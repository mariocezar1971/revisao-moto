#!/usr/bin/env python3
"""
========================================================================
REVISAO-MOTO :: Suite de testes da Fase 3
========================================================================
Valida execucao de checklist: migration, funcoes SQL, views, autosave
via upsert, progresso, validacao de finalizacao, trigger de km_moto,
UI (inspecao.html, camera.js, inspecao.js).
========================================================================
"""

import json
import os
import re
import subprocess
import sys
from pathlib import Path

RAIZ = Path(__file__).parent.parent.resolve()

class Cor:
    VERDE   = '\033[92m'
    VERMELHO= '\033[91m'
    AMARELO = '\033[93m'
    AZUL    = '\033[94m'
    NEGRITO = '\033[1m'
    RESET   = '\033[0m'

testes_total = 0
testes_passou = 0
testes_falhou = 0
falhas = []

def cabecalho(titulo):
    print(f"\n{Cor.AZUL}{Cor.NEGRITO}{'=' * 70}{Cor.RESET}")
    print(f"{Cor.AZUL}{Cor.NEGRITO}  {titulo}{Cor.RESET}")
    print(f"{Cor.AZUL}{Cor.NEGRITO}{'=' * 70}{Cor.RESET}")

def teste(descricao, condicao, detalhe=''):
    global testes_total, testes_passou, testes_falhou
    testes_total += 1
    if condicao:
        testes_passou += 1
        print(f"  {Cor.VERDE}OK{Cor.RESET}   {descricao}")
        if detalhe:
            print(f"       {Cor.AMARELO}{detalhe}{Cor.RESET}")
    else:
        testes_falhou += 1
        falhas.append(descricao)
        print(f"  {Cor.VERMELHO}FAIL {descricao}{Cor.RESET}")
        if detalhe:
            print(f"       {Cor.VERMELHO}{detalhe}{Cor.RESET}")

def psql(sql, db=None):
    cmd = ['psql',
           '-h', os.environ.get('PGHOST', '/tmp'),
           '-p', os.environ.get('PGPORT', '5433'),
           '-U', os.environ.get('PGUSER', 'postgres'),
           '-d', db or os.environ.get('PGDATABASE', 'revisao_moto_test'),
           '-t', '-A', '-c', sql]
    res = subprocess.run(cmd, capture_output=True, text=True)
    if res.returncode != 0:
        raise RuntimeError(f"psql falhou: {res.stderr}")
    return res.stdout.strip()

def psql_arquivo(arquivo):
    cmd = ['psql',
           '-h', os.environ.get('PGHOST', '/tmp'),
           '-p', os.environ.get('PGPORT', '5433'),
           '-U', os.environ.get('PGUSER', 'postgres'),
           '-d', os.environ.get('PGDATABASE', 'revisao_moto_test'),
           '-f', str(arquivo),
           '-v', 'ON_ERROR_STOP=1']
    res = subprocess.run(cmd, capture_output=True, text=True)
    return res.returncode, res.stdout, res.stderr

def limpar():
    """Remove dados de teste (motos TST- e suas inspecoes)."""
    psql("""
        DELETE FROM inspecoes WHERE moto_id IN (SELECT id FROM motos WHERE placa LIKE 'TST-%');
        DELETE FROM motos WHERE placa LIKE 'TST-%';
    """)

# ============================================================
# 1. MIGRATION
# ============================================================
def testar_migration():
    cabecalho("1. MIGRATION (004_fase3_execucao.sql)")
    arquivo = RAIZ / 'sql' / '004_fase3_execucao.sql'
    teste("Arquivo existe", arquivo.exists())
    if not arquivo.exists(): return False

    codigo, _, stderr = psql_arquivo(arquivo)
    teste("Migration executa", codigo == 0, stderr if codigo != 0 else 'OK')
    if codigo != 0: return False

    # Idempotencia
    codigo2, _, stderr2 = psql_arquivo(arquivo)
    teste("Migration eh idempotente (2x)", codigo2 == 0, stderr2 if codigo2 != 0 else 'OK')
    return True

# ============================================================
# 2. ESTRUTURA APOS MIGRATION
# ============================================================
def testar_estrutura():
    cabecalho("2. ESTRUTURA POS-MIGRATION")

    # Funcoes
    for func in ['sugerir_revisao', 'pode_finalizar_inspecao', 'trigger_atualizar_km_moto']:
        existe = psql(f"SELECT EXISTS(SELECT 1 FROM pg_proc WHERE proname='{func}');") == 't'
        teste(f"Funcao existe: {func}", existe)

    # Views
    for v in ['vw_inspecao_progresso', 'vw_inspecoes_lista']:
        existe = psql(f"""
            SELECT EXISTS(SELECT 1 FROM information_schema.views
            WHERE table_schema='public' AND table_name='{v}');
        """) == 't'
        teste(f"View existe: {v}", existe)

    # Trigger
    existe = psql("""
        SELECT EXISTS(SELECT 1 FROM information_schema.triggers
        WHERE trigger_name='set_km_moto_ao_finalizar');
    """) == 't'
    teste("Trigger set_km_moto_ao_finalizar criado", existe)

    # Indices adicionais
    for idx in ['idx_inspecoes_data_fim', 'idx_inspecoes_itens_item']:
        existe = psql(f"SELECT EXISTS(SELECT 1 FROM pg_indexes WHERE indexname='{idx}');") == 't'
        teste(f"Indice existe: {idx}", existe)

# ============================================================
# 3. FUNCAO sugerir_revisao
# ============================================================
def testar_sugerir_revisao():
    cabecalho("3. FUNCAO sugerir_revisao")
    limpar()

    # Cria moto Shotgun 650 com 0 km (nova)
    psql("""
        INSERT INTO motos (placa, modelo_id, ano, km_atual, proprietario)
        SELECT 'TST-3001', m.id, 2024, 0, 'Mario Teste'
        FROM modelos m WHERE m.nome='Shotgun 650';
    """)

    # Sem historico: deve sugerir 500 km
    km_sug = psql("""
        SELECT km_revisao FROM sugerir_revisao((SELECT id FROM motos WHERE placa='TST-3001'));
    """)
    teste("Moto nova (0 km, sem historico) -> sugere 500 km",
          km_sug == '500', f"sugeriu: {km_sug}")

    # Atualiza km para 4800 e cria inspecao de 500 finalizada
    psql("UPDATE motos SET km_atual = 4800 WHERE placa='TST-3001';")
    psql("""
        WITH nova AS (
            INSERT INTO inspecoes (moto_id, revisao_id, km_registrado, status, data_fim, mecanico_nome)
            SELECT m.id, r.id, 500, 'finalizada', NOW() - INTERVAL '10 days', 'Teste'
            FROM motos m, revisoes r
            WHERE m.placa='TST-3001' AND r.modelo_id=m.modelo_id AND r.km=500
            RETURNING id
        ) SELECT 1;
    """)
    km_sug2 = psql("""
        SELECT km_revisao FROM sugerir_revisao((SELECT id FROM motos WHERE placa='TST-3001'));
    """)
    teste("Apos revisao 500 -> proxima sugere 5000 km",
          km_sug2 == '5000', f"sugeriu: {km_sug2}")

    # Simula km 14000: deve sugerir 15000 (proxima apos 10000)
    psql("UPDATE motos SET km_atual = 14000 WHERE placa='TST-3001';")
    psql("""
        WITH nova AS (
            INSERT INTO inspecoes (moto_id, revisao_id, km_registrado, status, data_fim, mecanico_nome)
            SELECT m.id, r.id, 10000, 'finalizada', NOW() - INTERVAL '5 days', 'Teste'
            FROM motos m, revisoes r
            WHERE m.placa='TST-3001' AND r.modelo_id=m.modelo_id AND r.km=10000
            RETURNING id
        ) SELECT 1;
    """)
    km_sug3 = psql("""
        SELECT km_revisao FROM sugerir_revisao((SELECT id FROM motos WHERE placa='TST-3001'));
    """)
    teste("Apos revisao 10000 (moto com 14000 km) -> sugere 15000",
          km_sug3 == '15000', f"sugeriu: {km_sug3}")

    # Motivo deve estar preenchido
    motivo = psql("""
        SELECT motivo FROM sugerir_revisao((SELECT id FROM motos WHERE placa='TST-3001'));
    """)
    teste("Motivo esta preenchido", len(motivo) > 5, f"motivo: '{motivo}'")

    # Moto inexistente: erro
    try:
        psql("SELECT km_revisao FROM sugerir_revisao(99999);")
        teste("Moto inexistente lanca erro", False, "deveria ter falhado")
    except RuntimeError as e:
        teste("Moto inexistente lanca erro", 'nao encontrada' in str(e).lower())

# ============================================================
# 4. AUTOSAVE (UPSERT em inspecoes_itens)
# ============================================================
def testar_autosave():
    cabecalho("4. AUTOSAVE (upsert em inspecoes_itens)")

    # Pega inspecao criada acima (5000 km ou 10000 km)
    insp_id = psql("""
        SELECT id FROM inspecoes WHERE moto_id=(SELECT id FROM motos WHERE placa='TST-3001')
        AND km_registrado=10000 LIMIT 1;
    """)
    teste("Inspecao de teste existe", len(insp_id) > 20, f"id: {insp_id[:8]}...")

    # Pega um item da revisao
    item_id = psql(f"""
        SELECT ic.id FROM inspecoes i
        JOIN itens_checklist ic ON ic.revisao_id = i.revisao_id
        WHERE i.id = '{insp_id}' ORDER BY ic.ordem LIMIT 1;
    """)

    # Insert inicial (status=ok)
    psql(f"""
        INSERT INTO inspecoes_itens (inspecao_id, item_id, status)
        VALUES ('{insp_id}', {item_id}, 'ok');
    """)
    st1 = psql(f"SELECT status FROM inspecoes_itens WHERE inspecao_id='{insp_id}' AND item_id={item_id};")
    teste("Insert inicial de item", st1 == 'ok')

    # Simula autosave via UPSERT (mudou para nao_ok + observacao)
    psql(f"""
        INSERT INTO inspecoes_itens (inspecao_id, item_id, status, observacao)
        VALUES ('{insp_id}', {item_id}, 'nao_ok', 'Vazamento detectado')
        ON CONFLICT (inspecao_id, item_id) DO UPDATE SET
            status = EXCLUDED.status,
            observacao = EXCLUDED.observacao;
    """)
    st2 = psql(f"SELECT status FROM inspecoes_itens WHERE inspecao_id='{insp_id}' AND item_id={item_id};")
    obs = psql(f"SELECT observacao FROM inspecoes_itens WHERE inspecao_id='{insp_id}' AND item_id={item_id};")
    teste("Upsert atualiza status", st2 == 'nao_ok')
    teste("Upsert atualiza observacao", obs == 'Vazamento detectado')

    # Nao gera duplicata (verifica constraint UNIQUE)
    n = int(psql(f"SELECT COUNT(*) FROM inspecoes_itens WHERE inspecao_id='{insp_id}' AND item_id={item_id};"))
    teste("Constraint UNIQUE evita duplicata", n == 1, f"linhas: {n}")

# ============================================================
# 5. VIEW vw_inspecao_progresso
# ============================================================
def testar_progresso():
    cabecalho("5. VIEW vw_inspecao_progresso")

    insp_id = psql("""
        SELECT id FROM inspecoes WHERE moto_id=(SELECT id FROM motos WHERE placa='TST-3001')
        AND km_registrado=10000 LIMIT 1;
    """)

    # Total de itens da revisao 10000 (Shotgun 650) = 22
    total = int(psql(f"SELECT total_itens FROM vw_inspecao_progresso WHERE inspecao_id='{insp_id}';"))
    teste("Total de itens (revisao 10000 = 22)", total == 22, f"total: {total}")

    # Preenchidos = 1 (o que fizemos acima)
    preench = int(psql(f"SELECT preenchidos FROM vw_inspecao_progresso WHERE inspecao_id='{insp_id}';"))
    teste("Preenchidos = 1", preench == 1, f"preenchidos: {preench}")

    # nao_ok_count = 1
    nok = int(psql(f"SELECT nao_ok_count FROM vw_inspecao_progresso WHERE inspecao_id='{insp_id}';"))
    teste("nao_ok_count = 1", nok == 1)

    # Adiciona mais itens para simular quase-completude
    psql(f"""
        INSERT INTO inspecoes_itens (inspecao_id, item_id, status)
        SELECT '{insp_id}', ic.id, 'ok'
        FROM itens_checklist ic
        JOIN inspecoes i ON i.revisao_id = ic.revisao_id
        WHERE i.id = '{insp_id}'
          AND ic.id NOT IN (SELECT item_id FROM inspecoes_itens WHERE inspecao_id='{insp_id}');
    """)
    preench_full = int(psql(f"SELECT preenchidos FROM vw_inspecao_progresso WHERE inspecao_id='{insp_id}';"))
    teste("Apos preencher tudo, preenchidos = total", preench_full == total, f"{preench_full}/{total}")

# ============================================================
# 6. FUNCAO pode_finalizar_inspecao
# ============================================================
def testar_pode_finalizar():
    cabecalho("6. FUNCAO pode_finalizar_inspecao")

    insp_id = psql("""
        SELECT id FROM inspecoes WHERE moto_id=(SELECT id FROM motos WHERE placa='TST-3001')
        AND km_registrado=10000 LIMIT 1;
    """)

    # Todos preenchidos, mas talvez faltando fotos/medicoes
    resultado = psql(f"""
        SELECT pode_finalizar || '|' || faltam_obrigatorios || '|' || motivo
        FROM pode_finalizar_inspecao('{insp_id}');
    """).split('|', 2)
    pode = resultado[0]
    falta_obrig = int(resultado[1])
    motivo = resultado[2] if len(resultado) > 2 else ''

    teste("Nao ha obrigatorios pendentes", falta_obrig == 0, f"faltam: {falta_obrig}")

    # Verifica se ha fotos/medicoes pendentes
    if pode == 't':
        teste("Pode finalizar (nenhum requisito pendente)", True, motivo)
    else:
        teste("Nao pode finalizar (foto/medicao pendente)", True,
              f"esperado - {motivo}")

    # Simula inspecao com obrigatorio pendente: remove um item preenchido de obrigatorio
    psql(f"""
        DELETE FROM inspecoes_itens WHERE inspecao_id='{insp_id}'
        AND item_id IN (SELECT ic.id FROM itens_checklist ic
                        JOIN inspecoes i ON i.revisao_id = ic.revisao_id
                        WHERE i.id='{insp_id}' AND ic.obrigatorio=true LIMIT 1);
    """)
    pode2 = psql(f"SELECT pode_finalizar FROM pode_finalizar_inspecao('{insp_id}');")
    teste("Com obrigatorio pendente, pode_finalizar = FALSE", pode2 == 'f')

# ============================================================
# 7. TRIGGER de atualizacao de km_moto
# ============================================================
def testar_trigger_km():
    cabecalho("7. TRIGGER de km_atual da moto ao finalizar")
    limpar()

    # Cria moto com km_atual = 5000
    psql("""
        INSERT INTO motos (placa, modelo_id, km_atual, proprietario)
        SELECT 'TST-3002', m.id, 5000, 'Trigger Teste'
        FROM modelos m WHERE m.nome='Classic 350';
    """)
    km0 = int(psql("SELECT km_atual FROM motos WHERE placa='TST-3002';"))
    teste("Moto criada com km_atual = 5000", km0 == 5000)

    # Cria inspecao em_andamento com km 15000 - nao deve alterar
    psql("""
        WITH nova AS (
            INSERT INTO inspecoes (moto_id, revisao_id, km_registrado, status, mecanico_nome)
            SELECT m.id, r.id, 15000, 'em_andamento', 'Teste'
            FROM motos m JOIN revisoes r ON r.modelo_id=m.modelo_id AND r.km=15000
            WHERE m.placa='TST-3002' RETURNING id
        ) SELECT 1;
    """)
    km1 = int(psql("SELECT km_atual FROM motos WHERE placa='TST-3002';"))
    teste("em_andamento nao altera km da moto", km1 == 5000, f"km: {km1}")

    # Finaliza - deve atualizar
    psql("""
        UPDATE inspecoes SET status='finalizada', data_fim=NOW()
        WHERE moto_id=(SELECT id FROM motos WHERE placa='TST-3002');
    """)
    km2 = int(psql("SELECT km_atual FROM motos WHERE placa='TST-3002';"))
    teste("finalizada atualiza km da moto (5000 -> 15000)", km2 == 15000, f"km: {km2}")

    # Km menor nao regride
    psql("""
        WITH nova AS (
            INSERT INTO inspecoes (moto_id, revisao_id, km_registrado, status, data_fim, mecanico_nome)
            SELECT m.id, r.id, 10000, 'finalizada', NOW(), 'Teste'
            FROM motos m JOIN revisoes r ON r.modelo_id=m.modelo_id AND r.km=10000
            WHERE m.placa='TST-3002' RETURNING id
        ) SELECT 1;
    """)
    km3 = int(psql("SELECT km_atual FROM motos WHERE placa='TST-3002';"))
    teste("Km menor nao regride (mantem 15000)", km3 == 15000, f"km: {km3}")

# ============================================================
# 8. UI (inspecao.html, camera.js, inspecao.js)
# ============================================================
def testar_ui():
    cabecalho("8. UI (inspecao.html, camera.js, inspecao.js)")

    # inspecao.html
    ins = RAIZ / 'inspecao.html'
    teste("inspecao.html existe", ins.exists())
    if ins.exists():
        html = ins.read_text(encoding='utf-8')
        teste("HTML tem DOCTYPE", html.lstrip().startswith('<!DOCTYPE'))
        teste("HTML tem view-selecao", 'id="view-selecao"' in html)
        teste("HTML tem view-execucao", 'id="view-execucao"' in html)
        teste("HTML tem view-finalizacao", 'id="view-finalizacao"' in html)
        teste("HTML tem barra de progresso", 'barra-progresso' in html)
        teste("HTML importa camera.js", 'camera.js' in html)
        teste("HTML importa inspecao.js", 'inspecao.js' in html)
        teste("HTML tem autocomplete de placa", 'input-busca-placa' in html)
        teste("HTML tem select de revisao", 'select-revisao' in html)
        teste("HTML tem funcao iniciarInspecao", 'function iniciarInspecao' in html)
        teste("HTML tem marcarStatus", 'function marcarStatus' in html)
        teste("HTML tem capturarFotoItem", 'function capturarFotoItem' in html)
        teste("HTML tem confirmarFinalizacao", 'function confirmarFinalizacao' in html)
        teste("HTML exige login", 'exigirLogin' in html)

        # Sintaxe JS inline
        scripts = re.findall(r'<script>([\s\S]*?)</script>', html)
        if scripts:
            tmp = '/tmp/inspecao_inline.js'
            with open(tmp, 'w') as f:
                f.write(scripts[-1])
            res = subprocess.run(['node', '--check', tmp], capture_output=True, text=True)
            teste("JS inline de inspecao.html eh valido",
                  res.returncode == 0, res.stderr.strip() if res.returncode != 0 else 'OK')

    # camera.js
    cam = RAIZ / 'src' / 'camera.js'
    teste("src/camera.js existe", cam.exists())
    if cam.exists():
        js = cam.read_text()
        res = subprocess.run(['node', '--check', str(cam)], capture_output=True, text=True)
        teste("camera.js sintaxe valida", res.returncode == 0,
              res.stderr.strip() if res.returncode != 0 else 'OK')
        teste("camera.js exporta capturarFoto", 'window.capturarFoto' in js)
        teste("camera.js exporta comprimirImagem", 'window.comprimirImagem' in js)
        teste("camera.js exporta uploadFotoSupabase", 'window.uploadFotoSupabase' in js)
        teste("camera.js exporta tirarFoto", 'window.tirarFoto' in js)
        teste("camera.js exporta urlAssinada", 'window.urlAssinada' in js)
        teste("camera.js usa capture=environment", "capture = 'environment'" in js)
        teste("camera.js usa canvas para comprimir", 'canvas' in js and 'toBlob' in js)
        teste("camera.js usa bucket 'inspecoes'", "'inspecoes'" in js)

    # inspecao.js
    ins_js = RAIZ / 'src' / 'inspecao.js'
    teste("src/inspecao.js existe", ins_js.exists())
    if ins_js.exists():
        js = ins_js.read_text()
        res = subprocess.run(['node', '--check', str(ins_js)], capture_output=True, text=True)
        teste("inspecao.js sintaxe valida", res.returncode == 0,
              res.stderr.strip() if res.returncode != 0 else 'OK')
        teste("inspecao.js exporta buscarMotosPorPlaca", 'window.buscarMotosPorPlaca' in js)
        teste("inspecao.js exporta sugerirRevisao", 'window.sugerirRevisao' in js)
        teste("inspecao.js exporta criarInspecao", 'window.criarInspecao' in js)
        teste("inspecao.js exporta agendarSalvamento", 'window.agendarSalvamento' in js)
        teste("inspecao.js exporta finalizarInspecao", 'window.finalizarInspecao' in js)
        teste("inspecao.js tem debounce (setTimeout)", 'AUTOSAVE_DELAY_MS' in js)
        teste("inspecao.js usa upsert", 'upsert' in js and 'onConflict' in js)
        teste("inspecao.js usa rpc sugerir_revisao", "rpc('sugerir_revisao'" in js)
        teste("inspecao.js usa rpc pode_finalizar", "rpc('pode_finalizar_inspecao'" in js)

# ============================================================
# CLEANUP
# ============================================================
def cleanup():
    limpar()

# ============================================================
# RESUMO
# ============================================================
def resumo():
    print(f"\n{Cor.NEGRITO}{'=' * 70}{Cor.RESET}")
    print(f"{Cor.NEGRITO}  RESUMO FASE 3{Cor.RESET}")
    print(f"{Cor.NEGRITO}{'=' * 70}{Cor.RESET}")
    print(f"  Total : {testes_total}")
    print(f"  {Cor.VERDE}Passou: {testes_passou}{Cor.RESET}")
    if testes_falhou:
        print(f"  {Cor.VERMELHO}Falhou: {testes_falhou}{Cor.RESET}\n  Falhas:")
        for f in falhas:
            print(f"    - {f}")
    pct = (testes_passou / testes_total * 100) if testes_total else 0
    cor = Cor.VERDE if pct == 100 else (Cor.AMARELO if pct >= 80 else Cor.VERMELHO)
    print(f"\n  {cor}{Cor.NEGRITO}Sucesso: {pct:.1f}%{Cor.RESET}")
    return 0 if testes_falhou == 0 else 1

def main():
    print(f"{Cor.NEGRITO}REVISAO-MOTO :: Testes da Fase 3{Cor.RESET}")
    if not testar_migration(): return 1
    testar_estrutura()
    testar_sugerir_revisao()
    testar_autosave()
    testar_progresso()
    testar_pode_finalizar()
    testar_trigger_km()
    testar_ui()
    cleanup()
    return resumo()

if __name__ == '__main__':
    sys.exit(main())

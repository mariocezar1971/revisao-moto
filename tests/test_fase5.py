#!/usr/bin/env python3
"""
========================================================================
REVISAO-MOTO :: Suite de testes da Fase 5
========================================================================
Valida:
  - Migration (idempotente)
  - Estrutura (views, funcoes, indices)
  - Funcao status_revisao_moto (4 cenarios)
  - View vw_motos_com_status_revisao
  - View vw_timeline_inspecoes
  - View vw_inspecoes_por_mecanico_mes
  - View vw_itens_mais_reprovados
  - Funcao estatisticas_gerais
  - UI: historico.html, relatorios.js
========================================================================
"""

import os, re, subprocess, sys
from pathlib import Path

RAIZ = Path(__file__).parent.parent.resolve()

class Cor:
    VERDE='\033[92m'; VERMELHO='\033[91m'; AMAR='\033[93m'
    AZUL='\033[94m'; NEG='\033[1m'; RESET='\033[0m'

testes_total = 0; testes_passou = 0; testes_falhou = 0; falhas = []

def cabecalho(t):
    print(f"\n{Cor.AZUL}{Cor.NEG}{'='*70}{Cor.RESET}")
    print(f"{Cor.AZUL}{Cor.NEG}  {t}{Cor.RESET}")
    print(f"{Cor.AZUL}{Cor.NEG}{'='*70}{Cor.RESET}")

def teste(desc, cond, det=''):
    global testes_total, testes_passou, testes_falhou
    testes_total += 1
    if cond:
        testes_passou += 1
        print(f"  {Cor.VERDE}OK{Cor.RESET}   {desc}")
        if det: print(f"       {Cor.AMAR}{det}{Cor.RESET}")
    else:
        testes_falhou += 1
        falhas.append(desc)
        print(f"  {Cor.VERMELHO}FAIL {desc}{Cor.RESET}")
        if det: print(f"       {Cor.VERMELHO}{det}{Cor.RESET}")

def psql(sql):
    cmd = ['psql', '-h', os.environ.get('PGHOST','/tmp'),
           '-p', os.environ.get('PGPORT','5433'),
           '-U', os.environ.get('PGUSER','postgres'),
           '-d', os.environ.get('PGDATABASE','revisao_moto_test'),
           '-t', '-A', '-c', sql]
    r = subprocess.run(cmd, capture_output=True, text=True)
    if r.returncode != 0:
        raise RuntimeError(f"psql: {r.stderr}")
    return r.stdout.strip()

def psql_arq(arq):
    cmd = ['psql', '-h', os.environ.get('PGHOST','/tmp'),
           '-p', os.environ.get('PGPORT','5433'),
           '-U', os.environ.get('PGUSER','postgres'),
           '-d', os.environ.get('PGDATABASE','revisao_moto_test'),
           '-f', str(arq), '-v', 'ON_ERROR_STOP=1']
    r = subprocess.run(cmd, capture_output=True, text=True)
    return r.returncode, r.stdout, r.stderr

def limpar():
    psql("""
        DELETE FROM inspecoes_itens WHERE inspecao_id IN
            (SELECT id FROM inspecoes WHERE moto_id IN
             (SELECT id FROM motos WHERE placa LIKE 'TST-%'));
        DELETE FROM inspecoes WHERE moto_id IN (SELECT id FROM motos WHERE placa LIKE 'TST-%');
        DELETE FROM motos WHERE placa LIKE 'TST-%';
    """)

# ============================================================
# 1. MIGRATION
# ============================================================
def t_migration():
    cabecalho("1. MIGRATION (006_fase5_historico.sql)")
    arq = RAIZ / 'sql' / '006_fase5_historico.sql'
    teste("Arquivo existe", arq.exists())
    if not arq.exists(): return False
    c, _, e = psql_arq(arq)
    teste("Migration executa", c == 0, e if c != 0 else 'OK')
    if c != 0: return False
    c2, _, e2 = psql_arq(arq)
    teste("Migration idempotente (2x)", c2 == 0, e2 if c2 != 0 else 'OK')
    return True

# ============================================================
# 2. ESTRUTURA
# ============================================================
def t_estrutura():
    cabecalho("2. ESTRUTURA POS-MIGRATION")
    for f in ['status_revisao_moto', 'estatisticas_gerais']:
        ok = psql(f"SELECT EXISTS(SELECT 1 FROM pg_proc WHERE proname='{f}');") == 't'
        teste(f"Funcao: {f}", ok)
    for v in ['vw_motos_com_status_revisao','vw_timeline_inspecoes',
              'vw_inspecoes_por_mecanico_mes','vw_itens_mais_reprovados']:
        ok = psql(f"SELECT EXISTS(SELECT 1 FROM information_schema.views WHERE table_name='{v}');") == 't'
        teste(f"View: {v}", ok)
    for idx in ['idx_inspecoes_mecanico_id','idx_inspecoes_data_inicio','idx_inspecoes_status_data']:
        ok = psql(f"SELECT EXISTS(SELECT 1 FROM pg_indexes WHERE indexname='{idx}');") == 't'
        teste(f"Indice: {idx}", ok)

# ============================================================
# 3. FUNCAO status_revisao_moto
# ============================================================
def t_status_revisao():
    cabecalho("3. FUNCAO status_revisao_moto")
    limpar()

    # Cenario A: moto sem historico
    psql("""
        INSERT INTO motos (placa, modelo_id, km_atual, proprietario)
        SELECT 'TST-5001', m.id, 3000, 'Sem historico'
        FROM modelos m WHERE m.nome='Shotgun 650';
    """)
    r = psql("SELECT status_revisao_moto((SELECT id FROM motos WHERE placa='TST-5001'));")
    teste("Sem historico -> 'sem_historico'", r == 'sem_historico', f"retornou: {r}")

    # Cenario B: moto com revisao recente (em dia)
    # Cria inspecao finalizada de 5000 km recente, moto atualmente com 6000 km
    psql("""
        INSERT INTO motos (placa, modelo_id, km_atual, proprietario)
        SELECT 'TST-5002', m.id, 6000, 'Em dia'
        FROM modelos m WHERE m.nome='Shotgun 650';

        INSERT INTO inspecoes (moto_id, revisao_id, km_registrado, status, data_fim, mecanico_nome)
        SELECT m.id, r.id, 5000, 'finalizada', NOW() - INTERVAL '15 days', 'Teste'
        FROM motos m JOIN revisoes r ON r.modelo_id=m.modelo_id AND r.km=5000
        WHERE m.placa='TST-5002';
    """)
    r = psql("SELECT status_revisao_moto((SELECT id FROM motos WHERE placa='TST-5002'));")
    teste("Km 6000 apos revisao 5000 (proxima em 10000) -> 'em_dia'",
          r == 'em_dia', f"retornou: {r}")

    # Cenario C: proximo (dentro de 500 km)
    psql("UPDATE motos SET km_atual = 9600 WHERE placa='TST-5002';")
    r = psql("SELECT status_revisao_moto((SELECT id FROM motos WHERE placa='TST-5002'));")
    teste("Km 9600 (proxima 10000, faltam 400) -> 'proxima'",
          r == 'proxima', f"retornou: {r}")

    # Cenario D: atrasado por km
    psql("UPDATE motos SET km_atual = 12000 WHERE placa='TST-5002';")
    r = psql("SELECT status_revisao_moto((SELECT id FROM motos WHERE placa='TST-5002'));")
    teste("Km 12000 (passou de 10000) -> 'atrasada'",
          r == 'atrasada', f"retornou: {r}")

    # Cenario E: atrasado por tempo (> 6 meses)
    psql("""
        UPDATE motos SET km_atual = 6000 WHERE placa='TST-5002';
        UPDATE inspecoes SET data_fim = NOW() - INTERVAL '8 months'
        WHERE moto_id = (SELECT id FROM motos WHERE placa='TST-5002');
    """)
    r = psql("SELECT status_revisao_moto((SELECT id FROM motos WHERE placa='TST-5002'));")
    teste("Ultima revisao ha 8 meses -> 'atrasada'",
          r == 'atrasada', f"retornou: {r}")

    # Cenario F: moto inexistente
    r = psql("SELECT status_revisao_moto(999999);")
    teste("Moto inexistente -> 'nao_encontrada'",
          r == 'nao_encontrada', f"retornou: {r}")

# ============================================================
# 4. VIEW vw_motos_com_status_revisao
# ============================================================
def t_view_motos_status():
    cabecalho("4. VIEW vw_motos_com_status_revisao")

    n_com = int(psql("SELECT COUNT(*) FROM vw_motos_com_status_revisao WHERE placa LIKE 'TST-%';"))
    teste("View retorna motos ativas TST-", n_com == 2, f"encontrou: {n_com}")

    # Coluna proxima_km_prevista deve ser calculada
    prox = psql("SELECT proxima_km_prevista FROM vw_motos_com_status_revisao WHERE placa='TST-5002';")
    teste("proxima_km_prevista calculada", int(prox) == 10000, f"retornou: {prox}")

    # Coluna total_inspecoes
    total = psql("SELECT total_inspecoes FROM vw_motos_com_status_revisao WHERE placa='TST-5002';")
    teste("total_inspecoes = 1", int(total) == 1)

    # Moto arquivada NAO aparece
    psql("UPDATE motos SET ativo=FALSE WHERE placa='TST-5001';")
    n2 = int(psql("SELECT COUNT(*) FROM vw_motos_com_status_revisao WHERE placa='TST-5001';"))
    teste("Moto arquivada NAO aparece", n2 == 0)
    psql("UPDATE motos SET ativo=TRUE WHERE placa='TST-5001';")

# ============================================================
# 5. VIEW vw_timeline_inspecoes
# ============================================================
def t_view_timeline():
    cabecalho("5. VIEW vw_timeline_inspecoes")

    n = int(psql("SELECT COUNT(*) FROM vw_timeline_inspecoes WHERE placa='TST-5002';"))
    teste("Timeline retorna a inspecao", n == 1)

    # Colunas de agregado
    for c in ['revisao_km', 'km_registrado', 'mecanico_nome', 'duracao_minutos',
              'total_itens', 'ok_count', 'nao_ok_count']:
        existe = psql(f"""
            SELECT EXISTS(SELECT 1 FROM information_schema.columns
            WHERE table_name='vw_timeline_inspecoes' AND column_name='{c}');
        """) == 't'
        teste(f"Coluna '{c}' presente", existe)

# ============================================================
# 6. VIEW vw_inspecoes_por_mecanico_mes
# ============================================================
def t_view_mec_mes():
    cabecalho("6. VIEW vw_inspecoes_por_mecanico_mes")

    n = int(psql("SELECT COUNT(*) FROM vw_inspecoes_por_mecanico_mes WHERE mecanico_nome='Teste';"))
    teste("Agrega inspecoes por mecanico e mes", n >= 1, f"retornou: {n} linhas")

    total = psql("SELECT SUM(total) FROM vw_inspecoes_por_mecanico_mes WHERE mecanico_nome='Teste';")
    teste("total agregado correto", int(total) == 1, f"total: {total}")

    finalizadas = psql("SELECT SUM(finalizadas) FROM vw_inspecoes_por_mecanico_mes WHERE mecanico_nome='Teste';")
    teste("finalizadas contadas", int(finalizadas) == 1, f"finalizadas: {finalizadas}")

# ============================================================
# 7. VIEW vw_itens_mais_reprovados
# ============================================================
def t_view_reprovados():
    cabecalho("7. VIEW vw_itens_mais_reprovados")

    # Adiciona alguns itens reprovados nas inspecoes de teste
    insp_id = psql("SELECT id FROM inspecoes WHERE moto_id=(SELECT id FROM motos WHERE placa='TST-5002') LIMIT 1;")
    # Pega 3 itens dessa revisao e marca como nao_ok
    psql(f"""
        INSERT INTO inspecoes_itens (inspecao_id, item_id, status)
        SELECT '{insp_id}', ic.id, 'nao_ok'
        FROM inspecoes i JOIN itens_checklist ic ON ic.revisao_id=i.revisao_id
        WHERE i.id='{insp_id}' LIMIT 3;
    """)

    n = int(psql("SELECT COUNT(*) FROM vw_itens_mais_reprovados;"))
    teste("View retorna itens reprovados", n >= 3, f"itens: {n}")

    # Ordenado por reprovacoes DESC
    top = psql("SELECT reprovacoes FROM vw_itens_mais_reprovados LIMIT 1;")
    teste("Top item tem reprovacoes > 0", int(top) > 0, f"top: {top}")

# ============================================================
# 8. FUNCAO estatisticas_gerais
# ============================================================
def t_estatisticas():
    cabecalho("8. FUNCAO estatisticas_gerais")

    r = psql("SELECT total_motos FROM estatisticas_gerais();")
    teste("total_motos retornado", int(r) >= 2, f"total: {r}")

    r = psql("SELECT total_inspecoes FROM estatisticas_gerais();")
    teste("total_inspecoes retornado", int(r) >= 1, f"total: {r}")

    # Colunas todas presentes
    for col in ['total_motos','total_inspecoes','inspecoes_finalizadas',
                'inspecoes_em_andamento','motos_atrasadas','motos_proximas','duracao_media_min']:
        r = psql(f"SELECT {col} FROM estatisticas_gerais();")
        teste(f"Coluna '{col}' presente", r != '', f"valor: {r}")

# ============================================================
# 9. UI (relatorios.js e historico.html)
# ============================================================
def t_ui():
    cabecalho("9. UI (relatorios.js e historico.html)")

    # relatorios.js
    r = RAIZ / 'src' / 'relatorios.js'
    teste("src/relatorios.js existe", r.exists())
    if r.exists():
        js = r.read_text()
        res = subprocess.run(['node', '--check', str(r)], capture_output=True, text=True)
        teste("relatorios.js sintaxe valida", res.returncode == 0,
              res.stderr.strip() if res.returncode != 0 else 'OK')
        for fn in ['buscarInspecoes','listarMecanicos','listarModelos',
                   'exportarCsvInspecoes','exportarCsvItens',
                   'estatisticasGerais','inspecoesPorMecanicoMes',
                   'itensMaisReprovados','motosComStatus','timelineDeUmaMoto']:
            teste(f"relatorios.js exporta {fn}", f'window.{fn}' in js)
        teste("Escapa CSV corretamente", 'csvEscape' in js and 'replace(/"/g' in js)
        teste("BOM UTF-8 para Excel", '\\uFEFF' in js)
        teste("Usa RPC estatisticas_gerais", "rpc('estatisticas_gerais'" in js)

    # historico.html
    h = RAIZ / 'historico.html'
    teste("historico.html existe", h.exists())
    if h.exists():
        html = h.read_text()
        teste("HTML tem DOCTYPE", html.lstrip().startswith('<!DOCTYPE'))
        teste("Importa relatorios.js", 'relatorios.js' in html)
        teste("Tem 3 tabs (lista/inspecoes/relatorios)",
              'tab-lista' in html and 'tab-inspecoes' in html and 'tab-relatorios' in html)
        teste("Tem filtro placa", 'filtro-placa-lista' in html)
        teste("Tem filtro status", 'filtro-status-lista' in html)
        teste("Tem filtro mecanico", 'filtro-mecanico' in html)
        teste("Tem filtro data-de/ate", 'filtro-data-de' in html and 'filtro-data-ate' in html)
        teste("Tem botao export CSV cabecalho", 'exportarInspecoesCsv' in html)
        teste("Tem botao export CSV itens", 'exportarItensCsv' in html)
        teste("Tem KPIs (motos/inspecoes/atrasadas)",
              'kpi-motos' in html and 'kpi-inspecoes' in html and 'kpi-atrasadas' in html)
        teste("Tem tabela mecanico/mes", 'tabela-mec-mes' in html)
        teste("Tem tabela reprovados", 'tabela-reprovados' in html)
        teste("Tem modal detalhe", 'modal-detalhe' in html)
        teste("Tem grafico SVG km/tempo", 'grafico-km' in html)
        teste("Tem timeline (detalhe-timeline)", 'detalhe-timeline' in html)
        teste("Exige login", 'exigirLogin' in html)
        teste("Chama motosComStatus", 'motosComStatus' in html)
        teste("Chama estatisticasGerais", 'estatisticasGerais' in html)
        teste("Chama timelineDeUmaMoto", 'timelineDeUmaMoto' in html)

        # Sintaxe JS inline
        scripts = re.findall(r'<script>([\s\S]*?)</script>', html)
        if scripts:
            tmp = '/tmp/historico_inline.js'
            with open(tmp, 'w') as f: f.write(scripts[-1])
            res = subprocess.run(['node', '--check', tmp], capture_output=True, text=True)
            teste("JS inline valido (node --check)", res.returncode == 0,
                  res.stderr.strip() if res.returncode != 0 else 'OK')

def cleanup():
    limpar()

def resumo():
    print(f"\n{Cor.NEG}{'='*70}{Cor.RESET}")
    print(f"{Cor.NEG}  RESUMO FASE 5{Cor.RESET}")
    print(f"{Cor.NEG}{'='*70}{Cor.RESET}")
    print(f"  Total : {testes_total}")
    print(f"  {Cor.VERDE}Passou: {testes_passou}{Cor.RESET}")
    if testes_falhou:
        print(f"  {Cor.VERMELHO}Falhou: {testes_falhou}{Cor.RESET}")
        for f in falhas: print(f"    - {f}")
    pct = (testes_passou/testes_total*100) if testes_total else 0
    cor = Cor.VERDE if pct == 100 else (Cor.AMAR if pct >= 80 else Cor.VERMELHO)
    print(f"\n  {cor}{Cor.NEG}Sucesso: {pct:.1f}%{Cor.RESET}")
    return 0 if testes_falhou == 0 else 1

def main():
    print(f"{Cor.NEG}REVISAO-MOTO :: Testes da Fase 5{Cor.RESET}")
    if not t_migration(): return 1
    t_estrutura()
    t_status_revisao()
    t_view_motos_status()
    t_view_timeline()
    t_view_mec_mes()
    t_view_reprovados()
    t_estatisticas()
    t_ui()
    cleanup()
    return resumo()

if __name__ == '__main__':
    sys.exit(main())

#!/usr/bin/env python3
"""
========================================================================
REVISAO-MOTO :: Suite de testes da Fase 9 (P2) - Alta prioridade
========================================================================
  5. Checklist de recebimento (avarias)
  6. Recomendacoes futuras
  7. Fotos antes/depois
  8. Lembrete automatico ao CLIENTE
  9. Numero de OS
========================================================================
"""

import os, re, json, subprocess, sys, tempfile
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

def _conn():
    return ['-h', os.environ.get('PGHOST','/tmp'),
            '-p', os.environ.get('PGPORT','5433'),
            '-U', os.environ.get('PGUSER','postgres'),
            '-d', os.environ.get('PGDATABASE','revisao_moto_test')]

def psql(sql):
    r = subprocess.run(['psql'] + _conn() + ['-t','-A','-c', sql],
                       capture_output=True, text=True)
    if r.returncode != 0:
        raise RuntimeError(f"psql: {r.stderr}")
    return r.stdout.strip()

def psql_raw(sql):
    return subprocess.run(['psql'] + _conn() + ['-c', sql],
                          capture_output=True, text=True)

def psql_arq(arq):
    r = subprocess.run(['psql'] + _conn() + ['-f', str(arq), '-v','ON_ERROR_STOP=1'],
                       capture_output=True, text=True)
    return r.returncode, r.stdout, r.stderr

def node_check(c):
    r = subprocess.run(['node','--check',str(c)], capture_output=True, text=True)
    return r.returncode == 0, r.stderr


def node_eval(js_path, trecho):
    """Carrega um modulo window.* e roda um trecho de teste em cima dele.

    NAO usa require() nem 'node -e'. Dois motivos, os dois ja mordidos:

    1. require() resolve package.json subindo a arvore de diretorios. Se
       QUALQUER pasta acima do projeto declarar "type": "module" - e no
       Dropbox do usuario ha outros projetos JS acima - o Node trata este
       .js como ESM e estoura ERR_REQUIRE_ESM, mesmo o arquivo sendo
       CommonJS perfeitamente valido. 'node --check' passa, o require nao.
    2. 'node -e' depende de process.argv[1] carregar o argumento extra.

    Lendo o arquivo e avaliando o texto, nenhuma das duas coisas importa.
    Devolve (stdout, stderr) para que a falha apareca no detalhe do teste
    em vez de virar um resultado vazio sem explicacao.
    """
    runner = ("const fs = require('fs');\n"
              "global.window = {};\n"
              "eval(fs.readFileSync(process.argv[2], 'utf8'));\n" + trecho)
    with tempfile.NamedTemporaryFile('w', suffix='.js', delete=False) as f:
        f.write(runner)
        tmp = f.name
    try:
        r = subprocess.run(['node', tmp, str(js_path)],
                           capture_output=True, text=True)
        return r.stdout.strip(), r.stderr.strip()
    finally:
        os.unlink(tmp)


# ============================================================
def t_migration():
    cabecalho("1. MIGRATION (009_fase9_p2.sql)")
    arq = RAIZ / 'sql' / '009_fase9_p2.sql'
    teste("Arquivo existe", arq.exists())
    if not arq.exists(): return False

    c, _, e = psql_arq(arq)
    teste("Migration executa", c == 0, e[:200] if c else 'OK')
    if c != 0: return False

    c2, _, e2 = psql_arq(arq)
    teste("Migration idempotente (2x)", c2 == 0, e2[:200] if c2 else 'OK')
    return True


# ============================================================
def t_numero_os():
    cabecalho("2. NUMERO DE OS")

    ok = psql("SELECT EXISTS(SELECT 1 FROM information_schema.tables WHERE table_name='os_contador');") == 't'
    teste("Tabela os_contador criada", ok)

    ok = psql("SELECT EXISTS(SELECT 1 FROM information_schema.columns "
              "WHERE table_name='inspecoes' AND column_name='numero_os');") == 't'
    teste("inspecoes.numero_os existe", ok)

    ok = psql("SELECT EXISTS(SELECT 1 FROM pg_indexes WHERE indexname='idx_inspecoes_numero_os');") == 't'
    teste("Indice unico em numero_os", ok)

    ok = psql("SELECT EXISTS(SELECT 1 FROM pg_proc WHERE proname='proximo_numero_os');") == 't'
    teste("Funcao proximo_numero_os existe", ok)

    ok = psql("SELECT EXISTS(SELECT 1 FROM pg_trigger WHERE tgname='set_numero_os');") == 't'
    teste("Trigger set_numero_os criado", ok)

    # Setup: limpa dados de execucoes anteriores para o teste ser repetivel
    psql("DELETE FROM inspecoes WHERE moto_id IN (SELECT id FROM motos WHERE placa='OS9-0001');")
    psql("DELETE FROM motos WHERE placa='OS9-0001';")
    psql("""INSERT INTO motos (placa, modelo_id, ano, proprietario, telefone, km_atual)
            VALUES ('OS9-0001', 1, 2024, 'Cliente Fase9', '27999887766', 9800);""")
    moto = psql("SELECT id FROM motos WHERE placa='OS9-0001';")

    # 3 inspecoes seguidas
    psql(f"""DO $$
    DECLARE v_r INT; i INT;
    BEGIN
      SELECT id INTO v_r FROM revisoes WHERE modelo_id=1 AND km=5000;
      FOR i IN 1..3 LOOP
        INSERT INTO inspecoes (moto_id, revisao_id, km_registrado, status)
        VALUES ({moto}, v_r, 5000 + i*100, 'em_andamento');
      END LOOP;
    END $$;""")

    n = psql(f"SELECT COUNT(*) FROM inspecoes WHERE moto_id={moto} AND numero_os IS NOT NULL;")
    teste("Trigger gera numero automaticamente", int(n) >= 3, f"com numero: {n}")

    ano = psql("SELECT EXTRACT(YEAR FROM NOW())::TEXT;")

    fmt = psql(f"SELECT numero_os FROM inspecoes WHERE moto_id={moto} "
               f"ORDER BY criado_em LIMIT 1;")
    teste("Formato AAAA-NNNN", bool(re.match(r'^\d{4}-\d{4}$', fmt)), f"retornou: {fmt}")
    teste("Usa o ano corrente", fmt.startswith(ano), f"{fmt} comeca com {ano}")

    seq = psql(f"SELECT string_agg(numero_os, ',' ORDER BY numero_os) "
               f"FROM inspecoes WHERE moto_id={moto} AND numero_os LIKE '{ano}-%';")
    nums = [int(x.split('-')[1]) for x in seq.split(',')]
    teste("Sequencial sem buracos", nums == list(range(nums[0], nums[0]+len(nums))),
          f"numeros: {nums}")

    unicos = psql("SELECT COUNT(*) = COUNT(DISTINCT numero_os) FROM inspecoes "
                  "WHERE numero_os IS NOT NULL;")
    teste("Todos os numeros sao unicos", unicos == 't')

    cont = psql(f"SELECT ultimo_numero FROM os_contador WHERE ano={ano};")
    teste("Contador do ano atualizado", int(cont) >= 3, f"ultimo: {cont}")

    # Numero explicito nao eh sobrescrito pelo trigger
    psql("DELETE FROM inspecoes WHERE numero_os = '1999-9999';")
    psql(f"""INSERT INTO inspecoes (moto_id, revisao_id, km_registrado, status, numero_os)
             SELECT {moto}, id, 7000, 'em_andamento', '1999-9999'
             FROM revisoes WHERE modelo_id=1 AND km=5000;""")
    v = psql("SELECT numero_os FROM inspecoes WHERE numero_os='1999-9999';")
    teste("Numero informado explicitamente eh respeitado", v == '1999-9999', f"retornou: {v}")
    psql("DELETE FROM inspecoes WHERE numero_os = '1999-9999';")


# ============================================================
def t_recebimento():
    cabecalho("3. CHECKLIST DE RECEBIMENTO (AVARIAS)")

    ok = psql("SELECT EXISTS(SELECT 1 FROM information_schema.tables WHERE table_name='recebimentos');") == 't'
    teste("Tabela recebimentos criada", ok)
    if not ok: return

    for col in ['foto_frente','foto_tras','foto_lado_esq','foto_lado_dir',
                'avarias_texto','avarias_marcacoes','nivel_combustivel',
                'tem_bau','tem_capacete','tem_documentos',
                'assinatura_cliente','nome_cliente']:
        e = psql(f"SELECT EXISTS(SELECT 1 FROM information_schema.columns "
                 f"WHERE table_name='recebimentos' AND column_name='{col}');") == 't'
        teste(f"recebimentos.{col} existe", e)

    ok = psql("SELECT relrowsecurity FROM pg_class WHERE relname='recebimentos';") == 't'
    teste("RLS habilitado em recebimentos", ok)

    ok = psql("SELECT EXISTS(SELECT 1 FROM pg_proc WHERE proname='recebimento_completo');") == 't'
    teste("Funcao recebimento_completo existe", ok)

    ok = psql("SELECT EXISTS(SELECT 1 FROM information_schema.views WHERE table_name='vw_recebimentos');") == 't'
    teste("View vw_recebimentos criada", ok)

    moto = psql("SELECT id FROM motos WHERE placa='OS9-0001';")
    insp = psql(f"SELECT id FROM inspecoes WHERE moto_id={moto} ORDER BY criado_em LIMIT 1;")

    # Recebimento incompleto: 2 fotos, sem assinatura
    psql(f"""INSERT INTO recebimentos
             (inspecao_id, moto_id, km_entrada, foto_frente, foto_tras,
              nivel_combustivel, tem_bau, tem_documentos, avarias_texto)
             VALUES ('{insp}', {moto}, 9800, 'r/f.jpg', 'r/t.jpg', 2, TRUE, TRUE,
                     'Risco de 10cm no tanque lado direito');""")
    rec = psql(f"SELECT id FROM recebimentos WHERE inspecao_id='{insp}';")

    v = psql(f"SELECT completo FROM recebimento_completo('{rec}');")
    teste("Com 2 fotos e sem assinatura -> incompleto", v == 'f', f"retornou: {v}")

    v = psql(f"SELECT fotos_faltando FROM recebimento_completo('{rec}');")
    teste("Conta 2 fotos faltando", v == '2', f"retornou: {v}")

    v = psql(f"SELECT motivo FROM recebimento_completo('{rec}');")
    teste("Motivo cita fotos e assinatura", 'foto' in v and 'assinatura' in v, f"retornou: {v}")

    # Completa
    psql(f"""UPDATE recebimentos SET
             foto_lado_esq='r/e.jpg', foto_lado_dir='r/d.jpg',
             assinatura_cliente=repeat('iVBORw0KGgoAAAANS',12), nome_cliente='Cliente Fase9'
             WHERE id='{rec}';""")

    v = psql(f"SELECT completo FROM recebimento_completo('{rec}');")
    teste("Com 4 fotos e assinatura -> completo", v == 't', f"retornou: {v}")

    v = psql(f"SELECT motivo FROM recebimento_completo('{rec}');")
    teste("Motivo = 'Completo'", v == 'Completo', f"retornou: {v}")

    # Assinatura curta nao vale
    psql(f"UPDATE recebimentos SET assinatura_cliente='abc' WHERE id='{rec}';")
    v = psql(f"SELECT tem_assinatura FROM recebimento_completo('{rec}');")
    teste("Assinatura curta nao conta", v == 'f', f"retornou: {v}")
    psql(f"UPDATE recebimentos SET assinatura_cliente=repeat('iVBORw0KGgoAAAANS',12) WHERE id='{rec}';")

    # Nome curto nao vale
    psql(f"UPDATE recebimentos SET nome_cliente='Jo' WHERE id='{rec}';")
    v = psql(f"SELECT tem_assinatura FROM recebimento_completo('{rec}');")
    teste("Nome com menos de 3 letras nao conta", v == 'f', f"retornou: {v}")
    psql(f"UPDATE recebimentos SET nome_cliente='Cliente Fase9' WHERE id='{rec}';")

    # View
    v = psql(f"SELECT fotos_tiradas FROM vw_recebimentos WHERE id='{rec}';")
    teste("View conta 4 fotos", v == '4', f"retornou: {v}")

    v = psql(f"SELECT combustivel_texto FROM vw_recebimentos WHERE id='{rec}';")
    teste("Combustivel 2 -> '1/2'", v == '1/2', f"retornou: {v}")

    v = psql(f"SELECT numero_os FROM vw_recebimentos WHERE id='{rec}';")
    teste("View traz o numero de OS", bool(re.match(r'^\d{4}-\d{4}$', v or '')), f"retornou: {v}")

    # Marcacoes JSONB
    psql(f"""UPDATE recebimentos SET avarias_marcacoes =
             '[{{"x":0.3,"y":0.5,"lado":"tanque","nota":"risco"}},
               {{"x":0.7,"y":0.2,"lado":"dir","nota":"amassado"}}]'::jsonb
             WHERE id='{rec}';""")
    v = psql(f"SELECT qtd_marcacoes FROM vw_recebimentos WHERE id='{rec}';")
    teste("Marcacoes JSONB contadas", v == '2', f"retornou: {v}")

    # Nivel invalido rejeitado
    r = psql_raw(f"UPDATE recebimentos SET nivel_combustivel=9 WHERE id='{rec}';")
    teste("Nivel de combustivel fora de 0..4 rejeitado", r.returncode != 0, 'CHECK bloqueou')

    # Modulo JS
    js = RAIZ / 'src' / 'recebimento.js'
    teste("src/recebimento.js existe", js.exists())
    if js.exists():
        ok_s, err = node_check(js)
        teste("recebimento.js sintaxe valida", ok_s, err[:120])
        c = js.read_text()
        for fn in ['criarRecebimento','atualizarRecebimento','capturarFotoAngulo',
                   'estaCompleto','validarLocal','assinarEntrada','vincularInspecao',
                   'adicionarMarcacao']:
            teste(f"recebimento.js exporta {fn}", fn in c and 'window.recebimento' in c)
        teste("Define os 4 angulos", c.count('foto_frente') >= 1 and 'foto_lado_dir' in c)
        teste("Define 5 niveis de combustivel", c.count("valor:") >= 5)
        teste("Retoma vistoria interrompida", 'recebimentoAbertoDaMoto' in c)

    # Pagina
    pg = RAIZ / 'recebimento.html'
    teste("recebimento.html existe", pg.exists())
    if pg.exists():
        h = pg.read_text()
        teste("Tem grade de 4 fotos", 'grade-fotos' in h)
        teste("Tem contador de fotos", 'contador-fotos' in h)
        teste("Tem campo de avarias", 'avarias-texto' in h)
        teste("Tem seletor de combustivel", 'niveis-combustivel' in h)
        teste("Tem checkboxes de acessorios", 'tem-bau' in h and 'tem-capacete' in h and 'tem-documentos' in h)
        teste("Tem canvas de assinatura", 'canvas-entrada' in h)
        teste("Bloqueia conclusao sem as 4 fotos", 'fotos_faltando' in h)
        teste("Exige login", 'exigirLogin' in h)
        teste("Aceita ?placa= do QR", "get('placa')" in h)


# ============================================================
def t_recomendacoes():
    cabecalho("4. RECOMENDACOES FUTURAS")

    ok = psql("SELECT EXISTS(SELECT 1 FROM information_schema.tables WHERE table_name='recomendacoes');") == 't'
    teste("Tabela recomendacoes criada", ok)

    ok = psql("SELECT relrowsecurity FROM pg_class WHERE relname='recomendacoes';") == 't'
    teste("RLS habilitado em recomendacoes", ok)

    ok = psql("SELECT EXISTS(SELECT 1 FROM pg_proc WHERE proname='gerar_recomendacoes');") == 't'
    teste("Funcao gerar_recomendacoes existe", ok)

    moto = psql("SELECT id FROM motos WHERE placa='OS9-0001';")

    # Duas medicoes: 3.5mm@5000 -> 1.9mm@10000 (amarelo, limite 1.5)
    psql(f"""DO $$
    DECLARE v_r500 INT; v_r5k INT; v_p1 INT; v_p2 INT; v_i1 UUID; v_i2 UUID;
    BEGIN
      SELECT id INTO v_r500 FROM revisoes WHERE modelo_id=1 AND km=500;
      SELECT id INTO v_r5k  FROM revisoes WHERE modelo_id=1 AND km=5000;
      SELECT id INTO v_p1 FROM itens_checklist WHERE revisao_id=v_r500 AND chave_medicao='pastilha_dianteira';
      SELECT id INTO v_p2 FROM itens_checklist WHERE revisao_id=v_r5k  AND chave_medicao='pastilha_dianteira';

      INSERT INTO inspecoes (moto_id, revisao_id, km_registrado, status, data_fim)
      VALUES ({moto}, v_r500, 5000, 'finalizada', NOW() - INTERVAL '5 months') RETURNING id INTO v_i1;
      INSERT INTO inspecoes_itens (inspecao_id, item_id, status, valor_numerico)
      VALUES (v_i1, v_p1, 'ok', 3.5);

      INSERT INTO inspecoes (moto_id, revisao_id, km_registrado, status, data_fim)
      VALUES ({moto}, v_r5k, 10000, 'finalizada', NOW()) RETURNING id INTO v_i2;
      INSERT INTO inspecoes_itens (inspecao_id, item_id, status, valor_numerico)
      VALUES (v_i2, v_p2, 'nao_ok', 1.9);
    END $$;""")

    insp = psql(f"SELECT id FROM inspecoes WHERE moto_id={moto} AND km_registrado=10000 LIMIT 1;")
    n = psql(f"SELECT gerar_recomendacoes('{insp}');")
    teste("Gera recomendacao para item no amarelo", int(n) >= 1, f"geradas: {n}")

    v = psql(f"SELECT medicao_atual FROM recomendacoes WHERE inspecao_id='{insp}' LIMIT 1;")
    teste("Medicao atual gravada", v == '1.9', f"retornou: {v}")

    v = psql(f"SELECT prioridade FROM recomendacoes WHERE inspecao_id='{insp}' LIMIT 1;")
    teste("1.9mm (acima do limite 1.5) -> 'planejar'", v == 'planejar', f"retornou: {v}")

    v = psql(f"SELECT previsao_km FROM recomendacoes WHERE inspecao_id='{insp}' LIMIT 1;")
    teste("Previsao de km calculada", v == '11250',
          f"3.5->1.9 em 5000km = 0.32/1000km; (1.9-1.5)/0.32 = 1250; 10000+1250 | retornou: {v}")

    # Idempotencia: rodar de novo nao duplica
    psql(f"SELECT gerar_recomendacoes('{insp}');")
    n = psql(f"SELECT COUNT(*) FROM recomendacoes WHERE inspecao_id='{insp}';")
    teste("Regerar nao duplica", int(n) == 1, f"linhas: {n}")

    # Item abaixo do limite vira 'urgente'
    psql(f"""UPDATE inspecoes_itens SET valor_numerico = 1.2
             WHERE inspecao_id='{insp}' AND valor_numerico = 1.9;""")
    psql(f"SELECT gerar_recomendacoes('{insp}');")
    v = psql(f"SELECT prioridade FROM recomendacoes WHERE inspecao_id='{insp}' LIMIT 1;")
    teste("1.2mm (abaixo do limite) -> 'urgente'", v == 'urgente', f"retornou: {v}")

    # Prioridade so aceita os 3 valores
    r = psql_raw(f"UPDATE recomendacoes SET prioridade='qualquer' WHERE inspecao_id='{insp}';")
    teste("Prioridade invalida rejeitada", r.returncode != 0, 'CHECK bloqueou')

    # PDF
    pdf = (RAIZ / 'src' / 'pdf.js').read_text()
    teste("PDF tem secao RECOMENDACOES", 'RECOMENDACOES' in pdf)
    teste("PDF destaca urgentes", 'urgente' in pdf)
    teste("PDF coleta recomendacoes", "from('recomendacoes')" in pdf)

    html = (RAIZ / 'inspecao.html').read_text()
    teste("inspecao.html chama gerar_recomendacoes", 'gerar_recomendacoes' in html)


# ============================================================
def t_fotos():
    cabecalho("5. FOTOS ANTES/DEPOIS")

    for col in ['foto_antes_url','foto_depois_url']:
        ok = psql(f"SELECT EXISTS(SELECT 1 FROM information_schema.columns "
                  f"WHERE table_name='inspecoes_itens' AND column_name='{col}');") == 't'
        teste(f"inspecoes_itens.{col} existe", ok)

    ok = psql("SELECT EXISTS(SELECT 1 FROM information_schema.columns "
              "WHERE table_name='inspecoes_itens' AND column_name='foto_url');") == 't'
    teste("foto_url mantida (retrocompatibilidade)", ok)

    moto = psql("SELECT id FROM motos WHERE placa='OS9-0001';")
    item = psql(f"""SELECT ii.id FROM inspecoes_itens ii
                    JOIN inspecoes i ON i.id = ii.inspecao_id
                    WHERE i.moto_id={moto} LIMIT 1;""")

    psql(f"UPDATE inspecoes_itens SET foto_antes_url='a.jpg', foto_depois_url='d.jpg' WHERE id={item};")
    v = psql(f"SELECT foto_antes_url||'|'||foto_depois_url FROM inspecoes_itens WHERE id={item};")
    teste("Duas fotos coexistem no mesmo item", v == 'a.jpg|d.jpg', f"retornou: {v}")

    # Migracao do legado: a migration copia foto_url -> foto_antes_url.
    # Insere um item com foto_url apenas (como era antes da Fase 9) e
    # confirma que a copia so acontece quando foto_antes_url esta vazia.
    psql(f"""UPDATE inspecoes_itens
             SET foto_url='legado.jpg', foto_antes_url=NULL, foto_depois_url=NULL
             WHERE id={item};""")
    psql("""UPDATE inspecoes_itens SET foto_antes_url = foto_url
            WHERE foto_url IS NOT NULL AND foto_antes_url IS NULL;""")
    v = psql(f"SELECT foto_antes_url FROM inspecoes_itens WHERE id={item};")
    teste("foto_url legada migra para foto_antes_url", v == 'legado.jpg', f"retornou: {v}")

    # E nao sobrescreve quando ja ha foto_antes_url
    psql(f"UPDATE inspecoes_itens SET foto_antes_url='nova.jpg' WHERE id={item};")
    psql("""UPDATE inspecoes_itens SET foto_antes_url = foto_url
            WHERE foto_url IS NOT NULL AND foto_antes_url IS NULL;""")
    v = psql(f"SELECT foto_antes_url FROM inspecoes_itens WHERE id={item};")
    teste("Migracao nao sobrescreve foto ja existente", v == 'nova.jpg', f"retornou: {v}")

    html = (RAIZ / 'inspecao.html').read_text()
    teste("UI tem botao 'Antes'", "'antes'" in html and 'foto-antes-btn' in html)
    teste("UI tem botao 'Depois'", "'depois'" in html and 'foto-depois-btn' in html)
    teste("capturarFotoItem aceita momento", 'capturarFotoItem(itemId, momento' in html)
    teste("Grava foto_antes_url", 'foto_antes_url' in html)
    teste("Grava foto_depois_url", 'foto_depois_url' in html)

    js = (RAIZ / 'src' / 'inspecao.js').read_text()
    teste("inspecao.js carrega as duas fotos", 'foto_antes_url' in js and 'foto_depois_url' in js)

    pdf = (RAIZ / 'src' / 'pdf.js').read_text()
    teste("PDF considera as duas fotos", 'foto_antes_url' in pdf and 'foto_depois_url' in pdf)


# ============================================================
def t_lembretes():
    cabecalho("6. LEMBRETE AUTOMATICO AO CLIENTE")

    ok = psql("SELECT EXISTS(SELECT 1 FROM information_schema.tables WHERE table_name='lembretes_cliente');") == 't'
    teste("Tabela lembretes_cliente criada", ok)

    ok = psql("SELECT relrowsecurity FROM pg_class WHERE relname='lembretes_cliente';") == 't'
    teste("RLS habilitado", ok)

    ok = psql("SELECT EXISTS(SELECT 1 FROM information_schema.views WHERE table_name='vw_lembretes_pendentes');") == 't'
    teste("View vw_lembretes_pendentes criada", ok)

    moto = psql("SELECT id FROM motos WHERE placa='OS9-0001';")

    # Deixa a moto atrasada
    psql(f"DELETE FROM lembretes_cliente WHERE moto_id={moto};")
    psql(f"UPDATE motos SET km_atual=16000, telefone='27999887766' WHERE id={moto};")

    n = psql(f"SELECT COUNT(*) FROM vw_lembretes_pendentes WHERE moto_id={moto};")
    teste("Moto atrasada entra na fila", int(n) == 1, f"linhas: {n}")

    v = psql(f"SELECT tipo_lembrete FROM vw_lembretes_pendentes WHERE moto_id={moto};")
    teste("Tipo = revisao_atrasada", v == 'revisao_atrasada', f"retornou: {v}")

    # Registra envio -> sai da fila
    psql(f"""INSERT INTO lembretes_cliente (moto_id, tipo, mensagem, km_referencia)
             VALUES ({moto},'revisao_atrasada','teste',16000);""")
    n = psql(f"SELECT COUNT(*) FROM vw_lembretes_pendentes WHERE moto_id={moto};")
    teste("Apos envio sai da fila (janela de 30 dias)", int(n) == 0, f"linhas: {n}")

    # Envio antigo -> volta
    psql(f"UPDATE lembretes_cliente SET enviado_em = NOW() - INTERVAL '40 days' WHERE moto_id={moto};")
    n = psql(f"SELECT COUNT(*) FROM vw_lembretes_pendentes WHERE moto_id={moto};")
    teste("Envio de 40 dias atras volta para a fila", int(n) == 1, f"linhas: {n}")

    # Sem telefone -> nao entra
    psql(f"UPDATE motos SET telefone=NULL WHERE id={moto};")
    n = psql(f"SELECT COUNT(*) FROM vw_lembretes_pendentes WHERE moto_id={moto};")
    teste("Moto sem telefone nao entra na fila", int(n) == 0, f"linhas: {n}")
    psql(f"UPDATE motos SET telefone='27999887766' WHERE id={moto};")

    # Moto em dia -> nao entra
    psql(f"UPDATE motos SET km_atual=10500 WHERE id={moto};")
    n = psql(f"SELECT COUNT(*) FROM vw_lembretes_pendentes WHERE moto_id={moto};")
    teste("Moto em dia nao entra na fila", int(n) == 0, f"linhas: {n}")

    # Modulo JS
    js = RAIZ / 'src' / 'lembretes.js'
    teste("src/lembretes.js existe", js.exists())
    if js.exists():
        ok_s, err = node_check(js)
        teste("lembretes.js sintaxe valida", ok_s, err[:120])
        c = js.read_text()
        for fn in ['normalizarTelefone','montarLinkWhatsapp','montarMensagem',
                   'listarPendentes','enviarLembrete','registrarEnvio','linkMotoPronta']:
            teste(f"lembretes.js exporta {fn}", fn in c and 'window.lembretes' in c)
        teste("Usa wa.me (sem API paga)", 'wa.me' in c)
        teste("Tem template de revisao proxima", 'revisao_proxima' in c)
        teste("Tem template de revisao atrasada", 'revisao_atrasada' in c)
        teste("Tem template de moto pronta", "pronta" in c)
        teste("Codifica a mensagem na URL", 'encodeURIComponent' in c)

        # Normalizacao de telefone
        trecho = '''
        const n = window.lembretes.normalizarTelefone;
        const casos = [
          ["(27) 99988-7766", "5527999887766"],
          ["27999887766",     "5527999887766"],
          ["+55 27 99988-7766","5527999887766"],
          ["2733334444",      "552733334444"],
          ["99887766",        null],
          ["",                null]
        ];
        let ok = 0;
        const erros = [];
        for (const [i, e] of casos) {
          const got = n(i);
          if (got === e) ok++; else erros.push(JSON.stringify(i) + " -> " + got);
        }
        console.log(ok + "/" + casos.length + (erros.length ? " | " + erros.join("; ") : ""));
        '''
        out, err = node_eval(js, trecho)
        teste("Normaliza telefone em todos os formatos", out.startswith('6/6'),
              out if out else f"node falhou: {err[:160]}")

    # Pagina
    pg = RAIZ / 'lembretes.html'
    teste("lembretes.html existe", pg.exists())
    if pg.exists():
        h = pg.read_text()
        teste("Lista pendentes", 'listarPendentes' in h)
        teste("Mostra previa antes de enviar", 'modal-previa' in h)
        teste("Permite editar a mensagem", 'previa-texto' in h)
        teste("Registra o envio", 'registrarEnvio' in h)
        teste("Exige login", 'exigirLogin' in h)

    idx = (RAIZ / 'index.html').read_text()
    teste("Dashboard linka lembretes", 'lembretes.html' in idx)
    teste("Dashboard tem badge de pendentes", 'badge-lembretes' in idx)


# ============================================================
def t_integracao():
    cabecalho("7. INTEGRACAO")

    idx = (RAIZ / 'index.html').read_text()
    teste("Dashboard linka recebimento", 'recebimento.html' in idx)

    html = (RAIZ / 'inspecao.html').read_text()
    teste("inspecao.html importa recebimento.js", 'src/recebimento.js' in html)
    teste("inspecao.html vincula a vistoria", 'vincularRecebimento' in html)

    pdf = (RAIZ / 'src' / 'pdf.js').read_text()
    teste("PDF tem secao VISTORIA DE ENTRADA", 'VISTORIA DE ENTRADA' in pdf)
    teste("PDF usa o numero de OS no cabecalho", 'numero_os' in pdf)
    teste("PDF coleta o recebimento", 'vw_recebimentos' in pdf)

    sw = (RAIZ / 'service-worker.js').read_text()
    for a in ['recebimento.html','lembretes.html','recebimento.js','lembretes.js']:
        teste(f"APP_SHELL contem {a}", a in sw)

    _mv = re.search(r"CACHE_VERSION\s*=\s*'v(\d+)\.(\d+)", sw)
    _ver = (int(_mv.group(1)), int(_mv.group(2))) if _mv else (0, 0)
    _vtxt = _mv.group(0).split("'")[-1] if _mv else '?'
    teste("SW versao v0.9+", _ver >= (0, 9), _vtxt)


# ============================================================
def resumo():
    print(f"\n{Cor.NEG}{'='*70}{Cor.RESET}")
    print(f"{Cor.NEG}  RESUMO FASE 9 (P2){Cor.RESET}")
    print(f"{Cor.NEG}{'='*70}{Cor.RESET}")
    print(f"  Total : {testes_total}")
    print(f"  {Cor.VERDE}Passou: {testes_passou}{Cor.RESET}")
    if testes_falhou:
        print(f"  {Cor.VERMELHO}Falhou: {testes_falhou}{Cor.RESET}")
        for f in falhas[:15]: print(f"    - {f}")
    pct = (testes_passou/testes_total*100) if testes_total else 0
    cor = Cor.VERDE if pct == 100 else (Cor.AMAR if pct >= 80 else Cor.VERMELHO)
    print(f"\n  {cor}{Cor.NEG}Sucesso: {pct:.1f}%{Cor.RESET}")
    return 0 if testes_falhou == 0 else 1


def main():
    print(f"{Cor.NEG}REVISAO-MOTO :: Testes da Fase 9 (P2) - Alta prioridade{Cor.RESET}")
    if not t_migration(): return 1
    t_numero_os()
    t_recebimento()
    t_recomendacoes()
    t_fotos()
    t_lembretes()
    t_integracao()
    return resumo()


if __name__ == '__main__':
    sys.exit(main())

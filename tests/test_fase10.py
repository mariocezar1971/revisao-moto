#!/usr/bin/env python3
"""
========================================================================
REVISAO-MOTO :: Suite de testes da Fase 10 (P3) - Media prioridade
========================================================================
  10. Comparacao entre revisoes
  11. Teste de rodagem estruturado
  12. Garantia
  13. Torque efetivamente aplicado
  14. Revisao rapida vs completa
  +  Regressao: item.id do checklist (bug achado na Fase 10)
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
    cabecalho("1. MIGRATION (010_fase10_p3.sql)")
    arq = RAIZ / 'sql' / '010_fase10_p3.sql'
    teste("Arquivo existe", arq.exists())
    if not arq.exists(): return False

    c, _, e = psql_arq(arq)
    teste("Migration executa", c == 0, e[:200] if c else 'OK')
    if c != 0: return False

    c2, _, e2 = psql_arq(arq)
    teste("Migration idempotente (2x)", c2 == 0, e2[:200] if c2 else 'OK')
    return True


def _setup_moto():
    """Moto com duas inspecoes finalizadas e medicoes em ambas."""
    psql("DELETE FROM inspecoes WHERE moto_id IN (SELECT id FROM motos WHERE placa='P10-0001');")
    psql("DELETE FROM motos WHERE placa='P10-0001';")
    psql("""INSERT INTO motos (placa, modelo_id, ano, proprietario, telefone, km_atual)
            VALUES ('P10-0001', 1, 2024, 'Cliente Fase10', '27999887766', 10000);""")

    psql("""
    DO $$
    DECLARE v_m INT; v_r500 INT; v_r5k INT; v_i1 UUID; v_i2 UUID;
    BEGIN
      SELECT id INTO v_m FROM motos WHERE placa='P10-0001';
      SELECT id INTO v_r500 FROM revisoes WHERE modelo_id=1 AND km=500;
      SELECT id INTO v_r5k  FROM revisoes WHERE modelo_id=1 AND km=5000;

      INSERT INTO inspecoes (moto_id, revisao_id, km_registrado, status, data_fim)
      VALUES (v_m, v_r500, 5000, 'finalizada', NOW() - INTERVAL '6 months')
      RETURNING id INTO v_i1;
      INSERT INTO inspecoes_itens (inspecao_id, item_id, status, valor_numerico)
      SELECT v_i1, id, 'ok',
        CASE chave_medicao
          WHEN 'pastilha_dianteira' THEN 4.0
          WHEN 'pastilha_traseira'  THEN 3.8
          WHEN 'corrente_folga'     THEN 25.0
          WHEN 'bateria_tensao'     THEN 12.8
        END
      FROM itens_checklist WHERE revisao_id=v_r500 AND chave_medicao IN
        ('pastilha_dianteira','pastilha_traseira','corrente_folga','bateria_tensao');

      INSERT INTO inspecoes (moto_id, revisao_id, km_registrado, status, data_fim)
      VALUES (v_m, v_r5k, 10000, 'finalizada', NOW())
      RETURNING id INTO v_i2;
      INSERT INTO inspecoes_itens (inspecao_id, item_id, status, valor_numerico)
      SELECT v_i2, id, 'ok',
        CASE chave_medicao
          WHEN 'pastilha_dianteira' THEN 2.4
          WHEN 'pastilha_traseira'  THEN 1.2
          WHEN 'corrente_folga'     THEN 28.0
          WHEN 'bateria_tensao'     THEN 12.3
        END
      FROM itens_checklist WHERE revisao_id=v_r5k AND chave_medicao IN
        ('pastilha_dianteira','pastilha_traseira','corrente_folga','bateria_tensao');
    END $$;
    """)

    moto = psql("SELECT id FROM motos WHERE placa='P10-0001';")
    ia = psql(f"SELECT id FROM inspecoes WHERE moto_id={moto} AND km_registrado=5000;")
    ib = psql(f"SELECT id FROM inspecoes WHERE moto_id={moto} AND km_registrado=10000;")
    return moto, ia, ib


# ============================================================
def t_comparacao(ctx):
    cabecalho("2. COMPARACAO ENTRE REVISOES")
    moto, ia, ib = ctx

    for fn in ['comparar_inspecoes', 'historico_medicao']:
        ok = psql(f"SELECT EXISTS(SELECT 1 FROM pg_proc WHERE proname='{fn}');") == 't'
        teste(f"Funcao {fn} existe", ok)

    ok = psql("SELECT EXISTS(SELECT 1 FROM information_schema.views "
              "WHERE table_name='vw_inspecoes_comparaveis');") == 't'
    teste("View vw_inspecoes_comparaveis criada", ok)

    n = psql(f"SELECT COUNT(*) FROM comparar_inspecoes('{ia}','{ib}');")
    teste("Compara as 4 medicoes em comum", int(n) == 4, f"linhas: {n}")

    v = psql(f"""SELECT delta FROM comparar_inspecoes('{ia}','{ib}')
                 WHERE chave_medicao='pastilha_dianteira';""")
    teste("Delta da pastilha dianteira = -1.6", float(v) == -1.6,
          f"4.0 -> 2.4 | retornou: {v}")

    v = psql(f"""SELECT delta_pct FROM comparar_inspecoes('{ia}','{ib}')
                 WHERE chave_medicao='pastilha_dianteira';""")
    teste("Delta percentual = -40%", float(v) == -40.0, f"retornou: {v}")

    v = psql(f"""SELECT tendencia FROM comparar_inspecoes('{ia}','{ib}')
                 WHERE chave_medicao='pastilha_dianteira';""")
    teste("Pastilha que gastou -> 'piorou'", v == 'piorou', f"retornou: {v}")

    v = psql(f"""SELECT semaforo_b FROM comparar_inspecoes('{ia}','{ib}')
                 WHERE chave_medicao='pastilha_traseira';""")
    teste("1.2mm (limite 1.5) -> semaforo vermelho", v == 'vermelho', f"retornou: {v}")

    # Item de FAIXA: afastar-se do centro eh piorar, mesmo subindo
    v = psql(f"""SELECT tendencia FROM comparar_inspecoes('{ia}','{ib}')
                 WHERE chave_medicao='corrente_folga';""")
    teste("Folga 25->28 na faixa 20-30 -> 'piorou' (afastou do centro)",
          v == 'piorou',
          f"centro da faixa = 25; |28-25| > |25-25| | retornou: {v}")

    v = psql(f"""SELECT tendencia FROM comparar_inspecoes('{ia}','{ib}')
                 WHERE chave_medicao='bateria_tensao';""")
    teste("Bateria 12.8->12.3 -> 'piorou'", v == 'piorou', f"retornou: {v}")

    # Item so na inspecao B aparece como 'novo'
    psql(f"""INSERT INTO inspecoes_itens (inspecao_id, item_id, status, valor_numerico)
             SELECT '{ib}', id, 'ok', 0.8 FROM itens_checklist
             WHERE revisao_id=(SELECT revisao_id FROM inspecoes WHERE id='{ib}')
               AND chave_medicao='vela_folga' LIMIT 1
             ON CONFLICT DO NOTHING;""")
    v = psql(f"""SELECT tendencia FROM comparar_inspecoes('{ia}','{ib}')
                 WHERE chave_medicao='vela_folga';""")
    teste("Medicao so na inspecao nova -> 'novo'", v == 'novo', f"retornou: {v}")

    # Historico
    n = psql(f"SELECT COUNT(*) FROM historico_medicao({moto},'pastilha_dianteira');")
    teste("Historico traz as 2 medicoes", int(n) == 2, f"linhas: {n}")

    v = psql(f"""SELECT string_agg(km_registrado::text, ',' ORDER BY km_registrado)
                 FROM historico_medicao({moto},'pastilha_dianteira');""")
    teste("Historico em ordem de km", v == '5000,10000', f"retornou: {v}")

    v = psql(f"""SELECT numero_os FROM historico_medicao({moto},'pastilha_dianteira') LIMIT 1;""")
    teste("Historico traz o numero de OS", bool(re.match(r'^\d{4}-\d{4}$', v or '')),
          f"retornou: {v}")

    # View de pares
    v = psql(f"""SELECT km_anterior FROM vw_inspecoes_comparaveis
                 WHERE inspecao_atual='{ib}';""")
    teste("Par aponta para a inspecao anterior", v == '5000', f"retornou: {v}")

    v = psql(f"""SELECT COALESCE(inspecao_anterior::text,'(nulo)')
                 FROM vw_inspecoes_comparaveis WHERE inspecao_atual='{ia}';""")
    teste("Primeira inspecao nao tem anterior", v == '(nulo)', f"retornou: {v}")

    # Modulo JS
    js = RAIZ / 'src' / 'comparacao.js'
    teste("src/comparacao.js existe", js.exists())
    if js.exists():
        ok_s, err = node_check(js)
        teste("comparacao.js sintaxe valida", ok_s, err[:120])
        c = js.read_text()
        for fn in ['inspecoesComparaveis','compararInspecoes','historicoMedicao',
                   'graficoEvolucao','agruparPorCategoria','resumir','chavesComHistorico']:
            teste(f"comparacao.js exporta {fn}", fn in c and 'window.comparacao' in c)
        teste("Define as 4 tendencias",
              all(t in c for t in ['piorou','melhorou','estavel','novo']))
        teste("Grafico eh SVG inline", '<svg' in c and 'polyline' in c)
        teste("Grafico marca o limite de servico", 'limite' in c)

    pg = RAIZ / 'comparacao.html'
    teste("comparacao.html existe", pg.exists())
    if pg.exists():
        h = pg.read_text()
        teste("Tem busca por placa", 'busca-placa' in h)
        teste("Tem seletor de par", 'sel-par' in h)
        teste("Tem resumo (piorou/estavel/melhorou)", 'r-piorou' in h and 'r-melhorou' in h)
        teste("Tem grafico de evolucao", 'grafico' in h and 'carregarEvolucao' in h)
        teste("Exige login", 'exigirLogin' in h)

    idx = (RAIZ / 'index.html').read_text()
    teste("Dashboard linka comparacao", 'comparacao.html' in idx)


# ============================================================
def t_rodagem(ctx):
    cabecalho("3. TESTE DE RODAGEM ESTRUTURADO")
    moto, ia, ib = ctx

    for tab in ['rodagem_itens','inspecao_rodagem','inspecao_rodagem_itens']:
        ok = psql(f"SELECT EXISTS(SELECT 1 FROM information_schema.tables "
                  f"WHERE table_name='{tab}');") == 't'
        teste(f"Tabela {tab} criada", ok)
        rls = psql(f"SELECT relrowsecurity FROM pg_class WHERE relname='{tab}';") == 't'
        teste(f"RLS habilitado em {tab}", rls)

    ok = psql("SELECT EXISTS(SELECT 1 FROM pg_proc WHERE proname='rodagem_completa');") == 't'
    teste("Funcao rodagem_completa existe", ok)

    ok = psql("SELECT EXISTS(SELECT 1 FROM information_schema.views "
              "WHERE table_name='vw_rodagem');") == 't'
    teste("View vw_rodagem criada", ok)

    n = int(psql("SELECT COUNT(*) FROM rodagem_itens WHERE ativo;"))
    teste("Catalogo de rodagem populado", n >= 12, f"itens: {n}")

    n_obrig = int(psql("SELECT COUNT(*) FROM rodagem_itens WHERE obrigatorio AND ativo;"))
    teste("Tem itens obrigatorios e opcionais", 0 < n_obrig < n,
          f"{n_obrig} obrigatorios de {n}")

    n_cat = int(psql("SELECT COUNT(DISTINCT categoria) FROM rodagem_itens;"))
    teste("Varias categorias no teste", n_cat >= 5, f"categorias: {n_cat}")

    # Cria o teste
    psql(f"DELETE FROM inspecao_rodagem WHERE inspecao_id='{ib}';")
    psql(f"""INSERT INTO inspecao_rodagem (inspecao_id, km_inicial, km_final,
             condicao_pista, piloto_nome)
             VALUES ('{ib}', 10000, 10008, 'seca', 'Mecanico Teste');""")
    rod = psql(f"SELECT id FROM inspecao_rodagem WHERE inspecao_id='{ib}';")

    v = psql(f"SELECT completo FROM rodagem_completa('{rod}');")
    teste("Sem preencher -> incompleto", v == 'f', f"retornou: {v}")

    v = psql(f"SELECT obrigatorios_pendentes FROM rodagem_completa('{rod}');")
    teste("Conta os obrigatorios pendentes", int(v) == n_obrig, f"retornou: {v}")

    v = psql(f"SELECT km_percorridos FROM rodagem_completa('{rod}');")
    teste("Km percorridos = 8", int(v) == 8, f"10008 - 10000 | retornou: {v}")

    # Preenche tudo, com 1 reprovado
    psql(f"""INSERT INTO inspecao_rodagem_itens (rodagem_id, item_id, status)
             SELECT '{rod}', id,
               CASE WHEN descricao='Ruidos anormais' THEN 'nao_ok' ELSE 'ok' END
             FROM rodagem_itens WHERE obrigatorio AND ativo;""")

    v = psql(f"SELECT completo FROM rodagem_completa('{rod}');")
    teste("Obrigatorios preenchidos -> completo", v == 't', f"retornou: {v}")

    v = psql(f"SELECT reprovados FROM rodagem_completa('{rod}');")
    teste("Conta 1 reprovacao", int(v) == 1, f"retornou: {v}")

    v = psql(f"SELECT motivo FROM rodagem_completa('{rod}');")
    teste("Motivo cita a reprovacao", 'reprovacao' in v.lower(), f"retornou: {v}")

    # View
    v = psql(f"SELECT km_percorridos FROM vw_rodagem WHERE id='{rod}';")
    teste("View traz km percorridos", int(v) == 8, f"retornou: {v}")

    v = psql(f"SELECT numero_os FROM vw_rodagem WHERE id='{rod}';")
    teste("View traz o numero de OS", bool(re.match(r'^\d{4}-\d{4}$', v or '')),
          f"retornou: {v}")

    # Constraints
    r = psql_raw(f"UPDATE inspecao_rodagem SET condicao_pista='neve' WHERE id='{rod}';")
    teste("Condicao de pista invalida rejeitada", r.returncode != 0, 'CHECK bloqueou')

    r = psql_raw(f"""INSERT INTO inspecao_rodagem (inspecao_id) VALUES ('{ib}');""")
    teste("Uma inspecao tem no maximo um teste", r.returncode != 0, 'UNIQUE bloqueou')

    it = psql("SELECT id FROM rodagem_itens LIMIT 1;")
    r = psql_raw(f"""INSERT INTO inspecao_rodagem_itens (rodagem_id, item_id, status)
                     VALUES ('{rod}', {it}, 'talvez');""")
    teste("Status invalido rejeitado", r.returncode != 0, 'CHECK bloqueou')

    # Modulo JS
    js = RAIZ / 'src' / 'rodagem.js'
    teste("src/rodagem.js existe", js.exists())
    if js.exists():
        ok_s, err = node_check(js)
        teste("rodagem.js sintaxe valida", ok_s, err[:120])
        c = js.read_text()
        for fn in ['listarItensRodagem','iniciarRodagem','marcarItem',
                   'progresso','progressoLocal','finalizarRodagem','obterRodagem']:
            teste(f"rodagem.js exporta {fn}", fn in c and 'window.rodagem' in c)
        teste("Define as condicoes de pista", 'CONDICOES_PISTA' in c and 'molhada' in c)
        teste("Retoma teste em curso", 'obterRodagem' in c)

    h = (RAIZ / 'inspecao.html').read_text()
    teste("inspecao.html tem bloco de rodagem", 'bloco-rodagem' in h)
    teste("inspecao.html tem km inicial/final", 'rod-km-inicial' in h and 'rod-km-final' in h)
    teste("inspecao.html marca item de rodagem", 'marcarRodagem' in h)

    pdf = (RAIZ / 'src' / 'pdf.js').read_text()
    teste("PDF tem secao TESTE DE RODAGEM", 'TESTE DE RODAGEM' in pdf)
    teste("PDF coleta a rodagem", 'vw_rodagem' in pdf)


# ============================================================
def t_garantia(ctx):
    cabecalho("4. GARANTIA")
    moto, ia, ib = ctx

    for col in ['tipo_cobranca','garantia_ate','garantia_obs','inspecao_origem']:
        ok = psql(f"SELECT EXISTS(SELECT 1 FROM information_schema.columns "
                  f"WHERE table_name='inspecoes' AND column_name='{col}');") == 't'
        teste(f"inspecoes.{col} existe", ok)

    ok = psql("SELECT EXISTS(SELECT 1 FROM pg_constraint WHERE conname='chk_tipo_cobranca');") == 't'
    teste("Constraint chk_tipo_cobranca criada", ok)

    ok = psql("SELECT EXISTS(SELECT 1 FROM pg_trigger WHERE tgname='set_garantia_ao_finalizar');") == 't'
    teste("Trigger set_garantia_ao_finalizar criado", ok)

    ok = psql("SELECT EXISTS(SELECT 1 FROM pg_proc WHERE proname='garantia_vigente');") == 't'
    teste("Funcao garantia_vigente existe", ok)

    ok = psql("SELECT EXISTS(SELECT 1 FROM information_schema.views "
              "WHERE table_name='vw_garantias_vigentes');") == 't'
    teste("View vw_garantias_vigentes criada", ok)

    v = psql(f"SELECT tipo_cobranca FROM inspecoes WHERE id='{ib}';")
    teste("Default do tipo de cobranca eh 'pago'", v == 'pago', f"retornou: {v}")

    # Trigger abre a janela de 90 dias
    psql(f"UPDATE inspecoes SET status='em_andamento', garantia_ate=NULL WHERE id='{ib}';")
    psql(f"UPDATE inspecoes SET status='finalizada', data_fim=NOW() WHERE id='{ib}';")

    v = psql(f"SELECT garantia_ate IS NOT NULL FROM inspecoes WHERE id='{ib}';")
    teste("Finalizar servico pago abre a garantia", v == 't')

    v = psql(f"SELECT (garantia_ate - data_fim::date) FROM inspecoes WHERE id='{ib}';")
    teste("Garantia de 90 dias (CDC art. 26)", int(v) == 90, f"dias: {v}")

    v = psql(f"SELECT tem_garantia FROM garantia_vigente({moto});")
    teste("garantia_vigente encontra o servico", v == 't', f"retornou: {v}")

    v = psql(f"SELECT dias_restantes FROM garantia_vigente({moto});")
    teste("Dias restantes calculado", int(v) == 90, f"retornou: {v}")

    n = psql(f"SELECT COUNT(*) FROM vw_garantias_vigentes WHERE moto_id={moto};")
    teste("View lista a garantia vigente", int(n) >= 1, f"linhas: {n}")

    # Retorno em garantia NAO abre garantia nova
    psql(f"""DO $$
    DECLARE v_r INT; v_i UUID;
    BEGIN
      SELECT id INTO v_r FROM revisoes WHERE modelo_id=1 AND km=5000;
      INSERT INTO inspecoes (moto_id, revisao_id, km_registrado, status,
                             tipo_cobranca, inspecao_origem)
      VALUES ({moto}, v_r, 10500, 'em_andamento', 'garantia_oficina', '{ib}')
      RETURNING id INTO v_i;
      UPDATE inspecoes SET status='finalizada', data_fim=NOW() WHERE id=v_i;
    END $$;""")

    v = psql(f"""SELECT COALESCE(garantia_ate::text,'nulo') FROM inspecoes
                 WHERE moto_id={moto} AND tipo_cobranca='garantia_oficina';""")
    teste("Retorno em garantia NAO abre garantia nova", v == 'nulo',
          f"senao a garantia se renovaria para sempre | retornou: {v}")

    v = psql(f"""SELECT inspecao_origem IS NOT NULL FROM inspecoes
                 WHERE moto_id={moto} AND tipo_cobranca='garantia_oficina';""")
    teste("Retorno aponta para o servico original", v == 't')

    # Garantia vencida sai da view
    psql(f"UPDATE inspecoes SET garantia_ate = CURRENT_DATE - 1 WHERE id='{ib}';")
    n = psql(f"SELECT COUNT(*) FROM vw_garantias_vigentes WHERE inspecao_id='{ib}';")
    teste("Garantia vencida sai da view", int(n) == 0, f"linhas: {n}")
    psql(f"UPDATE inspecoes SET garantia_ate = CURRENT_DATE + 90 WHERE id='{ib}';")

    r = psql_raw(f"UPDATE inspecoes SET tipo_cobranca='qualquer' WHERE id='{ib}';")
    teste("Tipo de cobranca invalido rejeitado", r.returncode != 0, 'CHECK bloqueou')

    # Modulo JS
    js = RAIZ / 'src' / 'garantia.js'
    teste("src/garantia.js existe", js.exists())
    if js.exists():
        ok_s, err = node_check(js)
        teste("garantia.js sintaxe valida", ok_s, err[:120])
        c = js.read_text()
        for fn in ['garantiaVigente','definirTipoCobranca','sugerirCobranca',
                   'cobraDoCliente','formatarPrazo','textoOrcamento']:
            teste(f"garantia.js exporta {fn}", fn in c and 'window.garantia' in c)
        teste("Define os 4 tipos de cobranca",
              all(t in c for t in ['pago','garantia_fabrica','garantia_oficina','cortesia']))
        teste("garantia.js cita CDC art. 26", 'art. 26' in c)
        teste("Servico coberto nao cobra", 'cobra: false' in c)

    h = (RAIZ / 'inspecao.html').read_text()
    teste("inspecao.html tem seletor de cobranca", 'sel-cobranca' in h)
    teste("inspecao.html avisa garantia vigente", 'checarGarantia' in h)

    pdf = (RAIZ / 'src' / 'pdf.js').read_text()
    teste("PDF mostra o tipo de cobranca", 'tipo_cobranca' in pdf)
    teste("PDF zera o total quando coberto", 'cobraCliente' in pdf)


# ============================================================
def t_torque(ctx):
    cabecalho("5. TORQUE EFETIVAMENTE APLICADO")
    moto, ia, ib = ctx

    ok = psql("SELECT EXISTS(SELECT 1 FROM information_schema.tables "
              "WHERE table_name='inspecao_torques');") == 't'
    teste("Tabela inspecao_torques criada", ok)

    ok = psql("SELECT relrowsecurity FROM pg_class WHERE relname='inspecao_torques';") == 't'
    teste("RLS habilitado", ok)

    for fn in ['torques_do_modelo','avaliar_torque']:
        ok = psql(f"SELECT EXISTS(SELECT 1 FROM pg_proc WHERE proname='{fn}');") == 't'
        teste(f"Funcao {fn} existe", ok)

    ok = psql("SELECT EXISTS(SELECT 1 FROM information_schema.views "
              "WHERE table_name='vw_torques_inspecao');") == 't'
    teste("View vw_torques_inspecao criada", ok)

    # Le as specs da Fase 7
    n = psql("SELECT COUNT(*) FROM torques_do_modelo(1);")
    teste("Le os torques de especificacoes_modelo", int(n) >= 5, f"fixadores: {n}")

    v = psql("SELECT nominal FROM torques_do_modelo(1) WHERE fixador ILIKE '%roda dianteira%';")
    teste("Spec '80 Nm' vira nominal 80", float(v) == 80.0, f"retornou: {v}")

    v = psql("SELECT nominal FROM torques_do_modelo(1) WHERE fixador ILIKE '%vela%';")
    teste("Spec de faixa '12-15 Nm' vira o ponto medio 13.5", float(v) == 13.5,
          f"retornou: {v}")

    # Avaliacao
    for aplicado, esperado in [(80,'ok'), (75,'ok'), (72,'ok'), (60,'frouxo'), (95,'apertado')]:
        v = psql(f"SELECT situacao FROM avaliar_torque(80, {aplicado}, 10);")
        teste(f"Nominal 80, aplicado {aplicado} -> {esperado}", v == esperado,
              f"faixa 72-88 | retornou: {v}")

    v = psql("SELECT situacao FROM avaliar_torque(NULL, 50, 10);")
    teste("Sem nominal -> 'sem_spec'", v == 'sem_spec', f"retornou: {v}")

    v = psql("SELECT desvio_pct FROM avaliar_torque(80, 60, 10);")
    teste("Desvio percentual calculado", float(v) == -25.0, f"(60-80)/80 | retornou: {v}")

    # Registro
    psql(f"DELETE FROM inspecao_torques WHERE inspecao_id='{ib}';")
    psql(f"""INSERT INTO inspecao_torques
             (inspecao_id, fixador, torque_nominal, torque_aplicado, aplicado_por)
             VALUES ('{ib}', 'Parafuso roda dianteira', 80, 79, 'Mecanico Teste'),
                    ('{ib}', 'Parafuso roda traseira', 110, 98, 'Mecanico Teste'),
                    ('{ib}', 'Parafuso dreno oleo motor', 25, 25, 'Mecanico Teste');""")

    n = psql(f"SELECT COUNT(*) FROM vw_torques_inspecao WHERE inspecao_id='{ib}';")
    teste("Torques registrados", int(n) == 3, f"linhas: {n}")

    v = psql(f"""SELECT situacao FROM vw_torques_inspecao
                 WHERE inspecao_id='{ib}' AND fixador ILIKE '%dianteira%';""")
    teste("79 Nm num nominal de 80 -> na spec", v == 'ok', f"retornou: {v}")

    v = psql(f"""SELECT situacao FROM vw_torques_inspecao
                 WHERE inspecao_id='{ib}' AND fixador ILIKE '%traseira%';""")
    teste("98 Nm num nominal de 110 -> frouxo", v == 'frouxo',
          f"faixa 99-121 | retornou: {v}")

    v = psql(f"""SELECT aplicado_por FROM vw_torques_inspecao
                 WHERE inspecao_id='{ib}' LIMIT 1;""")
    teste("Registra quem aplicou", v == 'Mecanico Teste', f"retornou: {v}")

    v = psql(f"""SELECT aplicado_em IS NOT NULL FROM inspecao_torques
                 WHERE inspecao_id='{ib}' LIMIT 1;""")
    teste("Registra quando aplicou", v == 't')

    r = psql_raw(f"""INSERT INTO inspecao_torques (inspecao_id, fixador, torque_aplicado)
                     VALUES ('{ib}', 'Teste zero', 0);""")
    teste("Torque zero rejeitado", r.returncode != 0, 'CHECK bloqueou')

    r = psql_raw(f"""INSERT INTO inspecao_torques (inspecao_id, fixador, torque_aplicado)
                     VALUES ('{ib}', 'Parafuso roda dianteira', 81);""")
    teste("Mesmo fixador duas vezes rejeitado", r.returncode != 0, 'UNIQUE bloqueou')

    # Modulo JS
    js = RAIZ / 'src' / 'torque.js'
    teste("src/torque.js existe", js.exists())
    if js.exists():
        ok_s, err = node_check(js)
        teste("torque.js sintaxe valida", ok_s, err[:120])
        c = js.read_text()
        for fn in ['torquesDoModelo','avaliarLocal','registrarTorque',
                   'listarTorques','aplicarCor','textoFaixa','resumir']:
            teste(f"torque.js exporta {fn}", fn in c and 'window.torque' in c)
        teste("Define as 4 situacoes",
              all(x in c for x in ['ok','frouxo','apertado','sem_spec']))
        teste("Trata virgula decimal", "replace(',', '.')" in c)
        teste("Copia o nominal (nao referencia)", 'torque_nominal' in c)

        # A avaliacao local tem que bater com a SQL
        trecho = '''
        const a = window.torque.avaliarLocal;
        const casos = [[80,80,'ok'],[80,75,'ok'],[80,60,'frouxo'],
                       [80,95,'apertado'],[null,50,'sem_spec'],[80,'79,5','ok']];
        let ok = 0;
        const erros = [];
        for (const [n,v,e] of casos) {
          const got = a(n,v,10).situacao;
          if (got === e) ok++; else erros.push(n + "/" + v + " -> " + got + " (esperado " + e + ")");
        }
        console.log(ok + "/" + casos.length + (erros.length ? " | " + erros.join("; ") : ""));
        '''
        out, err = node_eval(js, trecho)
        teste("Avaliacao local bate com a SQL", out.startswith('6/6'),
              out if out else f"node falhou: {err[:160]}")

    h = (RAIZ / 'inspecao.html').read_text()
    teste("inspecao.html tem bloco de torques", 'bloco-torques' in h)
    teste("inspecao.html salva o torque", 'salvarTorque' in h)

    pdf = (RAIZ / 'src' / 'pdf.js').read_text()
    teste("PDF tem secao TORQUES APLICADOS", 'TORQUES APLICADOS' in pdf)
    teste("PDF mostra quem aplicou", 'aplicado_por' in pdf)


# ============================================================
def t_servicos(ctx):
    cabecalho("6. REVISAO RAPIDA VS COMPLETA")
    moto, ia, ib = ctx

    for col in ['tipo_execucao','servico_rapido_id']:
        ok = psql(f"SELECT EXISTS(SELECT 1 FROM information_schema.columns "
                  f"WHERE table_name='inspecoes' AND column_name='{col}');") == 't'
        teste(f"inspecoes.{col} existe", ok)

    ok = psql("SELECT EXISTS(SELECT 1 FROM pg_constraint WHERE conname='chk_tipo_execucao');") == 't'
    teste("Constraint chk_tipo_execucao criada", ok)

    ok = psql("SELECT EXISTS(SELECT 1 FROM information_schema.tables "
              "WHERE table_name='servicos_rapidos');") == 't'
    teste("Tabela servicos_rapidos criada", ok)

    for fn in ['itens_do_servico_rapido','pode_finalizar_por_tipo']:
        ok = psql(f"SELECT EXISTS(SELECT 1 FROM pg_proc WHERE proname='{fn}');") == 't'
        teste(f"Funcao {fn} existe", ok)

    n = int(psql("SELECT COUNT(*) FROM servicos_rapidos WHERE ativo;"))
    teste("Catalogo de servicos populado", n >= 5, f"servicos: {n}")

    v = psql("SELECT tipo_execucao FROM inspecoes LIMIT 1;")
    teste("Default do tipo de execucao eh 'completa'", v == 'completa', f"retornou: {v}")

    rev = psql("SELECT id FROM revisoes WHERE modelo_id=1 AND km=5000;")
    total_rev = int(psql(f"SELECT COUNT(*) FROM itens_checklist WHERE revisao_id={rev};"))

    serv_oleo = psql("SELECT id FROM servicos_rapidos WHERE nome='Troca de oleo';")
    n_oleo = int(psql(f"SELECT COUNT(*) FROM itens_do_servico_rapido({serv_oleo}, {rev});"))
    teste("Servico rapido traz menos itens que a revisao", n_oleo < total_rev,
          f"troca de oleo: {n_oleo} de {total_rev} itens da revisao")

    # Categoria E palavra-chave, nao OU
    v = psql(f"""SELECT COUNT(*) FROM itens_do_servico_rapido({serv_oleo}, {rev})
                 WHERE descricao ILIKE '%filtro de ar%';""")
    teste("Filtro de AR nao entra na troca de OLEO", int(v) == 0,
          "a categoria 'Motor' sozinha puxaria o filtro de ar")

    v = psql(f"""SELECT COUNT(*) FROM itens_do_servico_rapido({serv_oleo}, {rev})
                 WHERE descricao ILIKE '%oleo%';""")
    teste("Itens de oleo entram", int(v) >= 2, f"itens com 'oleo': {v}")

    serv_corr = psql("SELECT id FROM servicos_rapidos WHERE nome='Ajuste de corrente';")
    v = psql(f"""SELECT COUNT(*) FROM itens_do_servico_rapido({serv_corr}, {rev})
                 WHERE descricao ILIKE '%embreagem%';""")
    teste("Folga da EMBREAGEM nao entra no ajuste de CORRENTE", int(v) == 0,
          "a palavra 'folga' sozinha puxaria a embreagem")

    serv_past = psql("SELECT id FROM servicos_rapidos WHERE nome='Troca de pastilhas';")
    v = psql(f"""SELECT COUNT(*) FROM itens_do_servico_rapido({serv_past}, {rev})
                 WHERE descricao ILIKE '%pastilha%';""")
    teste("Pastilhas entram na troca de pastilhas", int(v) >= 2, f"itens: {v}")

    # pode_finalizar_por_tipo
    psql(f"DELETE FROM inspecoes WHERE moto_id={moto} AND tipo_execucao='rapida';")
    psql(f"""INSERT INTO inspecoes (moto_id, revisao_id, km_registrado, status,
             tipo_execucao, servico_rapido_id)
             VALUES ({moto}, {rev}, 11000, 'em_andamento', 'rapida', {serv_oleo});""")
    ir = psql(f"SELECT id FROM inspecoes WHERE moto_id={moto} AND tipo_execucao='rapida';")

    v = psql(f"SELECT tipo_execucao FROM pode_finalizar_por_tipo('{ir}');")
    teste("Reconhece o tipo da inspecao", v == 'rapida', f"retornou: {v}")

    esperados = int(psql(f"SELECT esperados FROM pode_finalizar_por_tipo('{ir}');"))
    teste("Espera so os itens do servico", esperados == n_oleo,
          f"esperados: {esperados} = itens do servico: {n_oleo}")

    v = psql(f"SELECT pode_finalizar FROM pode_finalizar_por_tipo('{ir}');")
    teste("Sem preencher -> nao pode finalizar", v == 'f', f"retornou: {v}")

    psql(f"""INSERT INTO inspecoes_itens (inspecao_id, item_id, status)
             SELECT '{ir}', item_id, 'ok' FROM itens_do_servico_rapido({serv_oleo}, {rev});""")

    v = psql(f"SELECT pode_finalizar FROM pode_finalizar_por_tipo('{ir}');")
    teste("Itens do servico preenchidos -> pode finalizar", v == 't', f"retornou: {v}")

    # A mesma inspecao como completa exigiria muito mais
    psql(f"UPDATE inspecoes SET tipo_execucao='completa' WHERE id='{ir}';")
    esp_completa = int(psql(f"SELECT esperados FROM pode_finalizar_por_tipo('{ir}');"))
    teste("Como 'completa' exigiria todos os obrigatorios", esp_completa > esperados,
          f"completa: {esp_completa} vs rapida: {esperados}")

    v = psql(f"SELECT pode_finalizar FROM pode_finalizar_por_tipo('{ir}');")
    teste("Como 'completa' nao poderia finalizar", v == 'f', f"retornou: {v}")
    psql(f"UPDATE inspecoes SET tipo_execucao='rapida' WHERE id='{ir}';")

    r = psql_raw(f"UPDATE inspecoes SET tipo_execucao='xyz' WHERE id='{ir}';")
    teste("Tipo de execucao invalido rejeitado", r.returncode != 0, 'CHECK bloqueou')

    ok = psql("SELECT EXISTS(SELECT 1 FROM information_schema.views "
              "WHERE table_name='vw_servicos_rapidos');") == 't'
    teste("View vw_servicos_rapidos criada", ok)

    # Modulo JS
    js = RAIZ / 'src' / 'servicos.js'
    teste("src/servicos.js existe", js.exists())
    if js.exists():
        ok_s, err = node_check(js)
        teste("servicos.js sintaxe valida", ok_s, err[:120])
        c = js.read_text()
        for fn in ['listarServicos','itensDoServico','contarItens',
                   'definirTipoExecucao','podeFinalizar','rotuloTipo']:
            teste(f"servicos.js exporta {fn}", fn in c and 'window.servicos' in c)
        teste("Define os 3 tipos de execucao",
              all(t in c for t in ['completa','rapida','avulsa']))

    h = (RAIZ / 'inspecao.html').read_text()
    teste("inspecao.html tem seletor de tipo", 'tipos-execucao' in h)
    teste("inspecao.html tem seletor de servico", 'sel-servico-rapido' in h)
    teste("inspecao.html usa a regra por tipo", 'podeFinalizar' in h)

    js_i = (RAIZ / 'src' / 'inspecao.js').read_text()
    teste("inspecao.js carrega so os itens do servico",
          'itens_do_servico_rapido' in js_i)
    teste("criarInspecao aceita tipo_execucao", 'tipo_execucao' in js_i)


# ============================================================
def t_regressao_item_id():
    cabecalho("7. REGRESSAO: item.id do checklist")
    print(f"  {Cor.AMAR}A view expoe a chave como 'item_id', mas renderItem(),{Cor.RESET}")
    print(f"  {Cor.AMAR}marcarStatus() e o mapa de respostas usam 'item.id'.{Cor.RESET}")

    tem_id = psql("SELECT EXISTS(SELECT 1 FROM information_schema.columns "
                  "WHERE table_name='vw_checklist_completo' AND column_name='id');") == 't'
    teste("A view NAO expoe coluna 'id' (so 'item_id')", not tem_id,
          "por isso o map eh necessario")

    js = (RAIZ / 'src' / 'inspecao.js').read_text()
    teste("carregarItensDaRevisao normaliza item_id -> id",
          'id: i.item_id' in js,
          "sem isso item.id eh undefined e marcarStatus(undefined) nao salva nada")

    n = js.count('id: i.item_id')
    teste("Normaliza nos dois caminhos (revisao completa e servico rapido)",
          n >= 2, f"ocorrencias: {n}")

    h = (RAIZ / 'inspecao.html').read_text()
    teste("renderItem continua usando item.id", 'item.id' in h,
          "o map garante que agora ele existe")


# ============================================================
def t_integracao():
    cabecalho("8. INTEGRACAO")

    h = (RAIZ / 'inspecao.html').read_text()
    for m in ['servicos.js','garantia.js','torque.js','rodagem.js']:
        teste(f"inspecao.html importa {m}", f'src/{m}' in h)

    pg = (RAIZ / 'comparacao.html').read_text()
    teste("comparacao.html importa comparacao.js", 'src/comparacao.js' in pg)

    sw = (RAIZ / 'service-worker.js').read_text()
    for a in ['comparacao.html','comparacao.js','rodagem.js','garantia.js',
              'torque.js','servicos.js']:
        teste(f"APP_SHELL contem {a}", a in sw)

    m = re.search(r"CACHE_VERSION\s*=\s*'v(\d+)\.(\d+)", sw)
    maior = (int(m.group(1)), int(m.group(2))) if m else (0, 0)
    teste("SW versao v1.0+", maior >= (1, 0),
          re.search(r"CACHE_VERSION\s*=\s*'([^']+)'", sw).group(1)
          if re.search(r"CACHE_VERSION\s*=\s*'([^']+)'", sw) else '?')

    pdf = (RAIZ / 'src' / 'pdf.js').read_text()
    teste("PDF mostra o tipo de execucao", 'tipo_execucao' in pdf)
    teste("PDF coleta os torques", 'vw_torques_inspecao' in pdf)

    # As funcoes das fases anteriores continuam de pe
    for fn in ['sugerir_revisao','avaliar_medicao','taxa_desgaste',
               'proximo_numero_os','gerar_recomendacoes']:
        ok = psql(f"SELECT EXISTS(SELECT 1 FROM pg_proc WHERE proname='{fn}');") == 't'
        teste(f"Funcao {fn} (fase anterior) intacta", ok)


# ============================================================
def resumo():
    print(f"\n{Cor.NEG}{'='*70}{Cor.RESET}")
    print(f"{Cor.NEG}  RESUMO FASE 10 (P3){Cor.RESET}")
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
    print(f"{Cor.NEG}REVISAO-MOTO :: Testes da Fase 10 (P3) - Media prioridade{Cor.RESET}")
    if not t_migration(): return 1
    ctx = _setup_moto()
    t_comparacao(ctx)
    t_rodagem(ctx)
    t_garantia(ctx)
    t_torque(ctx)
    t_servicos(ctx)
    t_regressao_item_id()
    t_integracao()
    return resumo()


if __name__ == '__main__':
    sys.exit(main())

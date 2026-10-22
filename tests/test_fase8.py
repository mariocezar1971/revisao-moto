#!/usr/bin/env python3
"""
========================================================================
REVISAO-MOTO :: Suite de testes da Fase 8 (P1) - Operacao Real
========================================================================
Valida os 4 itens P1 do roadmap:
  1. Medicao numerica com limites (semaforo + taxa de desgaste)
  2. Queixa do cliente + resolucao
  3. Itens avulsos fora do checklist
  4. Pecas e orcamento (+ aprovacao previa CDC art. 40)
========================================================================
"""

import os, re, json, subprocess, sys
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

def node_check(caminho):
    r = subprocess.run(['node', '--check', str(caminho)], capture_output=True, text=True)
    return r.returncode == 0, r.stderr


# ============================================================
# 1. MIGRATION
# ============================================================
def t_migration():
    cabecalho("1. MIGRATION (008_fase8_p1.sql)")
    arq = RAIZ / 'sql' / '008_fase8_p1.sql'
    teste("Arquivo existe", arq.exists())
    if not arq.exists(): return False

    c, _, e = psql_arq(arq)
    teste("Migration executa", c == 0, e[:200] if c != 0 else 'OK')
    if c != 0: return False

    c2, _, e2 = psql_arq(arq)
    teste("Migration idempotente (2x)", c2 == 0, e2[:200] if c2 != 0 else 'OK')
    return True


# ============================================================
# 2. MEDICAO NUMERICA - SCHEMA
# ============================================================
def t_medicao_schema():
    cabecalho("2. MEDICAO NUMERICA - schema")

    for col in ['unidade', 'limite_minimo', 'limite_maximo', 'alerta_em', 'chave_medicao']:
        ok = psql(f"SELECT EXISTS(SELECT 1 FROM information_schema.columns "
                  f"WHERE table_name='itens_checklist' AND column_name='{col}');") == 't'
        teste(f"itens_checklist.{col} existe", ok)

    ok = psql("SELECT EXISTS(SELECT 1 FROM information_schema.columns "
              "WHERE table_name='inspecoes_itens' AND column_name='valor_numerico');") == 't'
    teste("inspecoes_itens.valor_numerico existe", ok)

    tipo = psql("SELECT data_type FROM information_schema.columns "
                "WHERE table_name='inspecoes_itens' AND column_name='valor_numerico';")
    teste("valor_numerico eh NUMERIC", tipo == 'numeric', f"tipo: {tipo}")

    ok = psql("SELECT EXISTS(SELECT 1 FROM pg_indexes WHERE indexname='idx_itens_chave_medicao');") == 't'
    teste("Indice idx_itens_chave_medicao criado", ok)


# ============================================================
# 3. MEDICAO NUMERICA - SEED DE LIMITES
# ============================================================
def t_medicao_seed():
    cabecalho("3. MEDICAO NUMERICA - seed de limites")

    n = int(psql("SELECT COUNT(*) FROM itens_checklist WHERE limite_minimo IS NOT NULL;"))
    teste("Limites extraidos do valor_referencia", n >= 300, f"itens com limite: {n}")

    inconsistentes = int(psql("SELECT COUNT(*) FROM itens_checklist "
                              "WHERE unidade IS NOT NULL AND limite_minimo IS NULL;"))
    teste("Sem itens com unidade mas sem limite", inconsistentes == 0,
          f"inconsistentes: {inconsistentes}")

    # Padroes especificos
    v = psql("SELECT limite_minimo FROM itens_checklist "
             "WHERE valor_referencia LIKE '%minima 1,5 mm%' LIMIT 1;")
    teste("Padrao 'minima 1,5 mm' -> 1.5", v == '1.5', f"retornou: {v}")

    v = psql("SELECT limite_minimo||'/'||limite_maximo FROM itens_checklist "
             "WHERE valor_referencia LIKE '%20-30 mm%' LIMIT 1;")
    teste("Padrao faixa '20-30 mm' -> 20/30", v == '20/30', f"retornou: {v}")

    v = psql("SELECT limite_minimo FROM itens_checklist "
             "WHERE valor_referencia LIKE '%> 12,4 V%' LIMIT 1;")
    teste("Padrao '> 12,4 V' -> 12.4", v == '12.4', f"retornou: {v}")

    v = psql("SELECT limite_minimo FROM itens_checklist "
             "WHERE valor_referencia ILIKE '%Minimo 1,5 mm%' LIMIT 1;")
    teste("Padrao 'Minimo' (maiusculo) tambem casa", v == '1.5', f"retornou: {v}")

    # Chaves de medicao
    n_chaves = int(psql("SELECT COUNT(DISTINCT chave_medicao) FROM itens_checklist "
                        "WHERE chave_medicao IS NOT NULL;"))
    teste("Chaves de medicao criadas", n_chaves >= 6, f"chaves distintas: {n_chaves}")

    for chave in ['pastilha_dianteira', 'pastilha_traseira', 'corrente_folga', 'bateria_tensao']:
        n = int(psql(f"SELECT COUNT(*) FROM itens_checklist WHERE chave_medicao='{chave}';"))
        teste(f"Chave '{chave}' aplicada", n > 0, f"itens: {n}")

    # A chave precisa casar descricoes DIFERENTES (o motivo de existir)
    n_desc = int(psql("SELECT COUNT(DISTINCT descricao) FROM itens_checklist "
                      "WHERE chave_medicao='pastilha_dianteira';"))
    teste("Chave casa descricoes diferentes do mesmo item", n_desc >= 2,
          f"descricoes distintas sob a mesma chave: {n_desc}")


# ============================================================
# 4. FUNCAO avaliar_medicao (SEMAFORO)
# ============================================================
def t_semaforo():
    cabecalho("4. SEMAFORO - funcao avaliar_medicao")

    ok = psql("SELECT EXISTS(SELECT 1 FROM pg_proc WHERE proname='avaliar_medicao');") == 't'
    teste("Funcao avaliar_medicao existe", ok)
    if not ok: return

    item = psql("SELECT id FROM itens_checklist WHERE chave_medicao='pastilha_dianteira' "
                "AND limite_minimo=1.5 LIMIT 1;")

    s = psql(f"SELECT semaforo FROM avaliar_medicao({item}, 4.0);")
    teste("4.0mm (limite 1.5, alerta 2.03) -> verde", s == 'verde', f"retornou: {s}")

    s = psql(f"SELECT semaforo FROM avaliar_medicao({item}, 2.0);")
    teste("2.0mm -> amarelo (proximo do limite)", s == 'amarelo', f"retornou: {s}")

    s = psql(f"SELECT semaforo FROM avaliar_medicao({item}, 1.2);")
    teste("1.2mm -> vermelho (abaixo do limite)", s == 'vermelho', f"retornou: {s}")

    s = psql(f"SELECT semaforo FROM avaliar_medicao({item}, NULL);")
    teste("NULL -> sem_limite", s == 'sem_limite', f"retornou: {s}")

    sem_lim = psql("SELECT id FROM itens_checklist WHERE limite_minimo IS NULL LIMIT 1;")
    s = psql(f"SELECT semaforo FROM avaliar_medicao({sem_lim}, 5);")
    teste("Item sem limite -> sem_limite", s == 'sem_limite', f"retornou: {s}")

    s = psql("SELECT semaforo FROM avaliar_medicao(999999, 5);")
    teste("Item inexistente -> sem_limite", s == 'sem_limite', f"retornou: {s}")

    # Limite maximo (faixa)
    item_faixa = psql("SELECT id FROM itens_checklist WHERE limite_minimo=20 "
                      "AND limite_maximo=30 LIMIT 1;")
    s = psql(f"SELECT semaforo FROM avaliar_medicao({item_faixa}, 35);")
    teste("Acima do limite_maximo -> vermelho", s == 'vermelho', f"retornou: {s}")

    s = psql(f"SELECT semaforo FROM avaliar_medicao({item_faixa}, 25);")
    teste("Dentro da faixa -> verde", s == 'verde', f"retornou: {s}")


# ============================================================
# 5. TAXA DE DESGASTE
# ============================================================
def t_desgaste():
    cabecalho("5. TAXA DE DESGASTE")

    ok = psql("SELECT EXISTS(SELECT 1 FROM pg_proc WHERE proname='taxa_desgaste');") == 't'
    teste("Funcao taxa_desgaste existe", ok)
    if not ok: return

    # Cenario: pastilha 4.0mm@5000km -> 2.8mm@10000km, limite 1.5
    # Descricoes DIFERENTES (revisao 500 e revisao 5000) sob a mesma chave
    psql("""
    DO $$
    DECLARE v_moto INT; v_r500 INT; v_r5k INT; v_it1 INT; v_it2 INT; v_i1 UUID; v_i2 UUID;
    BEGIN
      INSERT INTO motos (placa, modelo_id, ano, proprietario, km_atual)
      VALUES ('DSG-0001', 1, 2024, 'Teste Desgaste', 10000)
      ON CONFLICT (placa) DO NOTHING;

      SELECT id INTO v_moto FROM motos WHERE placa='DSG-0001';
      SELECT id INTO v_r500 FROM revisoes WHERE modelo_id=1 AND km=500;
      SELECT id INTO v_r5k  FROM revisoes WHERE modelo_id=1 AND km=5000;
      SELECT id INTO v_it1 FROM itens_checklist
        WHERE revisao_id=v_r500 AND chave_medicao='pastilha_dianteira';
      SELECT id INTO v_it2 FROM itens_checklist
        WHERE revisao_id=v_r5k AND chave_medicao='pastilha_dianteira';

      DELETE FROM inspecoes WHERE moto_id=v_moto;

      INSERT INTO inspecoes (moto_id, revisao_id, km_registrado, status, data_fim)
      VALUES (v_moto, v_r500, 5000, 'finalizada', NOW() - INTERVAL '6 months')
      RETURNING id INTO v_i1;
      INSERT INTO inspecoes_itens (inspecao_id, item_id, status, valor_numerico, valor_medido)
      VALUES (v_i1, v_it1, 'ok', 4.0, '4,0 mm');

      INSERT INTO inspecoes (moto_id, revisao_id, km_registrado, status, data_fim)
      VALUES (v_moto, v_r5k, 10000, 'finalizada', NOW())
      RETURNING id INTO v_i2;
      INSERT INTO inspecoes_itens (inspecao_id, item_id, status, valor_numerico, valor_medido)
      VALUES (v_i2, v_it2, 'ok', 2.8, '2,8 mm');
    END $$;
    """)

    moto = psql("SELECT id FROM motos WHERE placa='DSG-0001';")

    n = psql(f"SELECT COUNT(*) FROM taxa_desgaste({moto}, 'pastilha_dianteira');")
    teste("Retorna resultado com 2 medicoes", n == '1', f"linhas: {n}")

    v = psql(f"SELECT desgaste_por_1000km FROM taxa_desgaste({moto}, 'pastilha_dianteira');")
    teste("Desgaste = 0.24 mm/1000km", v.startswith('0.24'),
          f"(4.0-2.8)*1000/(10000-5000) = 0.24 | retornou: {v}")

    v = psql(f"SELECT km_restantes FROM taxa_desgaste({moto}, 'pastilha_dianteira');")
    teste("Km restantes ~5417", v == '5417',
          f"(2.8-1.5)*1000/0.24 = 5417 | retornou: {v}")

    v = psql(f"SELECT previsao_troca_km FROM taxa_desgaste({moto}, 'pastilha_dianteira');")
    teste("Previsao de troca ~15417 km", v == '15417',
          f"10000+5417 | retornou: {v}")

    v = psql(f"SELECT unidade FROM taxa_desgaste({moto}, 'pastilha_dianteira');")
    teste("Unidade propagada", v == 'mm', f"retornou: {v}")

    # Com uma medicao so, nao ha o que comparar
    n = psql(f"SELECT COUNT(*) FROM taxa_desgaste({moto}, 'bateria_tensao');")
    teste("Sem 2 medicoes -> retorna vazio", n == '0', f"linhas: {n}")

    # View de recomendacoes
    ok = psql("SELECT EXISTS(SELECT 1 FROM information_schema.views "
              "WHERE table_name='vw_recomendacoes_futuras');") == 't'
    teste("View vw_recomendacoes_futuras criada", ok)

    if ok:
        n = psql(f"SELECT COUNT(*) FROM vw_recomendacoes_futuras WHERE moto_id={moto};")
        teste("View retorna linha para a moto", int(n) >= 1, f"linhas: {n}")

        v = psql(f"SELECT recomendacao FROM vw_recomendacoes_futuras "
                 f"WHERE moto_id={moto} AND chave_medicao='pastilha_dianteira';")
        teste("2.8mm (acima do alerta 2.03) -> 'ok'", v == 'ok', f"retornou: {v}")


# ============================================================
# 6. QUEIXA DO CLIENTE
# ============================================================
def t_queixa():
    cabecalho("6. QUEIXA DO CLIENTE + RESOLUCAO")

    for col in ['queixa_cliente', 'resolucao_queixa']:
        ok = psql(f"SELECT EXISTS(SELECT 1 FROM information_schema.columns "
                  f"WHERE table_name='inspecoes' AND column_name='{col}');") == 't'
        teste(f"inspecoes.{col} existe", ok)

    insp = psql("SELECT id FROM inspecoes ORDER BY criado_em DESC LIMIT 1;")
    psql(f"""UPDATE inspecoes SET
             queixa_cliente='Barulho na frente quando freia',
             resolucao_queixa='Pastilha dianteira gasta (1,2mm), substituida'
             WHERE id='{insp}';""")

    v = psql(f"SELECT queixa_cliente FROM inspecoes WHERE id='{insp}';")
    teste("Queixa persiste", 'Barulho na frente' in v, f"retornou: {v[:40]}")

    v = psql(f"SELECT resolucao_queixa FROM inspecoes WHERE id='{insp}';")
    teste("Resolucao persiste", 'substituida' in v, f"retornou: {v[:40]}")

    # UI
    html = (RAIZ / 'inspecao.html').read_text()
    teste("inspecao.html tem campo de queixa", 'input-queixa' in html)
    teste("inspecao.html tem campo de resolucao", 'input-resolucao' in html)
    teste("Queixa gravada ao criar inspecao", 'queixa_cliente:' in html)
    teste("Resolucao gravada ao finalizar", 'resolucao_queixa:' in html)
    teste("Bloco de resolucao exibe a queixa", 'texto-queixa' in html)

    js = (RAIZ / 'src' / 'inspecao.js').read_text()
    teste("criarInspecao aceita queixa_cliente", 'queixa_cliente' in js)

    pdf = (RAIZ / 'src' / 'pdf.js').read_text()
    teste("PDF tem secao RELATO DO CLIENTE", 'RELATO DO CLIENTE' in pdf)
    teste("PDF coleta queixa e resolucao", 'queixa_cliente' in pdf and 'resolucao_queixa' in pdf)


# ============================================================
# 7. ITENS AVULSOS
# ============================================================
def t_avulsos():
    cabecalho("7. ITENS AVULSOS FORA DO CHECKLIST")

    nul = psql("SELECT is_nullable FROM information_schema.columns "
               "WHERE table_name='inspecoes_itens' AND column_name='item_id';")
    teste("inspecoes_itens.item_id eh nullable", nul == 'YES', f"is_nullable: {nul}")

    for col in ['descricao_avulsa', 'categoria_avulsa']:
        ok = psql(f"SELECT EXISTS(SELECT 1 FROM information_schema.columns "
                  f"WHERE table_name='inspecoes_itens' AND column_name='{col}');") == 't'
        teste(f"inspecoes_itens.{col} existe", ok)

    ok = psql("SELECT EXISTS(SELECT 1 FROM pg_constraint WHERE conname='chk_item_ou_avulso');") == 't'
    teste("Constraint chk_item_ou_avulso criada", ok)

    insp = psql("SELECT id FROM inspecoes ORDER BY criado_em DESC LIMIT 1;")

    psql(f"""INSERT INTO inspecoes_itens
             (inspecao_id, item_id, descricao_avulsa, categoria_avulsa, status, observacao)
             VALUES ('{insp}', NULL, 'Retrovisor direito folgado', 'Adicional', 'nao_ok', 'Rosca espanada');""")
    n = psql(f"SELECT COUNT(*) FROM inspecoes_itens WHERE inspecao_id='{insp}' AND item_id IS NULL;")
    teste("Avulso inserido com item_id NULL", int(n) >= 1, f"avulsos: {n}")

    # Varios avulsos na mesma inspecao (UNIQUE com NULL nao conflita)
    psql(f"""INSERT INTO inspecoes_itens
             (inspecao_id, item_id, descricao_avulsa, status)
             VALUES ('{insp}', NULL, 'Adesivo do tanque descolando', 'nao_ok');""")
    n = psql(f"SELECT COUNT(*) FROM inspecoes_itens WHERE inspecao_id='{insp}' AND item_id IS NULL;")
    teste("Multiplos avulsos na mesma inspecao", int(n) >= 2, f"avulsos: {n}")

    # Constraint bloqueia avulso sem descricao
    cmd = ['psql', '-h', os.environ.get('PGHOST','/tmp'), '-p', os.environ.get('PGPORT','5433'),
           '-U', os.environ.get('PGUSER','postgres'),
           '-d', os.environ.get('PGDATABASE','revisao_moto_test'),
           '-c', f"INSERT INTO inspecoes_itens (inspecao_id, item_id, status) VALUES ('{insp}', NULL, 'ok');"]
    r = subprocess.run(cmd, capture_output=True, text=True)
    teste("Avulso sem descricao eh rejeitado",
          r.returncode != 0 and 'chk_item_ou_avulso' in r.stderr,
          'constraint bloqueou')

    # View unificada
    ok = psql("SELECT EXISTS(SELECT 1 FROM information_schema.views "
              "WHERE table_name='vw_inspecao_itens_completo');") == 't'
    teste("View vw_inspecao_itens_completo criada", ok)

    if ok:
        n = psql(f"SELECT COUNT(*) FROM vw_inspecao_itens_completo "
                 f"WHERE inspecao_id='{insp}' AND eh_avulso;")
        teste("View marca eh_avulso corretamente", int(n) >= 2, f"avulsos na view: {n}")

        v = psql(f"SELECT categoria FROM vw_inspecao_itens_completo "
                 f"WHERE inspecao_id='{insp}' AND descricao='Adesivo do tanque descolando';")
        teste("Categoria default 'Adicional' quando nao informada", v == 'Adicional', f"retornou: {v}")

        v = psql(f"SELECT semaforo FROM vw_inspecao_itens_completo "
                 f"WHERE inspecao_id='{insp}' AND eh_avulso LIMIT 1;")
        teste("Avulso sem medicao -> semaforo 'sem_limite'", v == 'sem_limite', f"retornou: {v}")

    # Modulo JS
    js = RAIZ / 'src' / 'avulsos.js'
    teste("src/avulsos.js existe", js.exists())
    if js.exists():
        ok_s, err = node_check(js)
        teste("avulsos.js sintaxe valida", ok_s, err[:120])
        c = js.read_text()
        for fn in ['adicionarAvulso', 'removerAvulso', 'listarAvulsos', 'listarTodosItens']:
            teste(f"avulsos.js exporta {fn}", fn in c and 'window.avulsos' in c)

    html = (RAIZ / 'inspecao.html').read_text()
    teste("inspecao.html tem botao de adicionar avulso", 'abrirModalAvulso' in html)
    teste("inspecao.html tem modal de avulso", 'modal-avulso' in html)

    pdf = (RAIZ / 'src' / 'pdf.js').read_text()
    teste("PDF tem secao ITENS ADICIONAIS", 'ITENS ADICIONAIS' in pdf)


# ============================================================
# 8. PECAS E ORCAMENTO
# ============================================================
def t_orcamento():
    cabecalho("8. PECAS E ORCAMENTO")

    for tab in ['pecas', 'inspecao_pecas', 'inspecao_servicos']:
        ok = psql(f"SELECT EXISTS(SELECT 1 FROM information_schema.tables "
                  f"WHERE table_name='{tab}');") == 't'
        teste(f"Tabela {tab} criada", ok)

    n = int(psql("SELECT COUNT(*) FROM pecas;"))
    teste("Catalogo de pecas populado", n >= 10, f"pecas: {n}")

    for tab in ['pecas', 'inspecao_pecas', 'inspecao_servicos']:
        ok = psql(f"SELECT relrowsecurity FROM pg_class WHERE relname='{tab}';") == 't'
        teste(f"RLS habilitado em {tab}", ok)

    for col in ['assinatura_orcamento', 'nome_aprovador_orcamento', 'orcamento_aprovado_em']:
        ok = psql(f"SELECT EXISTS(SELECT 1 FROM information_schema.columns "
                  f"WHERE table_name='inspecoes' AND column_name='{col}');") == 't'
        teste(f"inspecoes.{col} existe", ok)

    ok = psql("SELECT EXISTS(SELECT 1 FROM information_schema.views "
              "WHERE table_name='vw_orcamento_inspecao');") == 't'
    teste("View vw_orcamento_inspecao criada", ok)

    # --- Cenario de orcamento ---
    insp = psql("SELECT id FROM inspecoes ORDER BY criado_em DESC LIMIT 1;")
    psql(f"DELETE FROM inspecao_pecas WHERE inspecao_id='{insp}';")
    psql(f"DELETE FROM inspecao_servicos WHERE inspecao_id='{insp}';")

    psql(f"""INSERT INTO inspecao_pecas (inspecao_id, peca_id, quantidade, preco_aplicado)
             SELECT '{insp}', id, 1, 239.90 FROM pecas WHERE codigo_re='PAST-D';""")
    psql(f"""INSERT INTO inspecao_pecas (inspecao_id, peca_id, quantidade, preco_aplicado)
             SELECT '{insp}', id, 3, 78.00 FROM pecas WHERE codigo_re='OLEO15W50';""")
    psql(f"""INSERT INTO inspecao_pecas (inspecao_id, descricao_livre, quantidade, preco_aplicado)
             VALUES ('{insp}', 'Parafuso fora do catalogo', 2, 15.00);""")
    psql(f"""INSERT INTO inspecao_servicos (inspecao_id, descricao, horas, valor_hora)
             VALUES ('{insp}', 'Troca de pastilhas', 1.5, 120.00),
                    ('{insp}', 'Revisao 10.000 km', 2.0, 120.00);""")

    v = psql(f"SELECT total_pecas FROM vw_orcamento_inspecao WHERE inspecao_id='{insp}';")
    teste("Total de pecas = 503.90", float(v) == 503.90,
          f"239.90 + 3x78.00 + 2x15.00 | retornou: {v}")

    v = psql(f"SELECT total_servicos FROM vw_orcamento_inspecao WHERE inspecao_id='{insp}';")
    teste("Total de servicos = 420.00", float(v) == 420.00,
          f"3.5h x 120 | retornou: {v}")

    v = psql(f"SELECT total_geral FROM vw_orcamento_inspecao WHERE inspecao_id='{insp}';")
    teste("Total geral = 923.90", float(v) == 923.90, f"retornou: {v}")

    v = psql(f"SELECT total_horas FROM vw_orcamento_inspecao WHERE inspecao_id='{insp}';")
    teste("Total de horas = 3.5", float(v) == 3.5, f"retornou: {v}")

    v = psql(f"SELECT qtd_pecas FROM vw_orcamento_inspecao WHERE inspecao_id='{insp}';")
    teste("Quantidade de linhas de peca = 3", v == '3', f"retornou: {v}")

    # Peca fora do catalogo
    n = psql(f"SELECT COUNT(*) FROM inspecao_pecas "
             f"WHERE inspecao_id='{insp}' AND peca_id IS NULL AND descricao_livre IS NOT NULL;")
    teste("Aceita peca fora do catalogo (descricao_livre)", int(n) == 1, f"linhas: {n}")

    # --- Aprovacao previa ---
    v = psql(f"SELECT orcamento_aprovado FROM vw_orcamento_inspecao WHERE inspecao_id='{insp}';")
    teste("Orcamento comeca NAO aprovado", v == 'f', f"retornou: {v}")

    psql(f"""UPDATE inspecoes SET
             assinatura_orcamento = repeat('iVBORw0KGgoAAAANS', 12),
             nome_aprovador_orcamento = 'Cliente Teste',
             orcamento_aprovado_em = NOW()
             WHERE id='{insp}';""")

    v = psql(f"SELECT orcamento_aprovado FROM vw_orcamento_inspecao WHERE inspecao_id='{insp}';")
    teste("Apos assinatura -> aprovado", v == 't', f"retornou: {v}")

    v = psql(f"SELECT nome_aprovador_orcamento FROM vw_orcamento_inspecao WHERE inspecao_id='{insp}';")
    teste("Nome do aprovador registrado", v == 'Cliente Teste', f"retornou: {v}")

    # Assinatura curta nao conta como aprovacao
    psql(f"UPDATE inspecoes SET assinatura_orcamento='abc' WHERE id='{insp}';")
    v = psql(f"SELECT orcamento_aprovado FROM vw_orcamento_inspecao WHERE inspecao_id='{insp}';")
    teste("Assinatura curta nao aprova", v == 'f', f"retornou: {v}")

    # CASCADE
    n_antes = psql(f"SELECT COUNT(*) FROM inspecao_pecas WHERE inspecao_id='{insp}';")
    teste("Pecas existem antes do delete", int(n_antes) == 3)

    # Modulo JS
    js = RAIZ / 'src' / 'orcamento.js'
    teste("src/orcamento.js existe", js.exists())
    if js.exists():
        ok_s, err = node_check(js)
        teste("orcamento.js sintaxe valida", ok_s, err[:120])
        c = js.read_text()
        for fn in ['adicionarPeca', 'adicionarServico', 'totaisDoOrcamento',
                   'aprovarOrcamento', 'podeExecutar', 'calcularTotaisLocal']:
            teste(f"orcamento.js exporta {fn}", fn in c and 'window.orcamento' in c)
        teste("orcamento.js formata em BRL", 'BRL' in c)
        teste("orcamento.js copia preco (nao referencia)", 'preco_aplicado' in c)
        teste("orcamento.js cita CDC art. 40", 'art. 40' in c or 'CDC' in c)

    html = (RAIZ / 'inspecao.html').read_text()
    teste("inspecao.html tem bloco de orcamento", 'bloco-orcamento' in html)
    teste("inspecao.html tem modal de peca", 'modal-peca' in html)
    teste("inspecao.html tem modal de servico", 'modal-servico' in html)
    teste("inspecao.html tem modal de aprovacao", 'modal-aprovacao' in html)
    teste("inspecao.html bloqueia fim sem aprovacao", 'podeExecutar' in html)

    pdf = (RAIZ / 'src' / 'pdf.js').read_text()
    teste("PDF tem secao ORCAMENTO", 'ORCAMENTO' in pdf)
    teste("PDF mostra total geral", 'total_geral' in pdf)
    teste("PDF informa status da aprovacao", 'orcamento_aprovado' in pdf)


# ============================================================
# 9. MODULO medicoes.js
# ============================================================
def t_modulo_medicoes():
    cabecalho("9. MODULO src/medicoes.js")

    js = RAIZ / 'src' / 'medicoes.js'
    teste("Arquivo existe", js.exists())
    if not js.exists(): return

    ok, err = node_check(js)
    teste("Sintaxe valida", ok, err[:120])

    c = js.read_text()
    for fn in ['avaliarLocal', 'normalizarNumero', 'aplicarSemaforo',
               'textoReferencia', 'buscarDesgaste', 'formatarPrevisao']:
        teste(f"Exporta {fn}", fn in c and 'window.medicoes' in c)

    teste("Trata virgula decimal (pt-BR)", "replace(',', '.')" in c)
    teste("Define cores dos 4 estados",
          all(s in c for s in ['verde', 'amarelo', 'vermelho', 'sem_limite']))
    teste("Chama RPC taxa_desgaste", 'taxa_desgaste' in c)
    teste("Usa chave_medicao (nao descricao)", 'chave_medicao' in c or 'p_chave' in c)
    teste("Consulta vw_recomendacoes_futuras", 'vw_recomendacoes_futuras' in c)

    # Avaliacao local espelha a regra SQL
    teste("Compara com limite_minimo", 'limite_minimo' in c)
    teste("Compara com limite_maximo", 'limite_maximo' in c)
    teste("Compara com alerta_em", 'alerta_em' in c)


# ============================================================
# 10. INTEGRACAO
# ============================================================
def t_integracao():
    cabecalho("10. INTEGRACAO")

    html = (RAIZ / 'inspecao.html').read_text()
    for m in ['medicoes.js', 'avulsos.js', 'orcamento.js']:
        teste(f"inspecao.html importa {m}", f'src/{m}' in html)

    teste("Campo de medicao aplica semaforo", 'aplicarSemaforo' in html)
    teste("Campo de medicao mostra desgaste", 'mostrarDesgaste' in html)
    teste("marcarMedida grava valor_numerico", 'valor_numerico' in html)

    js = (RAIZ / 'src' / 'inspecao.js').read_text()
    teste("inspecao.js carrega valor_numerico", 'valor_numerico' in js)

    # View de checklist expoe os campos novos
    for col in ['unidade', 'limite_minimo', 'chave_medicao']:
        ok = psql(f"SELECT EXISTS(SELECT 1 FROM information_schema.columns "
                  f"WHERE table_name='vw_checklist_completo' AND column_name='{col}');") == 't'
        teste(f"vw_checklist_completo expoe {col}", ok)

    # Service worker
    sw = (RAIZ / 'service-worker.js').read_text()
    for m in ['medicoes.js', 'avulsos.js', 'orcamento.js']:
        teste(f"APP_SHELL contem {m}", m in sw)
    _mv = re.search(r"CACHE_VERSION\s*=\s*'v(\d+)\.(\d+)", sw)
    _ver = (int(_mv.group(1)), int(_mv.group(2))) if _mv else (0, 0)
    _vtxt = _mv.group(0).split("'")[-1] if _mv else '?'
    teste("SW versao v0.8+", _ver >= (0, 8), _vtxt)


# ============================================================
def resumo():
    print(f"\n{Cor.NEG}{'='*70}{Cor.RESET}")
    print(f"{Cor.NEG}  RESUMO FASE 8 (P1){Cor.RESET}")
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
    print(f"{Cor.NEG}REVISAO-MOTO :: Testes da Fase 8 (P1) - Operacao Real{Cor.RESET}")
    if not t_migration(): return 1
    t_medicao_schema()
    t_medicao_seed()
    t_semaforo()
    t_desgaste()
    t_queixa()
    t_avulsos()
    t_orcamento()
    t_modulo_medicoes()
    t_integracao()
    return resumo()


if __name__ == '__main__':
    sys.exit(main())

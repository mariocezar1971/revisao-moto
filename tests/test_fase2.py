#!/usr/bin/env python3
"""
========================================================================
REVISAO-MOTO :: Suite de testes da Fase 2
========================================================================
Valida CRUD de motos: estrutura, INSERT, UPDATE, soft delete, views,
filtros e paginacao.

Modos:
  - LOCAL : usa PGHOST/PGPORT (rodado pelo run_tests.sh)
  - REMOTE: usa .env com credenciais Supabase (TODO em versao futura)

Uso:
  python3 tests/test_fase2.py            # auto-detecta
  python3 tests/test_fase2.py --local
========================================================================
"""

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

def limpar_motos_teste():
    """Remove motos com placa que comeca com 'TST' usadas nos testes."""
    psql("DELETE FROM motos WHERE placa LIKE 'TST-%';")

# ============================================================
# 1. MIGRATION (003_fase2_motos_ativo.sql)
# ============================================================
def testar_migration():
    cabecalho("1. MIGRATION (003_fase2_motos_ativo.sql)")

    arquivo = RAIZ / 'sql' / '003_fase2_motos_ativo.sql'
    teste("Arquivo da migration existe", arquivo.exists())

    codigo, _, stderr = psql_arquivo(arquivo)
    teste("Migration executa sem erro", codigo == 0,
          stderr if codigo != 0 else 'OK')
    if codigo != 0:
        return False

    # Reexecuta para confirmar idempotencia
    codigo2, _, stderr2 = psql_arquivo(arquivo)
    teste("Migration eh idempotente (roda 2x)", codigo2 == 0,
          stderr2 if codigo2 != 0 else 'OK')

    return True

# ============================================================
# 2. ESTRUTURA APOS MIGRATION
# ============================================================
def testar_estrutura():
    cabecalho("2. ESTRUTURA APOS MIGRATION")

    # Campo ativo existe e eh BOOLEAN NOT NULL
    info = psql("""
        SELECT data_type, is_nullable, column_default
        FROM information_schema.columns
        WHERE table_name='motos' AND column_name='ativo';
    """)
    teste("Campo motos.ativo existe", 'boolean' in info,
          f"info: {info}")
    teste("motos.ativo eh NOT NULL", 'NO' in info,
          f"is_nullable: {info}")
    teste("motos.ativo default = TRUE", 'true' in info.lower(),
          f"default: {info}")

    # Indice
    n_idx = int(psql("""
        SELECT COUNT(*) FROM pg_indexes
        WHERE schemaname='public' AND indexname='idx_motos_ativo';
    """))
    teste("Indice idx_motos_ativo criado", n_idx == 1)

    # Views
    for v in ['vw_motos_status', 'vw_motos_arquivadas']:
        existe = psql(f"""
            SELECT EXISTS(SELECT 1 FROM information_schema.views
            WHERE table_schema='public' AND table_name='{v}');
        """) == 't'
        teste(f"View existe: {v}", existe)

    # Funcao reativar_moto
    existe = psql("SELECT EXISTS(SELECT 1 FROM pg_proc WHERE proname='reativar_moto');") == 't'
    teste("Funcao reativar_moto criada", existe)

# ============================================================
# 3. CRUD: CADASTRO
# ============================================================
def testar_cadastro():
    cabecalho("3. CRUD - CADASTRO")
    limpar_motos_teste()

    # Insert valido
    try:
        psql("""
            INSERT INTO motos (placa, modelo_id, ano, cor, proprietario, telefone, km_atual)
            SELECT 'TST-0001', m.id, 2024, 'Vermelho', 'Mario Teste', '(27) 99999-0001', 5000
            FROM modelos m WHERE m.nome='Shotgun 650';
        """)
        teste("Insert basico funciona", True)
    except RuntimeError as e:
        teste("Insert basico funciona", False, str(e))
        return

    # Validar dados inseridos
    placa = psql("SELECT placa FROM motos WHERE placa='TST-0001';")
    teste("Moto cadastrada acessivel", placa == 'TST-0001')

    ativo = psql("SELECT ativo FROM motos WHERE placa='TST-0001';")
    teste("Campo ativo default = TRUE", ativo == 't')

    # Placa duplicada deve falhar
    try:
        psql("INSERT INTO motos (placa, modelo_id) SELECT 'TST-0001', 1;")
        teste("Placa duplicada falha (constraint UNIQUE)", False, "deveria ter falhado")
    except RuntimeError as e:
        teste("Placa duplicada falha (constraint UNIQUE)", 'duplicate' in str(e).lower())

    # Insert mais 4 motos para testes seguintes
    psql("""
        INSERT INTO motos (placa, modelo_id, ano, proprietario, km_atual)
        SELECT 'TST-0002', m.id, 2023, 'Joao Silva', 15000 FROM modelos m WHERE m.nome='Classic 350';
    """)
    psql("""
        INSERT INTO motos (placa, modelo_id, ano, proprietario, km_atual)
        SELECT 'TST-0003', m.id, 2025, 'Pedro Souza', 1000 FROM modelos m WHERE m.nome='Interceptor 650';
    """)
    psql("""
        INSERT INTO motos (placa, modelo_id, ano, proprietario, km_atual)
        SELECT 'TST-0004', m.id, 2022, 'Maria Oliveira', 30000 FROM modelos m WHERE m.nome='Himalayan 450';
    """)
    psql("""
        INSERT INTO motos (placa, modelo_id, ano, proprietario, km_atual)
        SELECT 'TST-0005', m.id, 2024, 'Carlos Mendes', 8000 FROM modelos m WHERE m.nome='Hunter 350';
    """)
    n = int(psql("SELECT COUNT(*) FROM motos WHERE placa LIKE 'TST-%';"))
    teste("5 motos de teste cadastradas", n == 5, f"encontradas: {n}")

# ============================================================
# 4. CRUD: EDICAO
# ============================================================
def testar_edicao():
    cabecalho("4. CRUD - EDICAO")

    # Atualiza km_atual
    psql("UPDATE motos SET km_atual = 10000 WHERE placa = 'TST-0001';")
    novo_km = int(psql("SELECT km_atual FROM motos WHERE placa='TST-0001';"))
    teste("Atualizacao de km_atual", novo_km == 10000, f"km: {novo_km}")

    # Trigger atualizou atualizado_em?
    import time
    antes = psql("SELECT atualizado_em FROM motos WHERE placa='TST-0001';")
    time.sleep(1.1)
    psql("UPDATE motos SET cor='Preto' WHERE placa='TST-0001';")
    depois = psql("SELECT atualizado_em FROM motos WHERE placa='TST-0001';")
    teste("Trigger atualiza atualizado_em",
          antes != depois, f"antes: {antes[:19]} | depois: {depois[:19]}")

    # Atualiza varios campos
    psql("""
        UPDATE motos SET
            proprietario = 'Mario Cezar Santos Jr.',
            telefone = '(27) 91234-5678',
            email = 'mario@ifes.edu.br',
            observacoes = 'Teste de edicao'
        WHERE placa='TST-0001';
    """)
    valor = psql("SELECT email FROM motos WHERE placa='TST-0001';")
    teste("Edicao multipla de campos", valor == 'mario@ifes.edu.br', f"email: {valor}")

# ============================================================
# 5. SOFT DELETE
# ============================================================
def testar_soft_delete():
    cabecalho("5. SOFT DELETE")

    # Arquiva moto
    psql("UPDATE motos SET ativo = FALSE WHERE placa = 'TST-0002';")

    # Linha ainda existe na tabela
    existe = psql("SELECT EXISTS(SELECT 1 FROM motos WHERE placa='TST-0002');") == 't'
    teste("Moto arquivada AINDA existe na tabela motos", existe)

    # Mas nao aparece em vw_motos_status
    em_status = psql("SELECT EXISTS(SELECT 1 FROM vw_motos_status WHERE placa='TST-0002');") == 't'
    teste("Moto arquivada NAO aparece em vw_motos_status",
          em_status == False, f"deveria sumir da view de ativas")

    # Aparece em vw_motos_arquivadas
    em_arq = psql("SELECT EXISTS(SELECT 1 FROM vw_motos_arquivadas WHERE placa='TST-0002');") == 't'
    teste("Moto arquivada APARECE em vw_motos_arquivadas", em_arq)

    # Reativacao via funcao
    reativou = psql("SELECT reativar_moto('TST-0002');") == 't'
    teste("Funcao reativar_moto retorna TRUE", reativou)

    em_status2 = psql("SELECT EXISTS(SELECT 1 FROM vw_motos_status WHERE placa='TST-0002');") == 't'
    teste("Moto reativada VOLTA para vw_motos_status", em_status2)

    # Reativar inexistente retorna FALSE
    sem_efeito = psql("SELECT reativar_moto('XXX-9999');") == 'f'
    teste("Reativar moto inexistente retorna FALSE", sem_efeito)

# ============================================================
# 6. FILTROS E PAGINACAO
# ============================================================
def testar_filtros():
    cabecalho("6. FILTROS")

    # Filtro por placa
    n = int(psql("""
        SELECT COUNT(*) FROM vw_motos_status
        WHERE placa ILIKE '%TST%';
    """))
    teste("Filtro por placa ILIKE", n == 5, f"encontradas: {n}")

    # Filtro por proprietario
    n_pedro = int(psql("""
        SELECT COUNT(*) FROM vw_motos_status
        WHERE proprietario ILIKE '%Pedro%';
    """))
    teste("Filtro por proprietario ILIKE", n_pedro == 1, f"Pedro: {n_pedro}")

    # Combinado
    n_combo = int(psql("""
        SELECT COUNT(*) FROM vw_motos_status
        WHERE placa ILIKE '%TST%' AND proprietario ILIKE '%Mario%';
    """))
    teste("Filtros combinados (placa + prop)", n_combo == 1, f"encontradas: {n_combo}")

# ============================================================
# 7. VIEW vw_motos_status: COLUNAS NOVAS
# ============================================================
def testar_view_status():
    cabecalho("7. VIEW vw_motos_status (colunas enriquecidas)")

    colunas = psql("""
        SELECT string_agg(column_name, ',' ORDER BY column_name)
        FROM information_schema.columns
        WHERE table_schema='public' AND table_name='vw_motos_status';
    """).split(',')

    esperadas = ['placa', 'modelo', 'plataforma', 'proprietario', 'telefone',
                 'email', 'ano', 'cor', 'km_atual', 'data_compra',
                 'chassi', 'renavam', 'observacoes', 'modelo_id',
                 'total_inspecoes', 'ultima_inspecao', 'km_ultima_inspecao']
    for c in esperadas:
        teste(f"vw_motos_status tem coluna '{c}'", c in colunas)

# ============================================================
# 8. CLEANUP + UI VALIDATION
# ============================================================
def testar_ui():
    cabecalho("8. UI (admin.html)")
    admin = RAIZ / 'admin.html'
    teste("admin.html existe", admin.exists())
    if not admin.exists():
        return

    html = admin.read_text(encoding='utf-8')
    teste("admin.html tem DOCTYPE", html.lstrip().startswith('<!DOCTYPE'))
    teste("admin.html eh PWA (manifest)", 'manifest.json' in html)
    teste("Referencia Supabase JS", 'supabase-js' in html)
    teste("Tem formulario de moto (form-moto)", 'form-moto' in html)
    teste("Tem modal de km", 'modal-km' in html)
    teste("Tem modal de delete", 'modal-delete' in html)
    teste("Tem filtro de placa", 'filtro-placa' in html)
    teste("Tem filtro de proprietario", 'filtro-proprietario' in html)
    teste("Tem paginacao (PAGE_SIZE)", 'PAGE_SIZE' in html)
    teste("Funcao salvarMoto definida", 'function salvarMoto' in html)
    teste("Funcao confirmarDelete definida", 'function confirmarDelete' in html)
    teste("Funcao reativarMoto definida", 'function reativarMoto' in html)
    teste("Exige login (exigirLogin)", 'exigirLogin' in html)
    teste("Trata erro 23505 (placa duplicada)", "23505" in html)
    teste("Validacao de placa (pattern)", 'pattern=' in html)

    # Sintaxe JS embutido
    import subprocess
    # Extrai scripts inline e valida com node
    import re
    scripts_inline = re.findall(r'<script>([\s\S]*?)</script>', html)
    if scripts_inline:
        tmpfile = '/tmp/admin_inline.js'
        with open(tmpfile, 'w') as f:
            f.write(scripts_inline[-1])  # ultimo bloco eh o app
        res = subprocess.run(['node', '--check', tmpfile], capture_output=True, text=True)
        teste("JS inline tem sintaxe valida (node --check)",
              res.returncode == 0,
              res.stderr.strip() if res.returncode != 0 else 'OK')

    # Cleanup
    limpar_motos_teste()

# ============================================================
# RESUMO
# ============================================================
def resumo():
    print(f"\n{Cor.NEGRITO}{'=' * 70}{Cor.RESET}")
    print(f"{Cor.NEGRITO}  RESUMO FASE 2{Cor.RESET}")
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

# ============================================================
# MAIN
# ============================================================
def main():
    print(f"{Cor.NEGRITO}REVISAO-MOTO :: Testes da Fase 2{Cor.RESET}")
    if not testar_migration():
        return 1
    testar_estrutura()
    testar_cadastro()
    testar_edicao()
    testar_soft_delete()
    testar_filtros()
    testar_view_status()
    testar_ui()
    return resumo()

if __name__ == '__main__':
    sys.exit(main())

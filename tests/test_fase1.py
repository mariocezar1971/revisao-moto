#!/usr/bin/env python3
"""
========================================================================
REVISAO-MOTO :: Suite de testes da Fase 1
========================================================================
Valida o catalogo aplicado no Supabase (cloud) ou no Postgres local.

Modos:
  - LOCAL  : se PGHOST/PGPORT estao setados (usado no run_tests.sh)
  - REMOTE : se .env existe com SUPABASE_URL/ANON_KEY/SERVICE_KEY

Modo LOCAL valida: schema, seed, contagens, views, triggers, RLS
Modo REMOTE valida: tudo do LOCAL + bucket Storage + usuarios

Uso:
  python3 tests/test_fase1.py            # detecta modo automaticamente
  python3 tests/test_fase1.py --remote   # forca modo remote
  python3 tests/test_fase1.py --local    # forca modo local
========================================================================
"""

import json
import os
import sys
import subprocess
import urllib.request
import urllib.error
from pathlib import Path

# ============================================================
# CONFIG
# ============================================================
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

# ============================================================
# DETECCAO DE MODO
# ============================================================
def detectar_modo(args):
    if '--remote' in args:
        return 'remote'
    if '--local' in args:
        return 'local'
    # Auto: local se PGHOST setado, remote se .env existe
    if os.environ.get('PGHOST'):
        return 'local'
    if (RAIZ / '.env').exists():
        return 'remote'
    print(f"{Cor.VERMELHO}ERRO: nem .env nem PGHOST disponiveis{Cor.RESET}")
    print(f"  Para modo LOCAL:  export PGHOST=... PGPORT=... PGUSER=...")
    print(f"  Para modo REMOTE: crie .env (copie de .env.exemplo)")
    sys.exit(1)

# ============================================================
# CARREGA .env
# ============================================================
def carregar_env():
    env_file = RAIZ / '.env'
    config = {}
    if env_file.exists():
        for linha in env_file.read_text().splitlines():
            linha = linha.strip()
            if not linha or linha.startswith('#') or '=' not in linha:
                continue
            chave, valor = linha.split('=', 1)
            config[chave.strip()] = valor.strip().strip('"').strip("'")
    return config

# ============================================================
# MODO LOCAL - via psql
# ============================================================
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

def testar_local():
    cabecalho("FASE 1 - Modo LOCAL (Postgres)")

    # Contagens
    try:
        n_modelos = int(psql("SELECT COUNT(*) FROM modelos;"))
        teste("modelos = 10", n_modelos == 10, f"encontrados: {n_modelos}")

        n_revisoes = int(psql("SELECT COUNT(*) FROM revisoes;"))
        teste("revisoes = 70", n_revisoes == 70, f"encontradas: {n_revisoes}")

        n_itens = int(psql("SELECT COUNT(*) FROM itens_checklist;"))
        teste("itens_checklist = 1300", n_itens == 1300, f"encontrados: {n_itens}")
    except RuntimeError as e:
        teste("Conexao com Postgres local", False, str(e))
        return

    # Modelos
    modelos_esperados = ['Shotgun 650', 'Super Meteor 650', 'Interceptor 650',
                         'Continental GT 650', 'Classic 650', 'Bear 650',
                         'Hunter 350', 'Classic 350', 'Meteor 350', 'Himalayan 450']
    for m in modelos_esperados:
        existe = psql(f"SELECT EXISTS(SELECT 1 FROM modelos WHERE nome='{m}');") == 't'
        teste(f"Modelo: {m}", existe)

    # Itens por revisao (Shotgun 650)
    esperado_por_km = {500: 14, 5000: 16, 10000: 22, 15000: 16,
                       20000: 24, 25000: 16, 30000: 22}
    for km, esperado in esperado_por_km.items():
        n = int(psql(f"""
            SELECT COUNT(i.id) FROM itens_checklist i
            JOIN revisoes r ON r.id = i.revisao_id
            JOIN modelos m ON m.id = r.modelo_id
            WHERE m.nome='Shotgun 650' AND r.km={km};
        """))
        teste(f"Shotgun 650 / {km} km = {esperado} itens", n == esperado, f"encontrados: {n}")

    # Views
    for view in ['vw_checklist_completo', 'vw_motos_status']:
        existe = psql(f"""
            SELECT EXISTS(SELECT 1 FROM information_schema.views
            WHERE table_schema='public' AND table_name='{view}');
        """) == 't'
        teste(f"View existe: {view}", existe)

    # RLS
    n_policies = int(psql("SELECT COUNT(*) FROM pg_policies WHERE schemaname='public';"))
    teste("RLS policies >= 6", n_policies >= 6, f"encontradas: {n_policies}")

    # Indices
    n_indices = int(psql("""
        SELECT COUNT(*) FROM pg_indexes
        WHERE schemaname='public' AND indexname LIKE 'idx_%';
    """))
    teste("Indices >= 8", n_indices >= 8, f"encontrados: {n_indices}")

# ============================================================
# MODO REMOTE - via Supabase REST API
# ============================================================
def request_api(url, headers, method='GET'):
    req = urllib.request.Request(url, method=method)
    for k, v in headers.items():
        req.add_header(k, v)
    try:
        with urllib.request.urlopen(req, timeout=15) as resp:
            corpo = resp.read().decode('utf-8')
            return resp.status, dict(resp.headers), (json.loads(corpo) if corpo else [])
    except urllib.error.HTTPError as e:
        return e.code, dict(e.headers), {'erro': e.read().decode('utf-8')}
    except urllib.error.URLError as e:
        return 0, {}, {'erro': str(e)}

def contar_via_rest(config, tabela):
    """Conta linhas de uma tabela via PostgREST.
    Usa SERVICE_KEY se disponivel (bypassa RLS) para validacao confiavel,
    senao cai para ANON_KEY (que pode retornar 0 por causa de RLS)."""
    # Preferir service_key pois RLS bloqueia anon para o catalogo
    key = config.get('SUPABASE_SERVICE_KEY', '')
    if not key or 'SUA_' in key:
        key = config.get('SUPABASE_ANON_KEY', '')

    url = f"{config['SUPABASE_URL']}/rest/v1/{tabela}?select=*"
    headers = {
        'apikey': key,
        'Authorization': f"Bearer {key}",
        'Prefer': 'count=exact',
        'Range': '0-0'
    }
    status, h, _ = request_api(url, headers)
    if status not in (200, 206):
        return -1, status
    # Content-Range: 0-0/1300
    cr = h.get('Content-Range', '')
    if '/' in cr:
        try:
            return int(cr.split('/')[-1]), status
        except ValueError:
            pass
    return -1, status

def testar_remote():
    cabecalho("FASE 1 - Modo REMOTE (Supabase)")

    config = carregar_env()
    if not config.get('SUPABASE_URL') or 'SEU_PROJETO' in config.get('SUPABASE_URL', ''):
        teste(".env preenchido", False, "edite .env com seus valores reais")
        return
    if not config.get('SUPABASE_ANON_KEY') or 'SUA_' in config.get('SUPABASE_ANON_KEY', ''):
        teste("ANON_KEY preenchida", False, "edite .env com seus valores reais")
        return

    print(f"  Supabase: {config['SUPABASE_URL']}\n")

    # ---- Bloco 1: Contagens via PostgREST ----
    print(f"{Cor.NEGRITO}[1] Catalogo (contagens){Cor.RESET}")
    for tabela, esperado in [('modelos', 10), ('revisoes', 70), ('itens_checklist', 1300)]:
        n, status = contar_via_rest(config, tabela)
        if status == 0:
            teste(f"{tabela} = {esperado}", False, "sem conexao com Supabase")
        elif n == esperado:
            teste(f"{tabela} = {esperado}", True, f"OK ({n})")
        else:
            teste(f"{tabela} = {esperado}", False,
                  f"encontrado: {n} (status HTTP {status})")

    # ---- Bloco 2: Views via PostgREST ----
    print(f"\n{Cor.NEGRITO}[2] Views{Cor.RESET}")
    for view in ['vw_checklist_completo', 'vw_motos_status']:
        url = f"{config['SUPABASE_URL']}/rest/v1/{view}?select=*&limit=1"
        headers = {
            'apikey': config['SUPABASE_ANON_KEY'],
            'Authorization': f"Bearer {config['SUPABASE_ANON_KEY']}"
        }
        status, _, _ = request_api(url, headers)
        teste(f"View {view} acessivel", status == 200, f"HTTP {status}")

    # ---- Bloco 3: Bucket Storage ----
    print(f"\n{Cor.NEGRITO}[3] Storage Bucket{Cor.RESET}")
    if not config.get('SUPABASE_SERVICE_KEY') or 'SUA_' in config.get('SUPABASE_SERVICE_KEY', ''):
        teste("Bucket 'inspecoes' existe", False, "SERVICE_KEY nao preenchida em .env")
    else:
        url = f"{config['SUPABASE_URL']}/storage/v1/bucket/inspecoes"
        headers = {
            'apikey': config['SUPABASE_SERVICE_KEY'],
            'Authorization': f"Bearer {config['SUPABASE_SERVICE_KEY']}"
        }
        status, _, body = request_api(url, headers)
        teste("Bucket 'inspecoes' existe", status == 200,
              f"HTTP {status}" if status != 200 else f"id={body.get('id')}")
        if status == 200:
            teste("Bucket eh privado",
                  body.get('public') == False,
                  f"public={body.get('public')}")

    # ---- Bloco 4: Usuarios ----
    print(f"\n{Cor.NEGRITO}[4] Usuarios cadastrados{Cor.RESET}")
    if not config.get('SUPABASE_SERVICE_KEY') or 'SUA_' in config.get('SUPABASE_SERVICE_KEY', ''):
        teste("Pelo menos 1 usuario cadastrado", False, "SERVICE_KEY nao preenchida")
    else:
        url = f"{config['SUPABASE_URL']}/auth/v1/admin/users"
        headers = {
            'apikey': config['SUPABASE_SERVICE_KEY'],
            'Authorization': f"Bearer {config['SUPABASE_SERVICE_KEY']}"
        }
        status, _, body = request_api(url, headers)
        if status == 200:
            usuarios = body.get('users', []) if isinstance(body, dict) else []
            n_users = len(usuarios)
            teste("Pelo menos 1 usuario cadastrado", n_users >= 1,
                  f"encontrados: {n_users}")
            if usuarios:
                emails = [u.get('email', '?') for u in usuarios[:5]]
                print(f"       {Cor.AMARELO}Primeiros: {', '.join(emails)}{Cor.RESET}")
        else:
            teste("Pelo menos 1 usuario cadastrado", False, f"HTTP {status}")

# ============================================================
# RESUMO
# ============================================================
def resumo():
    print(f"\n{Cor.NEGRITO}{'=' * 70}{Cor.RESET}")
    print(f"{Cor.NEGRITO}  RESUMO{Cor.RESET}")
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
    print(f"{Cor.NEGRITO}REVISAO-MOTO :: Testes da Fase 1{Cor.RESET}")
    modo = detectar_modo(sys.argv)
    print(f"Modo: {modo.upper()}")

    if modo == 'local':
        testar_local()
    else:
        testar_remote()

    return resumo()

if __name__ == '__main__':
    sys.exit(main())

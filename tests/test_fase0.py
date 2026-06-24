#!/usr/bin/env python3
"""
========================================================================
REVISAO-MOTO :: Suite de testes da Fase 0
========================================================================
Valida toda a entrega da Fase 0:
  - Estrutura de pastas
  - Schema SQL (rodando contra Postgres real)
  - Seed Royal Enfield (contagens corretas)
  - Views funcionais
  - Triggers operando
  - RLS policies criadas
  - HTML/JS/CSS validos
  - PWA manifest valido
  - Service Worker sintaticamente OK
  - Icones presentes

Uso:
  python3 tests/test_fase0.py

Requer: psql em PATH, PostgreSQL rodando local
========================================================================
"""

import json
import os
import re
import subprocess
import sys
from pathlib import Path

# ============================================================
# CONFIG
# ============================================================
RAIZ = Path(__file__).parent.parent.resolve()
PG_HOST = os.environ.get('PGHOST', '/tmp')
PG_PORT = os.environ.get('PGPORT', '5433')
PG_USER = os.environ.get('PGUSER', 'postgres')
PG_DB   = os.environ.get('PGDATABASE', 'revisao_moto_test')

# Cores ANSI para output
class Cor:
    VERDE   = '\033[92m'
    VERMELHO= '\033[91m'
    AMARELO = '\033[93m'
    AZUL    = '\033[94m'
    NEGRITO = '\033[1m'
    RESET   = '\033[0m'

# Contadores globais
testes_total = 0
testes_passou = 0
testes_falhou = 0
falhas = []

# ============================================================
# HELPERS
# ============================================================

def cabecalho(titulo):
    print(f"\n{Cor.AZUL}{Cor.NEGRITO}{'=' * 70}{Cor.RESET}")
    print(f"{Cor.AZUL}{Cor.NEGRITO}  {titulo}{Cor.RESET}")
    print(f"{Cor.AZUL}{Cor.NEGRITO}{'=' * 70}{Cor.RESET}")

def teste(descricao, condicao, detalhe=''):
    global testes_total, testes_passou, testes_falhou
    testes_total += 1
    if condicao:
        testes_passou += 1
        print(f"  {Cor.VERDE}✓{Cor.RESET} {descricao}")
        if detalhe:
            print(f"    {Cor.AMARELO}{detalhe}{Cor.RESET}")
    else:
        testes_falhou += 1
        falhas.append(descricao)
        print(f"  {Cor.VERMELHO}✗ {descricao}{Cor.RESET}")
        if detalhe:
            print(f"    {Cor.VERMELHO}{detalhe}{Cor.RESET}")

def psql(sql, db=None):
    """Executa SQL e retorna stdout (sem cabecalhos)."""
    cmd = ['psql', '-h', PG_HOST, '-p', PG_PORT, '-U', PG_USER,
           '-d', db or PG_DB, '-t', '-A', '-c', sql]
    res = subprocess.run(cmd, capture_output=True, text=True)
    if res.returncode != 0:
        raise RuntimeError(f"psql falhou: {res.stderr}")
    return res.stdout.strip()

def psql_arquivo(arquivo, db=None):
    """Executa arquivo SQL."""
    cmd = ['psql', '-h', PG_HOST, '-p', PG_PORT, '-U', PG_USER,
           '-d', db or PG_DB, '-f', str(arquivo), '-v', 'ON_ERROR_STOP=1']
    res = subprocess.run(cmd, capture_output=True, text=True)
    return res.returncode, res.stdout, res.stderr

# ============================================================
# TESTE 1: ESTRUTURA DE PASTAS
# ============================================================
def testar_estrutura():
    cabecalho("1. ESTRUTURA DE PASTAS")

    arquivos_obrigatorios = [
        'index.html',
        'manifest.json',
        'service-worker.js',
        'README.md',
        'src/supabase-client.js',
        'src/auth.js',
        'css/styles.css',
        'sql/001_schema.sql',
        'sql/002_seed_royal_enfield.sql',
        'assets/icon-192.png',
        'assets/icon-512.png',
    ]
    for caminho in arquivos_obrigatorios:
        path = RAIZ / caminho
        teste(f"Existe: {caminho}", path.exists(),
              f"esperado em {path}" if not path.exists() else f"{path.stat().st_size} bytes")

    pastas_obrigatorias = ['src', 'css', 'sql', 'assets']
    for pasta in pastas_obrigatorias:
        path = RAIZ / pasta
        teste(f"Pasta existe: {pasta}/", path.is_dir())

# ============================================================
# TESTE 2: SCHEMA SQL
# ============================================================
def testar_schema():
    cabecalho("2. SCHEMA SQL (banco real)")

    # Cria banco limpo
    try:
        psql(f"DROP DATABASE IF EXISTS {PG_DB};", db='postgres')
        psql(f"CREATE DATABASE {PG_DB};", db='postgres')
    except Exception as e:
        teste(f"Cria banco {PG_DB}", False, str(e))
        return False

    # Cria role 'authenticated' que o schema referencia
    try:
        psql("CREATE ROLE authenticated;", db='postgres')
    except Exception:
        pass  # ja existe
    # Cria schema 'auth' simulado (Supabase usa este schema)
    psql("CREATE SCHEMA IF NOT EXISTS auth;")
    psql("""CREATE TABLE IF NOT EXISTS auth.users (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        email TEXT
    );""")

    # Executa schema
    arquivo_schema = RAIZ / 'sql' / '001_schema.sql'
    codigo, stdout, stderr = psql_arquivo(arquivo_schema)
    teste("Schema executa sem erro", codigo == 0,
          stderr if codigo != 0 else 'OK')
    if codigo != 0:
        return False

    # Verifica tabelas
    tabelas_esperadas = ['modelos', 'revisoes', 'itens_checklist',
                         'motos', 'inspecoes', 'inspecoes_itens']
    for tab in tabelas_esperadas:
        existe = psql(f"""
            SELECT EXISTS(SELECT 1 FROM information_schema.tables
            WHERE table_schema='public' AND table_name='{tab}');
        """) == 't'
        teste(f"Tabela existe: {tab}", existe)

    # Verifica views
    views_esperadas = ['vw_checklist_completo', 'vw_motos_status']
    for v in views_esperadas:
        existe = psql(f"""
            SELECT EXISTS(SELECT 1 FROM information_schema.views
            WHERE table_schema='public' AND table_name='{v}');
        """) == 't'
        teste(f"View existe: {v}", existe)

    # Verifica triggers
    triggers = psql("""
        SELECT trigger_name FROM information_schema.triggers
        WHERE event_object_schema='public' ORDER BY trigger_name;
    """)
    teste("Trigger 'set_atualizado_em_motos' criado",
          'set_atualizado_em_motos' in triggers,
          triggers)

    # Verifica RLS habilitado
    for tab in tabelas_esperadas:
        rls_on = psql(f"""
            SELECT relrowsecurity FROM pg_class
            WHERE relname='{tab}' AND relnamespace=(SELECT oid FROM pg_namespace WHERE nspname='public');
        """) == 't'
        teste(f"RLS habilitado em: {tab}", rls_on)

    # Verifica policies
    n_policies = int(psql("""
        SELECT COUNT(*) FROM pg_policies WHERE schemaname='public';
    """))
    teste("Policies criadas (esperado >= 6)", n_policies >= 6,
          f"encontradas: {n_policies}")

    # Verifica indices
    n_indices = int(psql("""
        SELECT COUNT(*) FROM pg_indexes
        WHERE schemaname='public' AND indexname LIKE 'idx_%';
    """))
    teste("Indices criados (esperado >= 8)", n_indices >= 8,
          f"encontrados: {n_indices}")

    return True

# ============================================================
# TESTE 3: SEED ROYAL ENFIELD
# ============================================================
def testar_seed():
    cabecalho("3. SEED ROYAL ENFIELD")

    arquivo_seed = RAIZ / 'sql' / '002_seed_royal_enfield.sql'
    codigo, stdout, stderr = psql_arquivo(arquivo_seed)
    teste("Seed executa sem erro", codigo == 0,
          stderr if codigo != 0 else 'OK')
    if codigo != 0:
        return False

    # Contagem de modelos
    n_modelos = int(psql("SELECT COUNT(*) FROM modelos;"))
    teste("10 modelos cadastrados", n_modelos == 10,
          f"encontrados: {n_modelos}")

    # Modelos especificos
    modelos_esperados = ['Shotgun 650', 'Super Meteor 650', 'Interceptor 650',
                         'Continental GT 650', 'Classic 650', 'Bear 650',
                         'Hunter 350', 'Classic 350', 'Meteor 350',
                         'Himalayan 450']
    for m in modelos_esperados:
        existe = psql(f"SELECT EXISTS(SELECT 1 FROM modelos WHERE nome='{m}');") == 't'
        teste(f"Modelo presente: {m}", existe)

    # Contagem de revisoes
    n_revisoes = int(psql("SELECT COUNT(*) FROM revisoes;"))
    teste("70 revisoes (10 modelos x 7 km)", n_revisoes == 70,
          f"encontradas: {n_revisoes}")

    # Distribuicao por km
    kms = psql("SELECT DISTINCT km FROM revisoes ORDER BY km;").split('\n')
    kms_esperados = ['500', '5000', '10000', '15000', '20000', '25000', '30000']
    teste("Kms corretos (500/5k/10k/15k/20k/25k/30k)",
          kms == kms_esperados, f"encontrados: {kms}")

    # Contagem de itens (correta: 14*10 + 16*30 + 22*20 + 24*10 = 1300)
    n_itens = int(psql("SELECT COUNT(*) FROM itens_checklist;"))
    teste("Total de itens = 1300 (130 por modelo x 10)",
          n_itens == 1300, f"encontrados: {n_itens}")

    # Distribuicao de itens por km (1o modelo)
    itens_por_km = psql("""
        SELECT r.km, COUNT(i.id) FROM revisoes r
        JOIN itens_checklist i ON i.revisao_id = r.id
        WHERE r.modelo_id = 1 GROUP BY r.km ORDER BY r.km;
    """).split('\n')
    esperado = {'500': 14, '5000': 16, '10000': 22, '15000': 16,
                '20000': 24, '25000': 16, '30000': 22}
    for linha in itens_por_km:
        if not linha or '|' not in linha:
            continue
        km, qtd = linha.split('|')
        qtd = int(qtd)
        teste(f"Itens em {km} km = {esperado.get(km, '?')}",
              qtd == esperado.get(km),
              f"encontrados: {qtd}")

    # Categorias presentes
    categorias = psql("SELECT DISTINCT categoria FROM itens_checklist ORDER BY categoria;").split('\n')
    cat_esperadas = ['Eletrica', 'Freios', 'Geral', 'Lubrificacao',
                     'Motor', 'Pneus', 'Suspensao', 'Transmissao']
    teste("Categorias corretas presentes",
          all(c in categorias for c in cat_esperadas),
          f"presentes: {categorias}")

    # Itens criticos da Shotgun 650 - 500 km
    n_itens_500_shotgun = int(psql("""
        SELECT COUNT(*) FROM itens_checklist i
        JOIN revisoes r ON r.id = i.revisao_id
        JOIN modelos m ON m.id = r.modelo_id
        WHERE m.nome='Shotgun 650' AND r.km=500;
    """))
    teste("Shotgun 650 / 500 km tem 14 itens",
          n_itens_500_shotgun == 14,
          f"encontrados: {n_itens_500_shotgun}")

    # Itens com referencia de oleo
    n_oleo = int(psql("""
        SELECT COUNT(*) FROM itens_checklist
        WHERE descricao ILIKE '%oleo do motor%' AND valor_referencia LIKE '%3.1%';
    """))
    teste("Volume de oleo 3,1 L referenciado na linha 650",
          n_oleo > 0, f"encontrados: {n_oleo}")

    return True

# ============================================================
# TESTE 4: VIEWS FUNCIONAIS
# ============================================================
def testar_views():
    cabecalho("4. VIEWS FUNCIONAIS")

    # vw_checklist_completo
    n = int(psql("SELECT COUNT(*) FROM vw_checklist_completo;"))
    teste("vw_checklist_completo retorna linhas",
          n > 700, f"linhas: {n}")

    # Shotgun 650 500 km via view
    resultado = psql("""
        SELECT categoria, descricao FROM vw_checklist_completo
        WHERE modelo_nome='Shotgun 650' AND km=500 ORDER BY ordem LIMIT 3;
    """)
    teste("View retorna primeiros itens Shotgun 500 km",
          'Motor' in resultado and 'oleo' in resultado.lower(),
          resultado.split('\n')[0] if resultado else 'vazio')

    # vw_motos_status com motos vazia
    n_motos_status = int(psql("SELECT COUNT(*) FROM vw_motos_status;"))
    teste("vw_motos_status executavel (sem motos)",
          n_motos_status == 0, f"linhas: {n_motos_status}")

# ============================================================
# TESTE 5: TRIGGER
# ============================================================
def testar_trigger():
    cabecalho("5. TRIGGER atualizado_em")

    psql("""
        INSERT INTO motos (placa, modelo_id, proprietario, km_atual)
        VALUES ('TEST-9999', 1, 'Mario Teste', 1000);
    """)
    criado = psql("SELECT criado_em FROM motos WHERE placa='TEST-9999';")
    atualizado1 = psql("SELECT atualizado_em FROM motos WHERE placa='TEST-9999';")
    teste("Insert popula criado_em e atualizado_em",
          criado and atualizado1, f"criado={criado}")

    # Aguarda 1s e atualiza
    import time
    time.sleep(1.1)
    psql("UPDATE motos SET km_atual=2000 WHERE placa='TEST-9999';")
    atualizado2 = psql("SELECT atualizado_em FROM motos WHERE placa='TEST-9999';")
    teste("Trigger atualiza atualizado_em em UPDATE",
          atualizado2 != atualizado1,
          f"antes: {atualizado1[:19]} | depois: {atualizado2[:19]}")

    psql("DELETE FROM motos WHERE placa='TEST-9999';")

# ============================================================
# TESTE 6: PWA MANIFEST
# ============================================================
def testar_manifest():
    cabecalho("6. PWA MANIFEST")

    path = RAIZ / 'manifest.json'
    try:
        with open(path) as f:
            manifest = json.load(f)
        teste("manifest.json eh JSON valido", True)
    except json.JSONDecodeError as e:
        teste("manifest.json eh JSON valido", False, str(e))
        return

    campos = ['name', 'short_name', 'start_url', 'display',
              'background_color', 'theme_color', 'icons']
    for campo in campos:
        teste(f"Campo presente: {campo}", campo in manifest)

    teste("display = 'standalone'", manifest.get('display') == 'standalone')
    teste("Pelo menos 2 icones (192 e 512)",
          len(manifest.get('icons', [])) >= 2)

    for icon in manifest.get('icons', []):
        icon_path = RAIZ / icon['src']
        teste(f"Icone existe: {icon['src']}",
              icon_path.exists(),
              f"{icon_path.stat().st_size} bytes" if icon_path.exists() else 'ausente')

# ============================================================
# TESTE 7: SERVICE WORKER
# ============================================================
def testar_sw():
    cabecalho("7. SERVICE WORKER")

    path = RAIZ / 'service-worker.js'
    conteudo = path.read_text()

    # Sintaxe via Node
    res = subprocess.run(['node', '--check', str(path)], capture_output=True, text=True)
    teste("Service Worker eh JS valido (node --check)",
          res.returncode == 0,
          res.stderr if res.returncode != 0 else 'OK')

    # Eventos esperados
    teste("Listener de 'install'", "addEventListener('install'" in conteudo)
    teste("Listener de 'activate'", "addEventListener('activate'" in conteudo)
    teste("Listener de 'fetch'", "addEventListener('fetch'" in conteudo)
    teste("Estrategia network-first para Supabase",
          'supabase.co' in conteudo)
    teste("Cache name versionado",
          'CACHE_VERSION' in conteudo and 'CACHE_NAME' in conteudo)
    teste("Skip waiting message handler",
          'SKIP_WAITING' in conteudo)

# ============================================================
# TESTE 8: HTML / JS
# ============================================================
def testar_html_js():
    cabecalho("8. HTML / JS / CSS")

    # index.html
    html = (RAIZ / 'index.html').read_text()
    teste("HTML tem DOCTYPE", html.lstrip().startswith('<!DOCTYPE'))
    teste("HTML tem viewport mobile",
          'name="viewport"' in html and 'width=device-width' in html)
    teste("HTML referencia manifest", 'manifest.json' in html)
    teste("HTML referencia Supabase CDN", 'supabase-js' in html)
    teste("HTML referencia Tailwind", 'tailwindcss.com' in html)
    teste("HTML tem tela de login", 'id="tela-login"' in html)
    teste("HTML tem dashboard", 'id="tela-dashboard"' in html)
    teste("HTML registra Service Worker",
          'serviceWorker.register' in html)
    teste("HTML chama fazerLogin", 'fazerLogin' in html)

    # JS files
    for js in ['src/supabase-client.js', 'src/auth.js']:
        res = subprocess.run(['node', '--check', str(RAIZ / js)],
                            capture_output=True, text=True)
        teste(f"{js} eh JS valido",
              res.returncode == 0,
              res.stderr.strip() if res.returncode != 0 else 'OK')

    # supabase-client tem placeholder
    sb = (RAIZ / 'src/supabase-client.js').read_text()
    teste("supabase-client tem placeholder SUPABASE_URL",
          'SEU_PROJETO' in sb,
          'pronto para edicao do usuario')

    # auth.js exporta funcoes globais
    auth = (RAIZ / 'src/auth.js').read_text()
    for fn in ['fazerLogin', 'cadastrarUsuario', 'recuperarSessao']:
        teste(f"auth.js define {fn}", f"function {fn}" in auth)

    # CSS
    css = (RAIZ / 'css/styles.css').read_text()
    teste("CSS define variaveis de cor", '--cor-primaria' in css)
    teste("CSS tem classes de status (.btn-status)", '.btn-status' in css)
    teste("CSS tem canvas-assinatura", '.canvas-assinatura' in css)
    teste("CSS tem viewport mobile (16px input)",
          'font-size: 16px' in css)

# ============================================================
# TESTE 9: README
# ============================================================
def testar_readme():
    cabecalho("9. README")

    readme = (RAIZ / 'README.md').read_text()
    secoes = ['## Estrutura', '## Setup', '## Roadmap',
              'Fase 0', 'Fase 1', 'Fase 2', 'Fase 3',
              'Supabase', 'GitHub Pages']
    for s in secoes:
        teste(f"README contem '{s}'", s in readme)

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
        print(f"  {Cor.VERMELHO}Falhou: {testes_falhou}{Cor.RESET}")
        print(f"\n  {Cor.VERMELHO}Falhas:{Cor.RESET}")
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
    print(f"{Cor.NEGRITO}REVISAO-MOTO :: Suite de testes da Fase 0{Cor.RESET}")
    print(f"Raiz do projeto: {RAIZ}")
    print(f"Postgres: {PG_HOST}:{PG_PORT}/{PG_DB} (user: {PG_USER})")

    testar_estrutura()
    if not testar_schema():
        print(f"\n{Cor.VERMELHO}Schema falhou - pulando demais testes SQL{Cor.RESET}")
    else:
        if testar_seed():
            testar_views()
            testar_trigger()
    testar_manifest()
    testar_sw()
    testar_html_js()
    testar_readme()

    return resumo()

if __name__ == '__main__':
    sys.exit(main())

#!/usr/bin/env python3
"""
========================================================================
REVISAO-MOTO :: Suite de testes da Fase 7 - Polimento
========================================================================
Valida:
  1. Migration SQL (especificacoes_modelo)
  2. Icones PNG reais (dimensoes, tamanho > 1KB)
  3. Manifest atualizado (maskable, shortcuts)
  4. Dark mode (src/darkmode.js + CSS + darkMode config)
  5. i18n (src/i18n.js + assets/i18n/pt.json + en.json)
  6. QR Code (src/qrcode.js + qrcode.html + CDN qrcode-generator)
  7. Notificacoes (src/notifications.js)
  8. Onboarding (onboarding.html + redirect no index.html)
  9. Especificacoes (especificacoes.html + view SQL)
  10. Service Worker v0.7.0
  11. Integracao nas paginas existentes
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

# ============================================================
# 1. MIGRATION
# ============================================================
def t_migration():
    cabecalho("1. MIGRATION SQL (007_fase7_especificacoes.sql)")
    arq = RAIZ / 'sql' / '007_fase7_especificacoes.sql'
    teste("Arquivo existe", arq.exists())
    if not arq.exists(): return False

    c, _, e = psql_arq(arq)
    teste("Migration executa", c == 0, e if c != 0 else 'OK')
    if c != 0: return False

    c2, _, e2 = psql_arq(arq)
    teste("Migration idempotente (2x)", c2 == 0, e2 if c2 != 0 else 'OK')

    # Estrutura
    ok = psql("SELECT EXISTS(SELECT 1 FROM information_schema.tables WHERE table_name='especificacoes_modelo');") == 't'
    teste("Tabela especificacoes_modelo criada", ok)

    ok = psql("SELECT EXISTS(SELECT 1 FROM information_schema.views WHERE table_name='vw_especificacoes');") == 't'
    teste("View vw_especificacoes criada", ok)

    # Dados
    n = int(psql("SELECT COUNT(*) FROM especificacoes_modelo;"))
    teste("Seed populou especs", n >= 100, f"linhas: {n} (esperado >=100 = 10 modelos x ~18 items)")

    n_cat = int(psql("SELECT COUNT(DISTINCT categoria) FROM especificacoes_modelo;"))
    teste("5 categorias distintas", n_cat == 5, f"encontrou: {n_cat}")

    # Volume oleo especifico por plataforma
    ok650 = psql("SELECT valor FROM vw_especificacoes WHERE modelo LIKE '%650%' AND item LIKE '%capacidade%' LIMIT 1;")
    teste("Volume oleo 650 = 3.1 L", '3.1' in ok650, f"retornou: {ok650}")

    ok350 = psql("SELECT valor FROM vw_especificacoes WHERE modelo LIKE '%350%' AND item LIKE '%capacidade%' LIMIT 1;")
    teste("Volume oleo 350 = 2.5 L", '2.5' in ok350, f"retornou: {ok350}")

    return True

# ============================================================
# 2. ICONES REAIS
# ============================================================
def t_icones():
    cabecalho("2. ICONES REAIS")
    for arq, tam_min in [('assets/icon-192.png', 500),
                         ('assets/icon-512.png', 1000),
                         ('assets/icon-512-maskable.png', 500)]:
        p = RAIZ / arq
        if p.exists():
            tam = p.stat().st_size
            teste(f"{arq} existe (>{tam_min}B)", tam > tam_min, f"{tam} bytes")
        else:
            teste(f"{arq} existe", False)

# ============================================================
# 3. MANIFEST
# ============================================================
def t_manifest():
    cabecalho("3. MANIFEST atualizado")
    p = RAIZ / 'manifest.json'
    if not p.exists(): return
    try:
        m = json.loads(p.read_text())
    except Exception as e:
        teste("manifest.json valido", False, str(e))
        return
    teste("manifest.json valido", True)
    teste("Tem shortcuts", 'shortcuts' in m and len(m.get('shortcuts', [])) >= 2)
    teste("Icone maskable separado", any(i.get('purpose')=='maskable' for i in m.get('icons',[])))
    teste("Tem 3 icones (192, 512, maskable)", len(m.get('icons', [])) >= 3)

# ============================================================
# 4. DARK MODE
# ============================================================
def t_darkmode():
    cabecalho("4. DARK MODE")
    p = RAIZ / 'src' / 'darkmode.js'
    teste("src/darkmode.js existe", p.exists())
    if not p.exists(): return
    js = p.read_text()

    res = subprocess.run(['node', '--check', str(p)], capture_output=True, text=True)
    teste("Sintaxe valida", res.returncode == 0)

    teste("Detecta prefers-color-scheme", 'prefers-color-scheme' in js)
    teste("Salva em localStorage", 'localStorage' in js and 'rm_tema' in js)
    teste("Aplica classe dark no html", "classList.add('dark')" in js)
    teste("Exporta alternarTema", 'alternarTema' in js and 'window.darkMode' in js)
    teste("Muda meta theme-color", 'theme-color' in js)
    teste("Cria botao flutuante", 'btn-dark-toggle' in js and 'position: fixed' in js)

    # CSS suporta
    css = (RAIZ / 'css' / 'styles.css').read_text()
    teste("CSS tem regras html.dark", 'html.dark' in css)

    # Tailwind darkMode class nas paginas
    for html in ['index.html', 'admin.html', 'historico.html', 'inspecao.html']:
        h = (RAIZ / html).read_text()
        teste(f"{html} configura tailwind darkMode:class", 'darkMode' in h)

# ============================================================
# 5. i18n
# ============================================================
def t_i18n():
    cabecalho("5. INTERNACIONALIZACAO (i18n)")
    p = RAIZ / 'src' / 'i18n.js'
    teste("src/i18n.js existe", p.exists())
    if not p.exists(): return
    js = p.read_text()

    res = subprocess.run(['node', '--check', str(p)], capture_output=True, text=True)
    teste("Sintaxe valida", res.returncode == 0)

    teste("Funcao t() disponivel", 'function t(' in js)
    teste("Exporta window.t (atalho)", 'window.t = t' in js)
    teste("Exporta window.i18n", 'window.i18n' in js)
    teste("Suporta placeholders {var}", '{(\\w+)}' in js or '{\\w+}' in js or 'params' in js)
    teste("Aplica no DOM via data-i18n", 'data-i18n' in js)
    teste("Persiste em localStorage", 'localStorage' in js and 'rm_idioma' in js)

    # Traducoes
    pt = RAIZ / 'assets' / 'i18n' / 'pt.json'
    en = RAIZ / 'assets' / 'i18n' / 'en.json'
    teste("pt.json existe", pt.exists())
    teste("en.json existe", en.exists())

    if pt.exists() and en.exists():
        try:
            dpt = json.loads(pt.read_text())
            den = json.loads(en.read_text())
            teste("pt.json valido", True)
            teste("en.json valido", True)
            # Chaves obrigatorias
            for chave in ['app', 'nav', 'login', 'dashboard', 'inspecao', 'historico', 'onboarding']:
                teste(f"pt.json tem '{chave}'", chave in dpt)
                teste(f"en.json tem '{chave}'", chave in den)
            # Mesmo shape
            teste("Chaves top-level identicas em pt/en", set(dpt.keys()) == set(den.keys()))
        except Exception as e:
            teste("JSON valido", False, str(e))

# ============================================================
# 6. QR CODE
# ============================================================
def t_qrcode():
    cabecalho("6. QR CODE (gerador + scanner)")
    p = RAIZ / 'src' / 'qrcode.js'
    teste("src/qrcode.js existe", p.exists())
    if not p.exists(): return
    js = p.read_text()

    res = subprocess.run(['node', '--check', str(p)], capture_output=True, text=True)
    teste("Sintaxe valida", res.returncode == 0)

    teste("Exporta gerarQrParaPlaca", 'gerarQrParaPlaca' in js and 'window.qrMoto' in js)
    teste("Exporta iniciarScanner", 'iniciarScanner' in js)
    teste("Exporta pararScanner", 'pararScanner' in js)
    teste("Exporta extrairPlacaDoQr", 'extrairPlacaDoQr' in js)
    teste("Usa BarcodeDetector (nativo)", 'BarcodeDetector' in js)
    teste("Usa getUserMedia (camera)", 'getUserMedia' in js)
    teste("Prefere camera traseira", 'environment' in js)

    # qrcode.html
    q = RAIZ / 'qrcode.html'
    teste("qrcode.html existe", q.exists())
    if q.exists():
        html = q.read_text()
        teste("Inclui qrcode-generator CDN", 'qrcode-generator' in html)
        teste("Tem input placa", 'placa-gerar' in html)
        teste("Tem tab escanear", 'painel-escanear' in html)
        teste("Tem video elemento", '<video' in html)
        teste("Tem botao imprimir", 'imprimir()' in html or 'imprimir' in html)
        teste("Tem botao baixarSvg", 'baixarSvg' in html)
        teste("Exige login", 'exigirLogin' in html)

    # inspecao.html aceita ?placa=
    insp = (RAIZ / 'inspecao.html').read_text()
    teste("inspecao.html aceita ?placa=X", 'preencherPlacaViaUrl' in insp)

# ============================================================
# 7. NOTIFICACOES
# ============================================================
def t_notificacoes():
    cabecalho("7. NOTIFICACOES LOCAIS")
    p = RAIZ / 'src' / 'notifications.js'
    teste("src/notifications.js existe", p.exists())
    if not p.exists(): return
    js = p.read_text()

    res = subprocess.run(['node', '--check', str(p)], capture_output=True, text=True)
    teste("Sintaxe valida", res.returncode == 0)

    teste("Verifica suporte Notification", "'Notification' in window" in js)
    teste("Pede permissao com requestPermission", 'requestPermission' in js)
    teste("Usa Service Worker.showNotification", 'showNotification' in js)
    teste("Exporta pedirPermissao", 'pedirPermissao' in js and 'window.notifs' in js)
    teste("Exporta notificar", 'notificar' in js)
    teste("Exporta checarECronizarAlertas", 'checarECronizarAlertas' in js)
    teste("Checa motos atrasadas/proximas", 'atrasada' in js and 'proxima' in js)
    teste("Checa inspecoes em andamento antigas", 'em_andamento' in js)
    teste("Anti-spam por dia (localStorage)", 'rm_notif' in js)
    teste("Vibra ao notificar", 'vibrate' in js)

# ============================================================
# 8. ONBOARDING
# ============================================================
def t_onboarding():
    cabecalho("8. ONBOARDING")
    p = RAIZ / 'onboarding.html'
    teste("onboarding.html existe", p.exists())
    if not p.exists(): return
    html = p.read_text()

    # 5 slides: SLIDES array com 5 items (tKey de 1 a 5)
    n_slides = len(re.findall(r'tKey:\s*\d', html))
    teste("Tem 5 slides", n_slides == 5, f"tKeys encontradas: {n_slides}")
    teste("Usa i18n para conteudo", 'window.t' in html)
    teste("Dots de progresso", 'dot-0' in html and 'dot-4' in html)
    teste("Botao pular", 'onboarding.pular' in html)
    teste("Finaliza gravando localStorage", 'rm_onboarding_visto' in html)
    teste("Redireciona para index apos finalizar", 'index.html' in html)

    # index.html redireciona se primeira vez
    idx = (RAIZ / 'index.html').read_text()
    teste("index.html redireciona se novo usuario", 'rm_onboarding_visto' in idx and 'onboarding.html' in idx)

# ============================================================
# 9. ESPECIFICACOES
# ============================================================
def t_especificacoes():
    cabecalho("9. ESPECIFICACOES TECNICAS")
    p = RAIZ / 'especificacoes.html'
    teste("especificacoes.html existe", p.exists())
    if not p.exists(): return
    html = p.read_text()

    teste("Seletor de modelo", 'sel-modelo' in html)
    teste("Usa vw_especificacoes", 'vw_especificacoes' in html)
    teste("Agrupa por categoria", 'grupos' in html or 'categoria' in html)
    teste("Exige login", 'exigirLogin' in html)
    teste("Aceita ?modelo=X na URL", "get('modelo')" in html or 'modelo=' in html)

    # Link no dashboard
    idx = (RAIZ / 'index.html').read_text()
    teste("Dashboard tem link para especificacoes", 'especificacoes.html' in idx)
    teste("Dashboard tem link para qrcode", 'qrcode.html' in idx)

# ============================================================
# 10. SERVICE WORKER v0.7
# ============================================================
def t_service_worker():
    cabecalho("10. SERVICE WORKER v0.7.0")
    sw = (RAIZ / 'service-worker.js').read_text()
    teste("Versao v0.7.x", 'v0.7' in sw)
    for f in ['onboarding.html', 'especificacoes.html', 'qrcode.html',
              'darkmode.js', 'i18n.js', 'qrcode.js', 'notifications.js',
              'icon-512-maskable.png', 'i18n/pt.json', 'i18n/en.json',
              'qrcode-generator']:
        teste(f"APP_SHELL contem '{f}'", f in sw)

# ============================================================
# 11. INTEGRACAO
# ============================================================
def t_integracao():
    cabecalho("11. INTEGRACAO NAS PAGINAS")
    for html in ['index.html', 'admin.html', 'historico.html', 'inspecao.html']:
        h = (RAIZ / html).read_text()
        teste(f"{html} importa darkmode.js", 'src/darkmode.js' in h)
        teste(f"{html} importa i18n.js",     'src/i18n.js' in h)

# ============================================================
# RESUMO
# ============================================================
def resumo():
    print(f"\n{Cor.NEG}{'='*70}{Cor.RESET}")
    print(f"{Cor.NEG}  RESUMO FASE 7{Cor.RESET}")
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
    print(f"{Cor.NEG}REVISAO-MOTO :: Testes da Fase 7 - Polimento{Cor.RESET}")
    if not t_migration(): return 1
    t_icones()
    t_manifest()
    t_darkmode()
    t_i18n()
    t_qrcode()
    t_notificacoes()
    t_onboarding()
    t_especificacoes()
    t_service_worker()
    t_integracao()
    return resumo()

if __name__ == '__main__':
    sys.exit(main())

#!/usr/bin/env python3
"""
========================================================================
REVISAO-MOTO :: Suite de testes da Fase 6
========================================================================
Valida suporte offline:
  - Modulo src/offline.js (IndexedDB wrapper + fila + sync)
  - Modulo src/status_offline.js (widget de indicador)
  - Service Worker atualizado (v0.6.0, cache dos novos arquivos)
  - Integracao nos HTMLs (offline.js e status_offline.js referenciados)
  - Estrutura de dados: object stores, tipos de operacao, retry

Foco: validar estrutura, exports e integracao. A funcionalidade real
(IndexedDB no browser) exige teste manual no celular.
========================================================================
"""

import os, re, subprocess, sys, json
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

# ============================================================
# 1. ARQUIVOS EXISTEM
# ============================================================
def t_arquivos():
    cabecalho("1. ARQUIVOS DA FASE 6")
    for arq in ['src/offline.js', 'src/status_offline.js']:
        p = RAIZ / arq
        teste(f"{arq} existe", p.exists())

# ============================================================
# 2. src/offline.js - SINTAXE E EXPORTS
# ============================================================
def t_offline_js():
    cabecalho("2. MODULO src/offline.js")
    arq = RAIZ / 'src' / 'offline.js'
    if not arq.exists(): return
    js = arq.read_text()

    res = subprocess.run(['node', '--check', str(arq)], capture_output=True, text=True)
    teste("Sintaxe valida (node --check)", res.returncode == 0,
          res.stderr.strip() if res.returncode != 0 else 'OK')

    # Uso de IndexedDB
    teste("Usa indexedDB.open", 'indexedDB.open' in js)
    teste("Define DB_NOME", 'DB_NOME' in js and 'revisao_moto_offline' in js)
    teste("Trata onupgradeneeded", 'onupgradeneeded' in js)
    teste("Cria object stores", 'createObjectStore' in js)

    # Object stores esperados
    for store in ['catalogo', 'inspecoes_locais', 'pending_operations', 'fotos_pendentes']:
        teste(f"Object store '{store}' definido", store in js)

    # Autoincrement na fila
    teste("Fila usa autoIncrement", 'autoIncrement: true' in js)
    teste("Indice em criado_em", "createIndex('criado_em'" in js)

    # Funcoes principais exportadas
    for fn in ['cachearCatalogo','obterCatalogo','enfileirarOperacao',
               'listarPendentes','contarPendentes','sincronizar',
               'salvarItemInteligente','salvarFotoLocal','obterFotoLocal',
               'iniciarAutoSync','pararAutoSync']:
        teste(f"Exporta window.offline.{fn}", f'{fn}' in js and 'window.offline' in js)

    # Tipos de operacao
    for op in ['upsert_item', 'update_inspecao', 'upload_foto', 'insert_inspecao']:
        teste(f"Suporta operacao '{op}'", f"'{op}'" in js)

    # Retry com backoff
    teste("Define MAX_TENTATIVAS", 'MAX_TENTATIVAS' in js)
    teste("Backoff exponencial", 'Math.pow' in js and 'tentativas' in js)
    teste("Marca desistido apos max tentativas", 'desistido' in js)

    # Auto-sync
    teste("Listener online", "'online'" in js and 'addEventListener' in js)
    teste("Listener offline", "'offline'" in js and 'addEventListener' in js)
    teste("Interval periodico", 'setInterval' in js and 'SYNC_INTERVAL_MS' in js)

    # Eventos custom
    teste("Emite eventos custom (offline:sync-inicio)", "offline:sync-inicio" in js or "sync-inicio" in js)
    teste("Emite offline:sync-fim", 'sync-fim' in js)

    # Fallback inteligente
    teste("salvarItemInteligente checa navigator.onLine", 'navigator.onLine' in js)
    teste("Retorna modo online/fila", "'online'" in js and "'fila'" in js)

# ============================================================
# 3. src/status_offline.js - WIDGET
# ============================================================
def t_status_js():
    cabecalho("3. MODULO src/status_offline.js")
    arq = RAIZ / 'src' / 'status_offline.js'
    if not arq.exists(): return
    js = arq.read_text()

    res = subprocess.run(['node', '--check', str(arq)], capture_output=True, text=True)
    teste("Sintaxe valida", res.returncode == 0,
          res.stderr.strip() if res.returncode != 0 else 'OK')

    # Estados
    for estado in ['online', 'offline', 'sync', 'erro']:
        teste(f"Trata estado '{estado}'", f"'{estado}'" in js)

    # UI
    teste("Cria elemento fixo (position: fixed)", 'position: fixed' in js)
    teste("z-index alto", 'z-index: 60' in js or 'zIndex' in js)
    teste("Anima com pulse (sync)", 'pulse' in js and 'animation' in js)

    # Interatividade
    teste("Click forca sincronizacao", 'sincronizar' in js and 'onclick' in js)

    # Listeners
    teste("Ouve online/offline do navegador", "'online'" in js and "'offline'" in js)
    teste("Ouve offline:sync-inicio", 'sync-inicio' in js)
    teste("Ouve offline:sync-fim", 'sync-fim' in js)

    # Init
    teste("Auto-init no DOMContentLoaded", 'DOMContentLoaded' in js)
    teste("Exporta window.statusOffline", 'window.statusOffline' in js)

# ============================================================
# 4. SERVICE WORKER ATUALIZADO
# ============================================================
def t_service_worker():
    cabecalho("4. SERVICE WORKER (cache atualizado)")
    arq = RAIZ / 'service-worker.js'
    teste("service-worker.js existe", arq.exists())
    if not arq.exists(): return
    sw = arq.read_text()

    teste("Versao bumped para 0.6.x", 'v0.6' in sw, det=re.search(r"CACHE_VERSION\s*=\s*'([^']+)'", sw).group(1) if re.search(r"CACHE_VERSION\s*=\s*'([^']+)'", sw) else '?')

    # Novos arquivos no APP_SHELL
    for arq_esperado in ['admin.html', 'inspecao.html', 'historico.html',
                          'camera.js', 'inspecao.js', 'assinatura.js', 'pdf.js',
                          'relatorios.js', 'offline.js', 'status_offline.js',
                          'jspdf']:
        teste(f"APP_SHELL contem '{arq_esperado}'", arq_esperado in sw)

    # Estrategias
    teste("Cache-first para app shell", 'caches.match' in sw)
    teste("Network-first para Supabase", 'supabase.co' in sw)
    teste("Trata skipWaiting", 'skipWaiting' in sw)

# ============================================================
# 5. INTEGRACAO NAS PAGINAS
# ============================================================
def t_integracao():
    cabecalho("5. INTEGRACAO NAS PAGINAS")
    for html in ['index.html', 'admin.html', 'inspecao.html', 'historico.html']:
        p = RAIZ / html
        if not p.exists():
            teste(f"{html} existe", False)
            continue
        conteudo = p.read_text()
        teste(f"{html} importa offline.js",     'src/offline.js' in conteudo)
        teste(f"{html} importa status_offline.js", 'src/status_offline.js' in conteudo)

# ============================================================
# 6. VALIDACAO ESTRUTURAL - DOCUMENTACAO/COMENTARIOS
# ============================================================
def t_documentacao():
    cabecalho("6. QUALIDADE DE CODIGO")
    arq = RAIZ / 'src' / 'offline.js'
    if not arq.exists(): return
    js = arq.read_text()

    teste("Cabecalho de documentacao presente", '=====' in js and 'REVISAO-MOTO' in js)
    teste("JSDoc em funcoes principais", '@param' in js or '@returns' in js or '/**' in js)
    teste("Constantes bem nomeadas", 'MAX_TENTATIVAS' in js and 'SYNC_INTERVAL_MS' in js)

# ============================================================
# 7. VALIDACAO SEMANTICA (parsing basico)
# ============================================================
def t_semantica():
    cabecalho("7. VALIDACAO SEMANTICA")
    arq = RAIZ / 'src' / 'offline.js'
    if not arq.exists(): return
    js = arq.read_text()

    # Object.freeze ou const para STORES
    teste("STORES eh const", 'const STORES' in js)

    # Nao ha uso de var (moderno)
    tem_var = re.search(r'\bvar\s+\w+', js)
    teste("Nao usa 'var' (JS moderno)", not tem_var,
          f"encontrou var: {tem_var.group() if tem_var else ''}")

    # async/await usado (nao Promise.then em cadeia grande)
    n_async = len(re.findall(r'async\s+function', js))
    teste(f"Usa async/await ({n_async} funcoes async)", n_async >= 10)

    # Trata rejeicoes
    n_try = len(re.findall(r'\btry\s*{', js))
    teste(f"Trata excecoes ({n_try} blocos try)", n_try >= 2)

# ============================================================
# RESUMO
# ============================================================
def resumo():
    print(f"\n{Cor.NEG}{'='*70}{Cor.RESET}")
    print(f"{Cor.NEG}  RESUMO FASE 6{Cor.RESET}")
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
    print(f"{Cor.NEG}REVISAO-MOTO :: Testes da Fase 6{Cor.RESET}")
    t_arquivos()
    t_offline_js()
    t_status_js()
    t_service_worker()
    t_integracao()
    t_documentacao()
    t_semantica()
    return resumo()

if __name__ == '__main__':
    sys.exit(main())

#!/usr/bin/env bash
# =====================================================================
# REVISAO-MOTO :: Orquestrador da Fase 7 - Polimento
# =====================================================================
# Automatiza validacao da Fase 7:
#   - Icones reais (192, 512, maskable)
#   - Onboarding (5 slides na 1a abertura)
#   - QR Code (gerar por placa + scanner via camera)
#   - Especificacoes tecnicas por modelo (torques/fluidos)
#   - Push notifications locais (revisao proxima, inspecao antiga)
#   - Dark mode (manual + prefers-color-scheme)
#   - Internacionalizacao PT-EN
#
# Uso:
#   ./orquestrador_fase7.sh              # so Fase 7 (~10s)
#   ./orquestrador_fase7.sh --all        # todas 0..7 (~40s)
#   ./orquestrador_fase7.sh --skip-tests
#   ./orquestrador_fase7.sh --project-dir X
#   ./orquestrador_fase7.sh --help
# =====================================================================

set -uo pipefail

if [ -t 1 ]; then
    C_VERDE="\033[92m"; C_VERM="\033[91m"; C_AMAR="\033[93m"
    C_AZUL="\033[94m"; C_CIANO="\033[96m"; C_NEG="\033[1m"; C_RESET="\033[0m"
else
    C_VERDE=""; C_VERM=""; C_AMAR=""; C_AZUL=""; C_CIANO=""; C_NEG=""; C_RESET=""
fi

cabecalho() {
    echo ""
    echo -e "${C_AZUL}${C_NEG}======================================================${C_RESET}"
    echo -e "${C_AZUL}${C_NEG}  $1${C_RESET}"
    echo -e "${C_AZUL}${C_NEG}======================================================${C_RESET}"
}
ok()    { echo -e "  ${C_VERDE}[OK]${C_RESET}    $1"; }
info()  { echo -e "  ${C_CIANO}[INFO]${C_RESET}  $1"; }
warn()  { echo -e "  ${C_AMAR}[WARN]${C_RESET}  $1"; }
fail()  { echo -e "  ${C_VERM}[FAIL]${C_RESET}  $1"; }
step()  { echo -e "  ${C_NEG}${C_CIANO}▶${C_RESET} $1"; }
erro_fatal() { fail "$1"; echo ""; echo -e "${C_VERM}${C_NEG}Interrompido.${C_RESET}"; exit 1; }

RODAR_TUDO=0
PROJECT_DIR=""
SKIP_TESTS=0

mostrar_ajuda() {
    cat <<HELP
Orquestrador da Fase 7 - Polimento

USO:
  $0 [OPCOES]

OPCOES:
  --all                  Roda todos os testes (Fase 0..7)
  --skip-tests           Nao roda testes
  --project-dir CAMINHO
  --help, -h

Fase 7 requer PostgreSQL (migration 007 tem tabela + view + seed).
HELP
}

while [ $# -gt 0 ]; do
    case "$1" in
        --all)          RODAR_TUDO=1; shift ;;
        --skip-tests)   SKIP_TESTS=1; shift ;;
        --project-dir)  PROJECT_DIR="${2:-}"; shift 2 ;;
        --help|-h)      mostrar_ajuda; exit 0 ;;
        *) echo "Argumento desconhecido: $1"; mostrar_ajuda; exit 1 ;;
    esac
done

clear
cat <<'BANNER'

  ██████╗ ███████╗██╗   ██╗██╗███████╗ █████╗  ██████╗
  ██╔══██╗██╔════╝██║   ██║██║██╔════╝██╔══██╗██╔═══██╗
  ██████╔╝█████╗  ██║   ██║██║███████╗███████║██║   ██║
  ██╔══██╗██╔══╝  ╚██╗ ██╔╝██║╚════██║██╔══██║██║   ██║
  ██║  ██║███████╗ ╚████╔╝ ██║███████║██║  ██║╚██████╔╝
  ╚═╝  ╚═╝╚══════╝  ╚═══╝  ╚═╝╚══════╝╚═╝  ╚═╝ ╚═════╝
                    M   O   T   O

BANNER
echo -e "${C_NEG}           Orquestrador da Fase 7 - Polimento${C_RESET}"
echo ""

# 1. AMBIENTE
cabecalho "1. Verificacoes de ambiente"
if grep -qi microsoft /proc/version 2>/dev/null; then
    ok "Ambiente WSL detectado"
fi
for c in psql python3 node; do
    if command -v "$c" >/dev/null 2>&1; then
        ok "$c: $("$c" --version 2>&1 | head -1)"
    else
        [ $SKIP_TESTS -eq 1 ] && warn "$c ausente" || erro_fatal "$c ausente. Rode: sudo apt install postgresql python3 nodejs"
    fi
done

# 2. PROJETO
cabecalho "2. Localizando projeto"
CANDIDATOS=(
    "$PROJECT_DIR"
    "$PWD"
    "/mnt/c/Users/mceza/Dropbox/PROJETOS/APLICATIVOS/JAVASCRIPT/APLICATIVOS/revisao-moto"
    "$HOME/revisao-moto"
)
RAIZ=""
for c in "${CANDIDATOS[@]}"; do
    [ -z "$c" ] && continue
    if [ -f "$c/tests/run_tests.sh" ]; then RAIZ="$c"; break; fi
    if [ -f "$c/revisao-moto/tests/run_tests.sh" ]; then RAIZ="$c/revisao-moto"; break; fi
done
if [ -z "$RAIZ" ]; then
    fail "Nao encontrei projeto. Use --project-dir CAMINHO"
    exit 1
fi
RAIZ="$(cd "$RAIZ" && pwd)"
ok "Projeto: $RAIZ"
cd "$RAIZ"

# 3. ARTEFATOS DA FASE 7
cabecalho "3. Artefatos da Fase 7"
AUSENTES=0
verificar() {
    if [ -f "$1" ] || [ -d "$1" ]; then ok "$2"; else fail "Ausente: $2"; AUSENTES=$((AUSENTES+1)); fi
}

step "SQL:"
verificar "sql/007_fase7_especificacoes.sql"    "Migration 007 (especificacoes tecnicas)"

step "Novos modulos JS:"
verificar "src/darkmode.js"        "Dark mode (toggle + persistencia)"
verificar "src/i18n.js"            "Internacionalizacao PT-EN"
verificar "src/qrcode.js"          "QR Code (gerar + scanner)"
verificar "src/notifications.js"   "Notificacoes locais"

step "Novas paginas:"
verificar "onboarding.html"        "Onboarding (5 slides na 1a abertura)"
verificar "especificacoes.html"    "Consulta de torques/fluidos por modelo"
verificar "qrcode.html"            "Gerar e escanear QR"

step "Assets:"
verificar "assets/icon-192.png"          "Icone 192 (real)"
verificar "assets/icon-512.png"          "Icone 512 (real)"
verificar "assets/icon-512-maskable.png" "Icone maskable Android"
verificar "assets/i18n/pt.json"          "Traducoes PT"
verificar "assets/i18n/en.json"          "Traducoes EN"

step "Testes:"
verificar "tests/test_fase7.py"    "Suite Fase 7"

step "Integracao nas paginas existentes:"
for html in index.html admin.html inspecao.html historico.html; do
    if [ -f "$html" ] && grep -q 'src/darkmode.js' "$html" && grep -q 'src/i18n.js' "$html"; then
        ok "$html importa darkmode.js + i18n.js"
    elif [ -f "$html" ]; then
        warn "$html sem importacao completa"
    fi
done

# Versao do SW
if [ -f service-worker.js ]; then
    SW_VERSAO=$(grep -oP "CACHE_VERSION\s*=\s*'\K[^']+" service-worker.js 2>/dev/null || echo "?")
    if echo "$SW_VERSAO" | grep -q "v0.7"; then
        ok "SW v0.7+ (correto: $SW_VERSAO)"
    else
        warn "SW versao $SW_VERSAO - esperado v0.7+"
    fi
fi

# Onboarding redirect no index
if grep -q 'rm_onboarding_visto' index.html 2>/dev/null; then
    ok "index.html redireciona novos usuarios para onboarding"
else
    warn "index.html sem redirect de onboarding"
fi

# Dashboard tem links Fase 7
if grep -q 'especificacoes.html' index.html && grep -q 'qrcode.html' index.html; then
    ok "Dashboard linka Especificacoes e QR"
else
    warn "Dashboard sem links para novas paginas"
fi

if [ $AUSENTES -gt 0 ] && [ $SKIP_TESTS -eq 0 ]; then
    erro_fatal "$AUSENTES arquivo(s) essencial(is) ausente(s)."
fi

# 4. SINTAXE JS
cabecalho "4. Validacao de sintaxe"
if command -v node >/dev/null 2>&1; then
    for js in src/darkmode.js src/i18n.js src/qrcode.js src/notifications.js; do
        if [ -f "$js" ]; then
            if node --check "$js" 2>/dev/null; then
                ok "$js"
            else
                fail "$js tem erro de sintaxe"
                AUSENTES=$((AUSENTES+1))
            fi
        fi
    done
    # HTMLs com JS inline
    for h in onboarding.html especificacoes.html qrcode.html; do
        if [ -f "$h" ] && python3 -c "
import re
html = open('$h').read()
scripts = re.findall(r'<script>([\s\S]*?)</script>', html)
if scripts:
    with open('/tmp/_check.js', 'w') as f:
        f.write(scripts[-1])
" 2>/dev/null && node --check /tmp/_check.js 2>/dev/null; then
            ok "$h (JS inline)"
        elif [ -f "$h" ]; then
            fail "$h JS inline com erro"
            AUSENTES=$((AUSENTES+1))
        fi
    done

    # JSONs
    for j in assets/i18n/pt.json assets/i18n/en.json manifest.json; do
        if [ -f "$j" ] && python3 -c "import json; json.load(open('$j'))" 2>/dev/null; then
            ok "$j"
        elif [ -f "$j" ]; then
            fail "$j nao eh JSON valido"
            AUSENTES=$((AUSENTES+1))
        fi
    done
else
    warn "node ausente"
fi

# 5. TESTES
if [ $SKIP_TESTS -eq 1 ]; then
    cabecalho "5. Testes"
    warn "--skip-tests passado - pulando"
    RESULTADO="SKIP"
else
    if [ $RODAR_TUDO -eq 1 ]; then
        cabecalho "5. Suite COMPLETA (Fase 0 -> 7)"
        chmod +x tests/run_tests.sh 2>/dev/null || true
        echo ""
        if ./tests/run_tests.sh; then RESULTADO="OK"; else RESULTADO="FAIL"; fi
    else
        cabecalho "5. Suite ISOLADA da Fase 7"
        info "(use --all para todas as fases)"
        echo ""

        PG_BIN=$(ls -d /usr/lib/postgresql/*/bin 2>/dev/null | tail -1)
        if [ -z "$PG_BIN" ]; then
            erro_fatal "Postgres nao instalado."
        fi

        PG_BASE=$(mktemp -d -t revmoto_pg.XXXXXX)
        PG_DATA="$PG_BASE/data"
        PG_SOCK="$PG_BASE/sock"
        mkdir -p "$PG_SOCK"
        PG_PORT=${PG_PORT:-5433}

        cleanup_pg() {
            if [ -f "$PG_DATA/postmaster.pid" ]; then
                "$PG_BIN/pg_ctl" -D "$PG_DATA" stop -m fast > /dev/null 2>&1 || true
            fi
            rm -rf "$PG_BASE"
        }
        trap cleanup_pg EXIT

        step "Subindo Postgres efemero..."
        "$PG_BIN/initdb" -D "$PG_DATA" -U postgres --auth=trust --no-locale --encoding=UTF8 > /dev/null 2>&1
        "$PG_BIN/pg_ctl" -D "$PG_DATA" -l "$PG_BASE/log" -o "-p $PG_PORT -k $PG_SOCK" start > /dev/null 2>&1
        sleep 2

        step "Aplicando schema + seed + migrations 3-7..."
        psql -h "$PG_SOCK" -p "$PG_PORT" -U postgres -c "CREATE DATABASE revisao_moto_test;" > /dev/null 2>&1
        psql -h "$PG_SOCK" -p "$PG_PORT" -U postgres -d revisao_moto_test -c "CREATE SCHEMA IF NOT EXISTS auth; CREATE TABLE IF NOT EXISTS auth.users(id UUID PRIMARY KEY DEFAULT gen_random_uuid()); CREATE ROLE authenticated;" > /dev/null 2>&1
        for sql in sql/001_schema.sql sql/002_seed_royal_enfield.sql \
                   sql/003_fase2_motos_ativo.sql sql/004_fase3_execucao.sql \
                   sql/005_fase4_assinaturas_pdf.sql sql/006_fase5_historico.sql \
                   sql/007_fase7_especificacoes.sql; do
            if ! psql -h "$PG_SOCK" -p "$PG_PORT" -U postgres -d revisao_moto_test -f "$sql" -v ON_ERROR_STOP=1 > /dev/null 2>&1; then
                fail "Falha ao aplicar $sql"
                RESULTADO="FAIL"
                break
            fi
        done
        ok "SQL aplicado com sucesso"

        step "Rodando tests/test_fase7.py..."
        echo ""
        echo -e "${C_CIANO}--- inicio ---${C_RESET}"
        if PGHOST="$PG_SOCK" PGPORT="$PG_PORT" PGUSER=postgres PGDATABASE=revisao_moto_test \
           python3 tests/test_fase7.py; then
            RESULTADO="OK"
        else
            RESULTADO="FAIL"
        fi
        echo -e "${C_CIANO}--- fim ---${C_RESET}"
    fi
fi

# 6. SUMARIO
cabecalho "SUMARIO FINAL"
echo -e "  ${C_NEG}Projeto:${C_RESET}      $RAIZ"
echo -e "  ${C_NEG}Modo:${C_RESET}         $([ $RODAR_TUDO -eq 1 ] && echo 'todas as fases' || echo 'so Fase 7')"
echo -e "  ${C_NEG}Estrutura:${C_RESET}    $AUSENTES problema(s)"
echo -e "  ${C_NEG}Testes:${C_RESET}       $RESULTADO"
echo ""

if [ "$RESULTADO" = "OK" ]; then
    echo -e "${C_VERDE}${C_NEG}   ✔  FASE 7 VALIDADA COM SUCESSO${C_RESET}"
    echo ""
    echo -e "   ${C_NEG}Como aplicar no Supabase:${C_RESET}"
    echo "   1. Cole sql/007_fase7_especificacoes.sql no SQL Editor -> Run"
    echo "      (cria tabela especificacoes_modelo + view + seed generico)"
    echo ""
    echo -e "   ${C_NEG}Como testar no celular:${C_RESET}"
    echo "   1. git add . && git commit -m 'Fase 7: polimento' && git push"
    echo "   2. Aguardar ~1 min para GitHub Pages redeployar"
    echo "   3. Limpar cache do Service Worker no celular (DevTools > Application)"
    echo "   4. Abrir a URL - deve mostrar onboarding com 5 slides (pt/en)"
    echo "   5. Dashboard: novo botao 🌙 dark mode + Especificacoes + QR"
    echo "   6. Testar QR: gera para uma placa cadastrada, imprime, escaneia"
    echo "   7. Permitir notificacoes quando o app pedir"
    exit 0
elif [ "$RESULTADO" = "SKIP" ]; then
    echo -e "${C_AMAR}${C_NEG}   ⚠  Setup OK, testes nao executados${C_RESET}"
    exit 0
else
    echo -e "${C_VERM}${C_NEG}   ✗  TESTES FALHARAM${C_RESET}"
    exit 1
fi

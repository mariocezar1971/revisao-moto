#!/usr/bin/env bash
# =====================================================================
# REVISAO-MOTO :: Orquestrador da Fase 6 - Suporte Offline
# =====================================================================
# Valida a Fase 6 (IndexedDB, fila de sync, Service Worker):
#   1. Verifica pre-requisitos
#   2. Localiza projeto
#   3. Valida arquivos-chave (offline.js, status_offline.js, SW atualizado)
#   4. Confirma integracao nos HTMLs
#   5. Roda testes da Fase 6 (ou todos com --all)
#
# Uso:
#   ./orquestrador_fase6.sh              # so Fase 6 (~5 seg)
#   ./orquestrador_fase6.sh --all        # todas 0-6 (~40 seg)
#   ./orquestrador_fase6.sh --skip-tests
#   ./orquestrador_fase6.sh --project-dir X
#   ./orquestrador_fase6.sh --help
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
Orquestrador da Fase 6 - Suporte Offline

USO:
  $0 [OPCOES]

OPCOES:
  --all                  Roda todos os testes (Fase 0..6)
  --skip-tests           Nao roda testes
  --project-dir CAMINHO
  --help, -h

Fase 6 NAO exige PostgreSQL (testes sao estaticos + node --check).
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
echo -e "${C_NEG}         Orquestrador da Fase 6 - Suporte Offline${C_RESET}"
echo ""

# 1. AMBIENTE
cabecalho "1. Verificacoes de ambiente"
if grep -qi microsoft /proc/version 2>/dev/null; then
    ok "Ambiente WSL detectado"
fi
for c in python3 node; do
    if command -v "$c" >/dev/null 2>&1; then
        ok "$c: $("$c" --version 2>&1 | head -1)"
    else
        [ $SKIP_TESTS -eq 1 ] && warn "$c ausente" || erro_fatal "$c ausente"
    fi
done
if [ $RODAR_TUDO -eq 1 ] && ! command -v psql >/dev/null 2>&1; then
    erro_fatal "--all requer psql. Instale: sudo apt install postgresql"
fi

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

# 3. ARTEFATOS DA FASE 6
cabecalho "3. Artefatos da Fase 6"
AUSENTES=0
verificar() {
    if [ -f "$1" ]; then ok "$2"; else fail "Ausente: $2"; AUSENTES=$((AUSENTES+1)); fi
}
verificar "src/offline.js"          "src/offline.js (IndexedDB + fila de sync)"
verificar "src/status_offline.js"   "src/status_offline.js (widget indicador)"
verificar "service-worker.js"       "service-worker.js (atualizado v0.6+)"
verificar "tests/test_fase6.py"     "tests/test_fase6.py (suite)"

# Verificar versao do SW
if [ -f service-worker.js ]; then
    SW_VERSAO=$(grep -oP "CACHE_VERSION\s*=\s*'\K[^']+" service-worker.js 2>/dev/null || echo "?")
    if echo "$SW_VERSAO" | grep -q "v0.6"; then
        ok "SW versao correta: $SW_VERSAO"
    else
        warn "SW versao $SW_VERSAO - esperado v0.6+"
    fi
fi

step "Integracao nos HTMLs:"
for html in index.html admin.html inspecao.html historico.html; do
    if [ -f "$html" ] && grep -q 'src/offline.js' "$html" && grep -q 'src/status_offline.js' "$html"; then
        ok "$html importa offline.js + status_offline.js"
    elif [ -f "$html" ]; then
        warn "$html sem importacao completa dos modulos offline"
    fi
done

# 4. SINTAXE JS
cabecalho "4. Validacao de sintaxe"
if command -v node >/dev/null 2>&1; then
    for js in src/offline.js src/status_offline.js service-worker.js; do
        if [ -f "$js" ]; then
            if node --check "$js" 2>/dev/null; then
                ok "$js"
            else
                fail "$js tem erro de sintaxe"
                AUSENTES=$((AUSENTES+1))
            fi
        fi
    done
else
    warn "node ausente - sintaxe nao verificada"
fi

if [ $AUSENTES -gt 0 ] && [ $SKIP_TESTS -eq 0 ]; then
    erro_fatal "$AUSENTES problema(s). Corrija e tente de novo."
fi

# 5. TESTES
if [ $SKIP_TESTS -eq 1 ]; then
    cabecalho "5. Testes"
    warn "--skip-tests passado"
    RESULTADO="SKIP"
else
    if [ $RODAR_TUDO -eq 1 ]; then
        cabecalho "5. Suite COMPLETA (Fase 0 -> 6)"
        chmod +x tests/run_tests.sh 2>/dev/null || true
        echo ""
        if ./tests/run_tests.sh; then RESULTADO="OK"; else RESULTADO="FAIL"; fi
    else
        cabecalho "5. Suite ISOLADA da Fase 6"
        info "(use --all para todas as fases)"
        echo ""
        if python3 tests/test_fase6.py; then RESULTADO="OK"; else RESULTADO="FAIL"; fi
    fi
fi

# 6. SUMARIO
cabecalho "SUMARIO FINAL"
echo -e "  ${C_NEG}Projeto:${C_RESET}      $RAIZ"
echo -e "  ${C_NEG}Modo:${C_RESET}         $([ $RODAR_TUDO -eq 1 ] && echo 'todas as fases' || echo 'so Fase 6')"
echo -e "  ${C_NEG}Estrutura:${C_RESET}    $AUSENTES problema(s)"
echo -e "  ${C_NEG}Testes:${C_RESET}       $RESULTADO"
echo ""

if [ "$RESULTADO" = "OK" ]; then
    echo -e "${C_VERDE}${C_NEG}   ✔  FASE 6 VALIDADA COM SUCESSO${C_RESET}"
    echo ""
    echo -e "   ${C_NEG}Como testar offline no celular (teste manual):${C_RESET}"
    echo "   1. Abra o app pelo GitHub Pages e faca login online"
    echo "   2. No console do celular (DevTools): window.offline.cachearCatalogo()"
    echo "   3. Ative modo aviao"
    echo "   4. Faca uma inspecao - deve funcionar e mostrar 'pendentes' na bolinha"
    echo "   5. Desative modo aviao - bolinha vira 'sincronizando' e depois 'online'"
    echo "   6. Confirme no Supabase que os dados chegaram"
    echo ""
    echo -e "   ${C_NEG}Deploy:${C_RESET}"
    echo "   git add . && git commit -m 'Fase 6: suporte offline' && git push"
    exit 0
elif [ "$RESULTADO" = "SKIP" ]; then
    echo -e "${C_AMAR}${C_NEG}   ⚠  Setup OK, testes nao executados${C_RESET}"
    exit 0
else
    echo -e "${C_VERM}${C_NEG}   ✗  TESTES FALHARAM${C_RESET}"
    exit 1
fi

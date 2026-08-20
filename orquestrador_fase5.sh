#!/usr/bin/env bash
# =====================================================================
# REVISAO-MOTO :: Orquestrador da Fase 5 - Historico e Relatorios
# =====================================================================
# Automatiza validacao da Fase 5:
#   1. Verifica pre-requisitos (mesmas ferramentas da Fase 0)
#   2. Localiza projeto
#   3. Valida arquivos-chave da Fase 5 (SQL, JS, HTML, testes)
#   4. Executa apenas a suite de testes da Fase 5 (ou tudo com --all)
#   5. Reporta status final
#
# Uso:
#   ./orquestrador_fase5.sh                   # so testa a Fase 5
#   ./orquestrador_fase5.sh --all             # roda todas as fases (0-5)
#   ./orquestrador_fase5.sh --skip-tests      # so valida estrutura
#   ./orquestrador_fase5.sh --project-dir X
#   ./orquestrador_fase5.sh --help
# =====================================================================

set -uo pipefail

# CORES
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
erro_fatal() {
    fail "$1"
    echo ""
    echo -e "${C_VERM}${C_NEG}Orquestrador interrompido.${C_RESET}"
    exit 1
}

# ARGS
RODAR_TUDO=0
PROJECT_DIR=""
SKIP_TESTS=0

mostrar_ajuda() {
    cat <<HELP
Orquestrador da Fase 5 - Historico e Relatorios

USO:
  $0 [OPCOES]

OPCOES:
  --all                  Roda todos os testes (Fase 0+1+2+3+4+5)
                         Sem essa flag, roda apenas testes da Fase 5.
  --skip-tests           Nao roda testes (so valida estrutura)
  --project-dir CAMINHO  Aponta pasta do projeto
  --help, -h             Esta ajuda

EXEMPLOS:
  ./orquestrador_fase5.sh              # Testa so a Fase 5 (~15s)
  ./orquestrador_fase5.sh --all        # Testa tudo (~40s)
  ./orquestrador_fase5.sh --skip-tests # So valida estrutura
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

# BANNER
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
echo -e "${C_NEG}     Orquestrador da Fase 5 - Historico e Relatorios${C_RESET}"
echo ""

# 1. AMBIENTE
cabecalho "1. Verificacoes de ambiente"
if grep -qi microsoft /proc/version 2>/dev/null; then
    ok "Ambiente WSL detectado ($(lsb_release -ds 2>/dev/null || echo Ubuntu))"
else
    warn "Nao parece ser WSL. Continuando."
fi
for c in psql python3 node; do
    if command -v "$c" >/dev/null 2>&1; then
        ok "$c: $("$c" --version 2>&1 | head -1)"
    else
        if [ $SKIP_TESTS -eq 1 ]; then
            warn "$c ausente (nao-fatal com --skip-tests)"
        else
            erro_fatal "$c ausente. Rode: sudo apt install postgresql python3 nodejs"
        fi
    fi
done

# 2. LOCALIZAR PROJETO
cabecalho "2. Localizando projeto"
CANDIDATOS=(
    "$PROJECT_DIR"
    "$PWD"
    "/mnt/c/Users/mceza/Dropbox/PROJETOS/APLICATIVOS/JAVASCRIPT/APLICATIVOS/revisao-moto"
    "/mnt/c/Users/mceza/Dropbox/PROGRAMACAO/JAVASCRIPT/APLICATIVOS/revisao-moto"
    "$HOME/revisao-moto"
)
RAIZ=""
for c in "${CANDIDATOS[@]}"; do
    [ -z "$c" ] && continue
    if [ -f "$c/sql/001_schema.sql" ] && [ -f "$c/tests/run_tests.sh" ]; then
        RAIZ="$c"; break
    fi
    if [ -f "$c/revisao-moto/sql/001_schema.sql" ]; then
        RAIZ="$c/revisao-moto"; break
    fi
done
if [ -z "$RAIZ" ]; then
    fail "Nao encontrei projeto. Use --project-dir CAMINHO"
    exit 1
fi
RAIZ="$(cd "$RAIZ" && pwd)"
ok "Projeto: $RAIZ"
cd "$RAIZ"

# 3. VALIDAR ARTEFATOS DA FASE 5
cabecalho "3. Artefatos da Fase 5"

verificar_arquivo() {
    if [ -f "$1" ] || [ -d "$1" ]; then
        ok "$2"; return 0
    else
        fail "Ausente: $2 ($1)"; return 1
    fi
}

AUSENTES=0
step "Novos arquivos da Fase 5:"
verificar_arquivo "sql/006_fase5_historico.sql"      "Migration SQL"                      || AUSENTES=$((AUSENTES+1))
verificar_arquivo "sql/validacao_fase5.sql"          "Validacao SQL inline"               || AUSENTES=$((AUSENTES+1))
verificar_arquivo "src/relatorios.js"                "Modulo src/relatorios.js"           || AUSENTES=$((AUSENTES+1))
verificar_arquivo "historico.html"                   "Pagina historico.html"              || AUSENTES=$((AUSENTES+1))
verificar_arquivo "tests/test_fase5.py"              "Suite tests/test_fase5.py"          || AUSENTES=$((AUSENTES+1))

step "Fases anteriores (dependencias):"
for f in "sql/005_fase4_assinaturas_pdf.sql:Fase 4" \
         "sql/004_fase3_execucao.sql:Fase 3" \
         "sql/003_fase2_motos_ativo.sql:Fase 2" \
         "sql/002_seed_royal_enfield.sql:Fase 1" \
         "sql/001_schema.sql:Fase 0"; do
    arq="${f%%:*}"; desc="${f##*:}"
    verificar_arquivo "$arq" "$desc" || AUSENTES=$((AUSENTES+1))
done

step "Integracao no index.html:"
if grep -q "historico.html" index.html 2>/dev/null; then
    ok "index.html tem link para historico.html"
else
    warn "index.html sem link para historico.html - adicione manualmente"
fi

if [ $AUSENTES -gt 0 ]; then
    if [ $SKIP_TESTS -eq 1 ]; then
        warn "$AUSENTES arquivo(s) ausente(s), mas --skip-tests passado"
    else
        erro_fatal "$AUSENTES arquivo(s) essencial(is) ausente(s)."
    fi
fi

# 4. VALIDAR SINTAXE JS
cabecalho "4. Validacao de sintaxe (node --check)"
JS_OK=0; JS_ERR=0
if command -v node >/dev/null 2>&1; then
    for js in src/relatorios.js; do
        if [ -f "$js" ]; then
            if node --check "$js" 2>/dev/null; then
                ok "$js"; JS_OK=$((JS_OK+1))
            else
                fail "$js tem erro de sintaxe"; JS_ERR=$((JS_ERR+1))
            fi
        fi
    done
    # HTML inline
    if [ -f historico.html ]; then
        if python3 -c "
import re
html = open('historico.html').read()
scripts = re.findall(r'<script>([\s\S]*?)</script>', html)
if scripts:
    with open('/tmp/_check_historico.js', 'w') as f:
        f.write(scripts[-1])
" 2>/dev/null && node --check /tmp/_check_historico.js 2>/dev/null; then
            ok "historico.html (JS inline)"; JS_OK=$((JS_OK+1))
        else
            fail "historico.html JS inline tem erro"; JS_ERR=$((JS_ERR+1))
        fi
    fi
else
    warn "node ausente - sintaxe JS nao verificada"
fi

# 5. TESTES
if [ $SKIP_TESTS -eq 1 ]; then
    cabecalho "5. Testes"
    warn "--skip-tests passado - pulando"
    RESULTADO="SKIP"
else
    if [ $RODAR_TUDO -eq 1 ]; then
        cabecalho "5. Suite COMPLETA (Fase 0 -> 5)"
        chmod +x tests/run_tests.sh 2>/dev/null || true
        echo -e "${C_CIANO}--- inicio ---${C_RESET}"
        if ./tests/run_tests.sh; then
            RESULTADO="OK"
        else
            RESULTADO="FAIL"
        fi
        echo -e "${C_CIANO}--- fim ---${C_RESET}"
    else
        cabecalho "5. Suite ISOLADA da Fase 5"
        info "(use --all para rodar todas as fases)"
        echo ""

        # Precisa de um Postgres efemero
        PG_BIN=$(ls -d /usr/lib/postgresql/*/bin 2>/dev/null | tail -1)
        if [ -z "$PG_BIN" ]; then
            erro_fatal "Postgres nao instalado - impossivel testar isoladamente."
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

        step "Aplicando schema + seed + migrations 3-6..."
        psql -h "$PG_SOCK" -p "$PG_PORT" -U postgres -c "CREATE DATABASE revisao_moto_test;" > /dev/null 2>&1
        psql -h "$PG_SOCK" -p "$PG_PORT" -U postgres -d revisao_moto_test -c "CREATE SCHEMA IF NOT EXISTS auth; CREATE TABLE IF NOT EXISTS auth.users(id UUID PRIMARY KEY DEFAULT gen_random_uuid()); CREATE ROLE authenticated;" > /dev/null 2>&1
        for sql in sql/001_schema.sql sql/002_seed_royal_enfield.sql \
                   sql/003_fase2_motos_ativo.sql sql/004_fase3_execucao.sql \
                   sql/005_fase4_assinaturas_pdf.sql sql/006_fase5_historico.sql; do
            if ! psql -h "$PG_SOCK" -p "$PG_PORT" -U postgres -d revisao_moto_test -f "$sql" -v ON_ERROR_STOP=1 > /dev/null 2>&1; then
                fail "Falha ao aplicar $sql"
                RESULTADO="FAIL"
                break
            fi
        done
        ok "SQL aplicado com sucesso"

        step "Rodando tests/test_fase5.py..."
        echo ""
        echo -e "${C_CIANO}--- inicio ---${C_RESET}"
        if PGHOST="$PG_SOCK" PGPORT="$PG_PORT" PGUSER=postgres PGDATABASE=revisao_moto_test \
           python3 tests/test_fase5.py; then
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
echo -e "  ${C_NEG}Modo:${C_RESET}         $([ $RODAR_TUDO -eq 1 ] && echo 'todas as fases' || echo 'so Fase 5')"
echo -e "  ${C_NEG}Estrutura:${C_RESET}    $AUSENTES arquivo(s) ausente(s)"
echo -e "  ${C_NEG}Testes:${C_RESET}       $RESULTADO"
echo ""

if [ "$RESULTADO" = "OK" ]; then
    echo -e "${C_VERDE}${C_NEG}   ✔  FASE 5 VALIDADA COM SUCESSO${C_RESET}"
    echo ""
    echo -e "   ${C_NEG}Proximos passos:${C_RESET}"
    echo "   1. Aplicar sql/006_fase5_historico.sql no Supabase (SQL Editor)"
    echo "   2. Validar com sql/validacao_fase5.sql (esperado: 5 PASS)"
    echo "   3. Testar historico.html no celular:"
    echo "      - Aba Motos: status de revisao (em dia/proxima/atrasada)"
    echo "      - Aba Inspecoes: filtros + export CSV"
    echo "      - Aba Relatorios: KPIs, mecanico/mes, problemas comuns"
    echo "   4. git add . && git commit -m 'Fase 5: historico e relatorios' && git push"
    echo ""
    exit 0
elif [ "$RESULTADO" = "SKIP" ]; then
    echo -e "${C_AMAR}${C_NEG}   ⚠  SETUP OK, TESTES NAO EXECUTADOS${C_RESET}"
    exit 0
else
    echo -e "${C_VERM}${C_NEG}   ✗  TESTES FALHARAM${C_RESET}"
    exit 1
fi

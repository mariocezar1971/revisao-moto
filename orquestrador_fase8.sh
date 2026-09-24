#!/usr/bin/env bash
# =====================================================================
# REVISAO-MOTO :: Orquestrador da Fase 8 (P1) - Operacao Real
# =====================================================================
# Automatiza validacao dos 4 itens criticos do roadmap Fase 8+:
#   1. Medicao numerica com limites (semaforo + taxa de desgaste)
#   2. Queixa do cliente + resolucao
#   3. Itens avulsos fora do checklist
#   4. Pecas e orcamento (+ aprovacao previa CDC art. 40)
#
# Uso:
#   ./orquestrador_fase8.sh              # so Fase 8 (~15s)
#   ./orquestrador_fase8.sh --all        # todas 0..8 (~50s)
#   ./orquestrador_fase8.sh --skip-tests
#   ./orquestrador_fase8.sh --project-dir X
#   ./orquestrador_fase8.sh --help
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
step()  { echo -e "  ${C_NEG}${C_CIANO}>${C_RESET} $1"; }
erro_fatal() { fail "$1"; echo ""; echo -e "${C_VERM}${C_NEG}Interrompido.${C_RESET}"; exit 1; }

RODAR_TUDO=0
PROJECT_DIR=""
SKIP_TESTS=0

mostrar_ajuda() {
    cat <<HELP
Orquestrador da Fase 8 (P1) - Operacao Real

USO:
  $0 [OPCOES]

OPCOES:
  --all                  Roda todos os testes (Fase 0..8)
  --skip-tests           Nao roda testes
  --project-dir CAMINHO
  --help, -h

A Fase 8 requer PostgreSQL: a migration 008 altera tabelas existentes,
cria 3 tabelas novas, 2 funcoes, 3 views e faz seed de limites por regex.
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
echo -e "${C_NEG}        Orquestrador da Fase 8 (P1) - Operacao Real${C_RESET}"
echo ""

# ---------------------------------------------------------------------
# 1. AMBIENTE
# ---------------------------------------------------------------------
cabecalho "1. Verificacoes de ambiente"
if grep -qi microsoft /proc/version 2>/dev/null; then
    ok "Ambiente WSL detectado"
fi
for c in psql python3 node; do
    if command -v "$c" >/dev/null 2>&1; then
        ok "$c: $("$c" --version 2>&1 | head -1)"
    else
        [ $SKIP_TESTS -eq 1 ] && warn "$c ausente" \
            || erro_fatal "$c ausente. Rode: sudo apt install postgresql python3 nodejs"
    fi
done

# ---------------------------------------------------------------------
# 2. PROJETO
# ---------------------------------------------------------------------
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
[ -z "$RAIZ" ] && erro_fatal "Nao encontrei projeto. Use --project-dir CAMINHO"
RAIZ="$(cd "$RAIZ" && pwd)"
ok "Projeto: $RAIZ"
cd "$RAIZ"

# ---------------------------------------------------------------------
# 3. ARTEFATOS
# ---------------------------------------------------------------------
cabecalho "3. Artefatos da Fase 8"
AUSENTES=0
verificar() {
    if [ -f "$1" ] || [ -d "$1" ]; then ok "$2"; else fail "Ausente: $2"; AUSENTES=$((AUSENTES+1)); fi
}

step "SQL:"
verificar "sql/008_fase8_p1.sql"   "Migration 008 (4 blocos P1)"

step "Novos modulos JS:"
verificar "src/medicoes.js"        "Semaforo + taxa de desgaste"
verificar "src/avulsos.js"         "Itens fora do checklist"
verificar "src/orcamento.js"       "Pecas, mao de obra e aprovacao"

step "Testes:"
verificar "tests/test_fase8.py"    "Suite Fase 8 (145 testes)"

step "Integracao no inspecao.html:"
if [ -f inspecao.html ]; then
    for par in \
        "input-queixa:campo de relato do cliente" \
        "input-resolucao:campo de resolucao" \
        "modal-avulso:modal de item avulso" \
        "modal-peca:modal de peca" \
        "modal-servico:modal de mao de obra" \
        "modal-aprovacao:modal de aprovacao do orcamento" \
        "aplicarSemaforo:semaforo nas medicoes" \
        "mostrarDesgaste:previsao de troca" \
        "podeExecutar:trava de orcamento nao aprovado"
    do
        chave="${par%%:*}"; desc="${par#*:}"
        if grep -q "$chave" inspecao.html; then ok "$desc"
        else warn "ausente: $desc"; fi
    done
fi

step "Integracao no PDF:"
if [ -f src/pdf.js ]; then
    for par in \
        "RELATO DO CLIENTE:secao de relato" \
        "ITENS ADICIONAIS:secao de avulsos" \
        "ORCAMENTO:secao de orcamento" \
        "total_geral:total do orcamento"
    do
        chave="${par%%:*}"; desc="${par#*:}"
        if grep -q "$chave" src/pdf.js; then ok "$desc"
        else warn "ausente: $desc"; fi
    done
fi

# Versao do SW
if [ -f service-worker.js ]; then
    SW_VERSAO=$(grep -oP "CACHE_VERSION\s*=\s*'\K[^']+" service-worker.js 2>/dev/null || echo "?")
    if echo "$SW_VERSAO" | grep -q "v0.8"; then
        ok "SW v0.8+ (correto: $SW_VERSAO)"
    else
        warn "SW versao $SW_VERSAO - esperado v0.8+"
    fi
fi

[ $AUSENTES -gt 0 ] && [ $SKIP_TESTS -eq 0 ] && erro_fatal "$AUSENTES arquivo(s) essencial(is) ausente(s)."

# ---------------------------------------------------------------------
# 4. SINTAXE
# ---------------------------------------------------------------------
cabecalho "4. Validacao de sintaxe"
if command -v node >/dev/null 2>&1; then
    for js in src/medicoes.js src/avulsos.js src/orcamento.js src/pdf.js src/inspecao.js; do
        if [ -f "$js" ]; then
            if node --check "$js" 2>/dev/null; then ok "$js"
            else fail "$js tem erro de sintaxe"; AUSENTES=$((AUSENTES+1)); fi
        fi
    done

    # JS inline do inspecao.html (varios blocos)
    if [ -f inspecao.html ]; then
        python3 - <<'PY' > /tmp/_blocos.txt 2>/dev/null
import re
html = open('inspecao.html').read()
blocos = re.findall(r'<script>([\s\S]*?)</script>', html)
for i, b in enumerate(blocos):
    open(f'/tmp/_inline{i}.js', 'w').write(b)
print(len(blocos))
PY
        N=$(cat /tmp/_blocos.txt 2>/dev/null || echo 0)
        ERRO_INLINE=0
        for i in $(seq 0 $((N-1))); do
            node --check "/tmp/_inline$i.js" 2>/dev/null || ERRO_INLINE=1
        done
        if [ $ERRO_INLINE -eq 0 ]; then ok "inspecao.html ($N blocos inline)"
        else fail "inspecao.html tem erro em JS inline"; AUSENTES=$((AUSENTES+1)); fi
        rm -f /tmp/_inline*.js /tmp/_blocos.txt
    fi
else
    warn "node ausente"
fi

# ---------------------------------------------------------------------
# 5. TESTES
# ---------------------------------------------------------------------
if [ $SKIP_TESTS -eq 1 ]; then
    cabecalho "5. Testes"
    warn "--skip-tests passado - pulando"
    RESULTADO="SKIP"
elif [ $RODAR_TUDO -eq 1 ]; then
    cabecalho "5. Suite COMPLETA (Fase 0 -> 8)"
    chmod +x tests/run_tests.sh 2>/dev/null || true
    echo ""
    if ./tests/run_tests.sh; then RESULTADO="OK"; else RESULTADO="FAIL"; fi
else
    cabecalho "5. Suite ISOLADA da Fase 8"
    info "(use --all para todas as fases)"
    echo ""

    PG_BIN=$(ls -d /usr/lib/postgresql/*/bin 2>/dev/null | tail -1)
    [ -z "$PG_BIN" ] && erro_fatal "Postgres nao instalado."

    PG_BASE=$(mktemp -d -t revmoto_pg8.XXXXXX)
    PG_DATA="$PG_BASE/data"
    PG_SOCK="$PG_BASE/sock"
    mkdir -p "$PG_SOCK"
    PG_PORT=${PG_PORT:-5441}

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

    step "Aplicando schema + seed + migrations 3..7..."
    psql -h "$PG_SOCK" -p "$PG_PORT" -U postgres -c "CREATE DATABASE revisao_moto_test;" > /dev/null 2>&1
    psql -h "$PG_SOCK" -p "$PG_PORT" -U postgres -d revisao_moto_test \
        -c "CREATE SCHEMA IF NOT EXISTS auth;
            CREATE TABLE IF NOT EXISTS auth.users(id UUID PRIMARY KEY DEFAULT gen_random_uuid());
            CREATE ROLE authenticated;" > /dev/null 2>&1

    FALHOU_SQL=0
    for sql in sql/001_schema.sql sql/002_seed_royal_enfield.sql \
               sql/003_fase2_motos_ativo.sql sql/004_fase3_execucao.sql \
               sql/005_fase4_assinaturas_pdf.sql sql/006_fase5_historico.sql \
               sql/007_fase7_especificacoes.sql; do
        if ! psql -h "$PG_SOCK" -p "$PG_PORT" -U postgres -d revisao_moto_test \
             -f "$sql" -v ON_ERROR_STOP=1 > /dev/null 2>&1; then
            fail "Falha ao aplicar $sql"
            FALHOU_SQL=1
            break
        fi
    done

    if [ $FALHOU_SQL -eq 1 ]; then
        RESULTADO="FAIL"
    else
        ok "Base preparada (a 008 eh aplicada pelo proprio teste)"
        step "Rodando tests/test_fase8.py..."
        echo ""
        echo -e "${C_CIANO}--- inicio ---${C_RESET}"
        if PGHOST="$PG_SOCK" PGPORT="$PG_PORT" PGUSER=postgres PGDATABASE=revisao_moto_test \
           python3 tests/test_fase8.py; then
            RESULTADO="OK"
        else
            RESULTADO="FAIL"
        fi
        echo -e "${C_CIANO}--- fim ---${C_RESET}"
    fi
fi

# ---------------------------------------------------------------------
# 6. SUMARIO
# ---------------------------------------------------------------------
cabecalho "SUMARIO FINAL"
echo -e "  ${C_NEG}Projeto:${C_RESET}      $RAIZ"
echo -e "  ${C_NEG}Modo:${C_RESET}         $([ $RODAR_TUDO -eq 1 ] && echo 'todas as fases' || echo 'so Fase 8')"
echo -e "  ${C_NEG}Estrutura:${C_RESET}    $AUSENTES problema(s)"
echo -e "  ${C_NEG}Testes:${C_RESET}       $RESULTADO"
echo ""

if [ "$RESULTADO" = "OK" ]; then
    echo -e "${C_VERDE}${C_NEG}   OK  FASE 8 (P1) VALIDADA COM SUCESSO${C_RESET}"
    echo ""
    echo -e "   ${C_NEG}Como aplicar no Supabase:${C_RESET}"
    echo "   1. SQL Editor > cole sql/008_fase8_p1.sql > Run"
    echo "      Cria: 5 colunas em itens_checklist, 3 em inspecoes_itens,"
    echo "            5 em inspecoes, 3 tabelas novas, 2 funcoes, 3 views."
    echo "      Faz seed de limites em ~400 itens por regex."
    echo ""
    echo -e "   ${C_NEG}Deploy:${C_RESET}"
    echo "   2. git add . && git commit -m 'Fase 8 P1: operacao real' && git push"
    echo "   3. Aguardar ~1 min (GitHub Pages)"
    echo "   4. Limpar SW no celular: DevTools > Application > Unregister + Clear"
    echo ""
    echo -e "   ${C_NEG}Roteiro de teste em campo:${C_RESET}"
    echo "   5. Nova inspecao: preencha o RELATO DO CLIENTE antes de iniciar"
    echo "   6. Num item de medicao (pastilha, corrente, bateria), digite um valor"
    echo "      -> campo deve pintar verde/amarelo/vermelho na hora"
    echo "   7. Toque em '+ Adicionar item fora do checklist' e registre um achado"
    echo "   8. Lance uma peca e uma mao de obra no bloco Orcamento"
    echo "   9. Tente finalizar: deve BLOQUEAR pedindo aprovacao do cliente"
    echo "   10. Colete a assinatura de aprovacao e finalize"
    echo "   11. Confira no PDF: relato, itens adicionais e orcamento com total"
    echo ""
    echo -e "   ${C_AMAR}A previsao de troca so aparece a partir da SEGUNDA${C_RESET}"
    echo -e "   ${C_AMAR}medicao do mesmo item na mesma moto.${C_RESET}"
    exit 0
elif [ "$RESULTADO" = "SKIP" ]; then
    echo -e "${C_AMAR}${C_NEG}   Setup OK, testes nao executados${C_RESET}"
    exit 0
else
    echo -e "${C_VERM}${C_NEG}   TESTES FALHARAM${C_RESET}"
    exit 1
fi

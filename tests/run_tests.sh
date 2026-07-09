#!/bin/bash
# =====================================================================
# REVISAO-MOTO :: Runner de testes da Fase 0
# =====================================================================
# Sobe um Postgres local efemero, executa a suite, derruba o servidor.
# Requer: postgresql, python3, node instalados.
#
# Uso:  ./tests/run_tests.sh
# =====================================================================

set -e

# Detecta diretorio raiz
RAIZ="$(cd "$(dirname "$0")/.." && pwd)"
cd "$RAIZ"

# Config Postgres efemero
PG_BIN=$(ls -d /usr/lib/postgresql/*/bin 2>/dev/null | tail -1)
if [ -z "$PG_BIN" ]; then
    echo "ERRO: PostgreSQL nao encontrado. Instale com:"
    echo "  sudo apt-get install postgresql"
    exit 1
fi

PG_BASE=$(mktemp -d -t revmoto_pg.XXXXXX)
PG_DATA="$PG_BASE/data"
PG_PORT=${PG_PORT:-5433}
PG_LOG="$PG_BASE/server.log"
PG_USER=$(whoami)
PG_SOCK="$PG_BASE/sock"
mkdir -p "$PG_SOCK"

cleanup() {
    if [ -d "$PG_DATA" ] && [ -f "$PG_DATA/postmaster.pid" ]; then
        "$PG_BIN/pg_ctl" -D "$PG_DATA" stop -m fast > /dev/null 2>&1 || true
    fi
    rm -rf "$PG_BASE"
}
trap cleanup EXIT

echo "=========================================="
echo "  REVISAO-MOTO :: Run de testes"
echo "=========================================="
echo "  Raiz:    $RAIZ"
echo "  PG bin:  $PG_BIN"
echo "  PG base: $PG_BASE (efemero)"
echo "  PG port: $PG_PORT"
echo ""

# 1. Inicializa cluster
echo "[1/3] Inicializando Postgres..."
"$PG_BIN/initdb" -D "$PG_DATA" -U postgres --auth=trust --no-locale --encoding=UTF8 > /dev/null 2>&1

# 2. Sobe servidor
echo "[2/3] Subindo servidor..."
"$PG_BIN/pg_ctl" -D "$PG_DATA" -l "$PG_LOG" -o "-p $PG_PORT -k $PG_SOCK" start > /dev/null 2>&1
sleep 2

# Verifica se subiu
if ! psql -h "$PG_SOCK" -p "$PG_PORT" -U postgres -c "SELECT 1" > /dev/null 2>&1; then
    echo "ERRO: Servidor nao subiu. Log:"
    cat "$PG_LOG"
    exit 1
fi

# 3. Roda testes
echo "[3/3] Executando suites..."
echo ""

# Fase 0
PGHOST="$PG_SOCK" PGPORT="$PG_PORT" PGUSER=postgres \
    python3 "$RAIZ/tests/test_fase0.py"
EXIT_F0=$?

echo ""
echo "----------------------------------------"
echo ""

# Fase 1 (modo local, reusa o banco populado pela Fase 0)
PGHOST="$PG_SOCK" PGPORT="$PG_PORT" PGUSER=postgres PGDATABASE=revisao_moto_test \
    python3 "$RAIZ/tests/test_fase1.py" --local
EXIT_F1=$?

echo ""
echo "----------------------------------------"
echo ""

# Fase 2 (CRUD de motos - reusa banco)
PGHOST="$PG_SOCK" PGPORT="$PG_PORT" PGUSER=postgres PGDATABASE=revisao_moto_test \
    python3 "$RAIZ/tests/test_fase2.py"
EXIT_F2=$?

echo ""
echo "----------------------------------------"
echo ""

# Fase 3 (Execucao do checklist - reusa banco)
PGHOST="$PG_SOCK" PGPORT="$PG_PORT" PGUSER=postgres PGDATABASE=revisao_moto_test \
    python3 "$RAIZ/tests/test_fase3.py"
EXIT_F3=$?

EXIT_CODE=$(( EXIT_F0 + EXIT_F1 + EXIT_F2 + EXIT_F3 ))

echo ""
if [ $EXIT_CODE -eq 0 ]; then
    echo "=========================================="
    echo "  TODOS OS TESTES PASSARAM (Fase 0 + 1 + 2 + 3)"
    echo "=========================================="
else
    echo "=========================================="
    echo "  ALGUNS TESTES FALHARAM"
    echo "  Fase 0 exit: $EXIT_F0"
    echo "  Fase 1 exit: $EXIT_F1"
    echo "  Fase 2 exit: $EXIT_F2"
    echo "  Fase 3 exit: $EXIT_F3"
    echo "=========================================="
fi

exit $EXIT_CODE

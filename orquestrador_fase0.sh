#!/usr/bin/env bash
# =====================================================================
# REVISAO-MOTO :: Orquestrador da Fase 0 - Setup
# =====================================================================
# Automatiza o setup completo da Fase 0:
#   1. Verifica WSL + sudo
#   2. Instala dependencias (postgresql, python3, nodejs, unzip)
#   3. Localiza o projeto
#   4. Valida estrutura de pastas e arquivos-chave
#   5. Executa a suite de testes (Postgres efemero)
#   6. Reporta status final
#
# Idempotente: pode rodar quantas vezes quiser sem efeito colateral.
#
# Uso:
#   ./orquestrador_fase0.sh                  # execucao normal
#   ./orquestrador_fase0.sh --skip-install   # pula apt install
#   ./orquestrador_fase0.sh --project-dir X  # aponta projeto manual
#   ./orquestrador_fase0.sh --help
#
# Requer: WSL Ubuntu com acesso a sudo.
# =====================================================================

set -uo pipefail

# ---------------------------------------------------------------------
# CORES E HELPERS
# ---------------------------------------------------------------------
if [ -t 1 ]; then
    C_VERDE="\033[92m"
    C_VERM="\033[91m"
    C_AMAR="\033[93m"
    C_AZUL="\033[94m"
    C_CIANO="\033[96m"
    C_NEG="\033[1m"
    C_RESET="\033[0m"
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
    echo -e "${C_VERM}${C_NEG}Setup interrompido.${C_RESET} Corrija o problema acima e rode de novo."
    exit 1
}

# ---------------------------------------------------------------------
# ARGUMENTOS
# ---------------------------------------------------------------------
SKIP_INSTALL=0
PROJECT_DIR=""
SKIP_TESTS=0

mostrar_ajuda() {
    cat <<HELP
Orquestrador da Fase 0 - Setup do revisao-moto

USO:
  $0 [OPCOES]

OPCOES:
  --skip-install         Pula a instalacao via apt
  --skip-tests           Nao roda os testes (so setup + validacao de estrutura)
  --project-dir CAMINHO  Usa este caminho como raiz do projeto
                         (default: procura em locais comuns)
  --help, -h             Mostra esta ajuda

EXEMPLOS:
  # Execucao completa (padrao)
  ./orquestrador_fase0.sh

  # Ja tem pacotes instalados, so quer validar e rodar testes
  ./orquestrador_fase0.sh --skip-install

  # Projeto em local nao-padrao
  ./orquestrador_fase0.sh --project-dir ~/meus-projetos/revisao-moto
HELP
}

while [ $# -gt 0 ]; do
    case "$1" in
        --skip-install) SKIP_INSTALL=1; shift ;;
        --skip-tests)   SKIP_TESTS=1; shift ;;
        --project-dir)  PROJECT_DIR="${2:-}"; shift 2 ;;
        --help|-h)      mostrar_ajuda; exit 0 ;;
        *) echo "Argumento desconhecido: $1"; mostrar_ajuda; exit 1 ;;
    esac
done

# ---------------------------------------------------------------------
# BANNER INICIAL
# ---------------------------------------------------------------------
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
echo -e "${C_NEG}         Orquestrador da Fase 0 - Setup${C_RESET}"
echo ""

# ---------------------------------------------------------------------
# 1. VERIFICACOES DE AMBIENTE
# ---------------------------------------------------------------------
cabecalho "1. Verificacoes de ambiente"

# Detecta WSL
if grep -qi microsoft /proc/version 2>/dev/null; then
    ok "Ambiente WSL detectado ($(lsb_release -ds 2>/dev/null || echo Ubuntu))"
else
    warn "Nao parece ser WSL. Continuando mesmo assim (Linux nativo tambem funciona)."
fi

# Detecta sudo (obrigatorio so se for instalar)
if command -v sudo >/dev/null 2>&1; then
    ok "sudo disponivel"
else
    if [ $SKIP_INSTALL -eq 1 ]; then
        warn "sudo nao encontrado (nao-fatal com --skip-install)"
    else
        erro_fatal "sudo nao encontrado. Instale: apt install sudo (ou use --skip-install)"
    fi
fi

# Detecta shell interativo
if [ -t 0 ]; then
    ok "Shell interativo (pode pedir senha do sudo)"
else
    warn "Shell nao-interativo - certifique que sudo nao pedira senha (sudo -n true?)"
fi

# ---------------------------------------------------------------------
# 2. INSTALACAO DE DEPENDENCIAS
# ---------------------------------------------------------------------
cabecalho "2. Dependencias do sistema"

if [ $SKIP_INSTALL -eq 1 ]; then
    warn "--skip-install passado - pulando apt install"
else
    step "Executando: sudo apt update"
    if sudo apt update -qq 2>&1 | tail -3; then
        ok "apt update completo"
    else
        warn "apt update teve avisos - continuando"
    fi

    step "Instalando pacotes: postgresql postgresql-contrib python3 nodejs unzip"
    if sudo apt install -y postgresql postgresql-contrib python3 nodejs unzip 2>&1 | tail -3; then
        ok "Pacotes instalados / atualizados"
    else
        erro_fatal "Falha ao instalar pacotes. Rode manualmente e tente de novo."
    fi
fi

# Verifica cada dependencia
verificar_cmd() {
    local cmd="$1"
    local pacote="${2:-$1}"
    if command -v "$cmd" >/dev/null 2>&1; then
        local v
        case "$cmd" in
            unzip)   v=$(unzip -v 2>&1 | head -1) ;;
            *)       v=$("$cmd" --version 2>&1 | head -1) ;;
        esac
        ok "$cmd: $v"
        return 0
    else
        if [ $SKIP_TESTS -eq 1 ] || [ $SKIP_INSTALL -eq 1 ]; then
            warn "$cmd nao encontrado (pacote: $pacote)"
        else
            fail "$cmd nao encontrado (pacote: $pacote)"
        fi
        return 1
    fi
}

step "Verificando ferramentas disponiveis:"
FALTA=0
verificar_cmd psql postgresql            || FALTA=$((FALTA+1))
verificar_cmd python3                    || FALTA=$((FALTA+1))
verificar_cmd node nodejs                || FALTA=$((FALTA+1))
verificar_cmd unzip                      || FALTA=$((FALTA+1))
verificar_cmd git                        || FALTA=$((FALTA+1))

# Fatal so se for rodar os testes (que dependem de psql/python/node)
if [ $FALTA -gt 0 ]; then
    if [ $SKIP_TESTS -eq 1 ]; then
        warn "$FALTA ferramenta(s) ausente(s), mas --skip-tests passado - seguindo"
    else
        erro_fatal "$FALTA ferramenta(s) essencial(is) ausente(s). Instale-as ou use --skip-tests."
    fi
fi

# Verifica binarios do postgres (initdb, pg_ctl)
PG_BIN=$(ls -d /usr/lib/postgresql/*/bin 2>/dev/null | tail -1)
if [ -n "$PG_BIN" ] && [ -x "$PG_BIN/initdb" ] && [ -x "$PG_BIN/pg_ctl" ]; then
    ok "Binarios do Postgres em $PG_BIN"
else
    if [ $SKIP_TESTS -eq 1 ]; then
        warn "initdb/pg_ctl nao encontrados (nao-fatal com --skip-tests)"
    else
        erro_fatal "Nao achei initdb/pg_ctl. Instale postgresql-contrib."
    fi
fi

# ---------------------------------------------------------------------
# 3. LOCALIZAR O PROJETO
# ---------------------------------------------------------------------
cabecalho "3. Localizando projeto"

# Locais candidatos (em ordem de preferencia)
CANDIDATOS=(
    "$PROJECT_DIR"
    "$PWD"
    "/mnt/c/Users/mceza/Dropbox/PROGRAMACAO/JAVASCRIPT/APLICATIVOS/revisao-moto"
    "$HOME/revisao-moto"
)

RAIZ=""
for c in "${CANDIDATOS[@]}"; do
    if [ -z "$c" ]; then continue; fi
    if [ -f "$c/sql/001_schema.sql" ] && [ -f "$c/tests/run_tests.sh" ]; then
        RAIZ="$c"
        break
    fi
    # Talvez esteja um nivel acima
    if [ -f "$c/revisao-moto/sql/001_schema.sql" ]; then
        RAIZ="$c/revisao-moto"
        break
    fi
done

if [ -z "$RAIZ" ]; then
    fail "Nao consegui localizar o projeto automaticamente."
    echo ""
    echo "  Tentei os seguintes locais:"
    for c in "${CANDIDATOS[@]}"; do
        [ -n "$c" ] && echo "    - $c"
    done
    echo ""
    echo -e "  ${C_AMAR}Solucao:${C_RESET} rode com --project-dir CAMINHO"
    echo "  Exemplo: $0 --project-dir /caminho/para/revisao-moto"
    exit 1
fi

RAIZ="$(cd "$RAIZ" && pwd)"
ok "Projeto: $RAIZ"

cd "$RAIZ"

# ---------------------------------------------------------------------
# 4. VALIDAR ESTRUTURA DE ARQUIVOS
# ---------------------------------------------------------------------
cabecalho "4. Estrutura do projeto"

verificar_arquivo() {
    local caminho="$1"
    local descricao="$2"
    if [ -f "$caminho" ] || [ -d "$caminho" ]; then
        ok "$descricao"
        return 0
    else
        fail "Ausente: $descricao ($caminho)"
        return 1
    fi
}

step "Arquivos esperados da Fase 0:"
AUSENTES=0
verificar_arquivo "index.html"                              "index.html (login + dashboard)"      || AUSENTES=$((AUSENTES+1))
verificar_arquivo "manifest.json"                           "manifest.json (PWA)"                 || AUSENTES=$((AUSENTES+1))
verificar_arquivo "service-worker.js"                       "service-worker.js"                   || AUSENTES=$((AUSENTES+1))
verificar_arquivo "README.md"                               "README.md"                           || AUSENTES=$((AUSENTES+1))
verificar_arquivo "src/supabase-client.js"                  "src/supabase-client.js"              || AUSENTES=$((AUSENTES+1))
verificar_arquivo "src/auth.js"                             "src/auth.js"                         || AUSENTES=$((AUSENTES+1))
verificar_arquivo "css/styles.css"                          "css/styles.css"                      || AUSENTES=$((AUSENTES+1))
verificar_arquivo "sql/001_schema.sql"                      "sql/001_schema.sql (schema)"         || AUSENTES=$((AUSENTES+1))
verificar_arquivo "sql/002_seed_royal_enfield.sql"          "sql/002_seed_royal_enfield.sql"      || AUSENTES=$((AUSENTES+1))
verificar_arquivo "assets"                                  "pasta assets/"                       || AUSENTES=$((AUSENTES+1))
verificar_arquivo "tests/test_fase0.py"                     "tests/test_fase0.py"                 || AUSENTES=$((AUSENTES+1))
verificar_arquivo "tests/run_tests.sh"                      "tests/run_tests.sh"                  || AUSENTES=$((AUSENTES+1))

if [ $AUSENTES -gt 0 ]; then
    erro_fatal "$AUSENTES arquivo(s) essencial(is) ausente(s). Extraia o zip da Fase 0 na pasta correta."
fi

# Icones (opcionais mas recomendados)
step "Icones PWA:"
if [ -f "assets/icon-192.png" ]; then ok "assets/icon-192.png"; else warn "assets/icon-192.png ausente (nao-fatal)"; fi
if [ -f "assets/icon-512.png" ]; then ok "assets/icon-512.png"; else warn "assets/icon-512.png ausente (nao-fatal)"; fi

# Config opcionais
step "Config local (opcionais):"
if [ -f ".env" ]; then
    ok ".env presente (credenciais Supabase)"
    if grep -q "SEU_PROJETO\|SUA_ANON_KEY" .env 2>/dev/null; then
        warn "  .env parece ter placeholders - Fase 1 vai exigir credenciais reais"
    fi
else
    warn ".env ausente - crie a partir de .env.exemplo antes da Fase 1"
fi

if [ -f "usuarios.json" ]; then
    ok "usuarios.json presente"
else
    warn "usuarios.json ausente - crie a partir de usuarios.json.exemplo antes da Fase 1"
fi

# ---------------------------------------------------------------------
# 5. GIT (opcional, so avisa)
# ---------------------------------------------------------------------
cabecalho "5. Git (opcional)"

if [ -d ".git" ]; then
    ok "Repositorio Git inicializado"
    if git remote -v 2>/dev/null | grep -q origin; then
        REMOTE=$(git remote get-url origin 2>/dev/null || echo "")
        ok "Remote origin: $REMOTE"
    else
        warn "Sem remote origin configurado (deploy no GitHub Pages nao funcionara)"
    fi

    if git status --porcelain 2>/dev/null | grep -q .; then
        info "Ha mudancas nao commitadas (rode: git status para detalhes)"
    else
        ok "Working tree limpo"
    fi
else
    warn "Nao eh um repo Git. Sem problema para desenvolvimento local; deploy exige Git+GitHub."
fi

# ---------------------------------------------------------------------
# 6. EXECUCAO DOS TESTES
# ---------------------------------------------------------------------
if [ $SKIP_TESTS -eq 1 ]; then
    cabecalho "6. Testes"
    warn "--skip-tests passado - pulando execucao dos testes"
    RESULTADO_TESTES="SKIP"
else
    cabecalho "6. Executando suite de testes"
    chmod +x tests/run_tests.sh 2>/dev/null || true

    step "Rodando: ./tests/run_tests.sh"
    echo ""
    echo -e "${C_CIANO}--- inicio da saida dos testes ---${C_RESET}"
    if ./tests/run_tests.sh; then
        RESULTADO_TESTES="OK"
        echo -e "${C_CIANO}--- fim da saida dos testes ---${C_RESET}"
    else
        EXIT_CODE=$?
        RESULTADO_TESTES="FAIL (exit $EXIT_CODE)"
        echo -e "${C_CIANO}--- fim da saida dos testes ---${C_RESET}"
    fi
fi

# ---------------------------------------------------------------------
# 7. SUMARIO FINAL
# ---------------------------------------------------------------------
cabecalho "SUMARIO FINAL"

versao_ou_ausente() {
    if command -v "$1" >/dev/null 2>&1; then
        "$@" 2>&1 | head -1
    else
        echo "(nao instalado)"
    fi
}

echo -e "  ${C_NEG}Projeto:${C_RESET}         $RAIZ"
echo -e "  ${C_NEG}Ambiente:${C_RESET}        $(uname -srm)"
echo -e "  ${C_NEG}Postgres:${C_RESET}        $(versao_ou_ausente psql --version)"
echo -e "  ${C_NEG}Python:${C_RESET}          $(versao_ou_ausente python3 --version)"
echo -e "  ${C_NEG}Node:${C_RESET}            $(versao_ou_ausente node --version)"
echo -e "  ${C_NEG}Estrutura:${C_RESET}       $AUSENTES arquivo(s) ausente(s)"
echo -e "  ${C_NEG}Testes:${C_RESET}          $RESULTADO_TESTES"
echo ""

if [ "$RESULTADO_TESTES" = "OK" ]; then
    echo -e "${C_VERDE}${C_NEG}   ✔  FASE 0 VALIDADA COM SUCESSO${C_RESET}"
    echo ""
    echo -e "   ${C_NEG}Proximos passos:${C_RESET}"
    echo "   1. Aplicar sql/001_schema.sql + sql/002_seed_royal_enfield.sql no Supabase"
    echo "   2. Configurar .env com credenciais reais (Fase 1)"
    echo "   3. Rodar scripts/setup_fase1.py para criar bucket + usuarios"
    echo "   4. Continuar com o roadmap: Fases 1 -> 2 -> 3 -> 4"
    echo ""
    exit 0
elif [ "$RESULTADO_TESTES" = "SKIP" ]; then
    echo -e "${C_AMAR}${C_NEG}   ⚠  SETUP CONCLUIDO SEM RODAR TESTES${C_RESET}"
    echo ""
    echo "   Para validar a Fase 0, rode: ./tests/run_tests.sh"
    echo ""
    exit 0
else
    echo -e "${C_VERM}${C_NEG}   ✗  TESTES FALHARAM${C_RESET}"
    echo ""
    echo "   Revise a saida acima. Falhas comuns:"
    echo "   - Postgres nao subiu: veja /tmp/revmoto_pg.*/server.log"
    echo "   - node --check falhando: sintaxe JS quebrada em algum arquivo"
    echo "   - Arquivos faltando: extraia o zip novamente"
    echo ""
    exit 1
fi

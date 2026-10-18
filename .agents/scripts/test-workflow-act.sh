#!/bin/bash
set -e

export PATH="/home/linuxbrew/.linuxbrew/bin:$HOME/.local/bin:$PATH"

# Colors
CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${CYAN}=============================================${NC}"
echo -e "${CYAN} Pruebas Locales de Workflows con 'act'      ${NC}"
echo -e "${CYAN}=============================================${NC}"

EVENT_TYPE="pr"
DRY_RUN=false
LIST_ONLY=false
JOB_NAME=""
WORKFLOW_FILE=""
CONCURRENT_JOBS=""
EXTRA_INPUTS=()

while [[ $# -gt 0 ]]; do
    case "$1" in
        --list|-l)
            LIST_ONLY=true
            shift
            ;;
        --dry-run|-n)
            DRY_RUN=true
            shift
            ;;
        --event|-e)
            EVENT_TYPE="$2"
            shift 2
            ;;
        --push-only)
            EVENT_TYPE="feature"
            [ -z "$WORKFLOW_FILE" ] && WORKFLOW_FILE=".github/workflows/ci.yml"
            shift
            ;;
        --pr)
            EVENT_TYPE="pr"
            [ -z "$WORKFLOW_FILE" ] && WORKFLOW_FILE=".github/workflows/ci.yml"
            shift
            ;;
        --merge)
            EVENT_TYPE="dev"
            [ -z "$WORKFLOW_FILE" ] && WORKFLOW_FILE=".github/workflows/ci.yml"
            shift
            ;;
        -W|--workflow)
            WORKFLOW_FILE="$2"
            shift 2
            ;;
        --docs-only)
            WORKFLOW_FILE=".github/workflows/docs.yml"
            JOB_NAME="build"
            shift
            ;;
        --concurrent-jobs|--concurrency)
            CONCURRENT_JOBS="$2"
            shift 2
            ;;
        --concurrent-jobs=*|--concurrency=*)
            CONCURRENT_JOBS="${1#*=}"
            shift
            ;;
        --jobs|-j)
            # Determina si el siguiente parámetro es un número (concurrencia) o el nombre de un job
            if [[ -n "${2:-}" && "$2" =~ ^[0-9]+$ ]]; then
                CONCURRENT_JOBS="$2"
                shift 2
            else
                JOB_NAME="$2"
                shift 2
            fi
            ;;
        --jobs=*|-j=*)
            val="${1#*=}"
            if [[ "$val" =~ ^[0-9]+$ ]]; then
                CONCURRENT_JOBS="$val"
            else
                JOB_NAME="$val"
            fi
            shift
            ;;
        --job)
            JOB_NAME="$2"
            shift 2
            ;;
        --input)
            EXTRA_INPUTS+=("--input" "$2")
            shift 2
            ;;
        --input=*)
            EXTRA_INPUTS+=("--input" "${1#*=}")
            shift
            ;;
        # Banderas directas por Job ID
        --build|-b)
            JOB_NAME="build"
            WORKFLOW_FILE=".github/workflows/ci.yml"
            shift
            ;;
        --test)
            JOB_NAME="test"
            WORKFLOW_FILE=".github/workflows/ci.yml"
            shift
            ;;
        --format-check)
            JOB_NAME="format-check"
            WORKFLOW_FILE=".github/workflows/ci.yml"
            shift
            ;;
        --cppcheck)
            JOB_NAME="cppcheck"
            WORKFLOW_FILE=".github/workflows/ci.yml"
            shift
            ;;
        --clang-tidy)
            JOB_NAME="clang-tidy"
            WORKFLOW_FILE=".github/workflows/ci.yml"
            shift
            ;;
        --sanitizers|--test-sanitizers)
            JOB_NAME="test-sanitizers"
            WORKFLOW_FILE=".github/workflows/ci.yml"
            shift
            ;;
        --sonar|-s)
            JOB_NAME="sonar"
            WORKFLOW_FILE=".github/workflows/ci.yml"
            shift
            ;;
        --windows|--test-windows)
            JOB_NAME="test-windows"
            WORKFLOW_FILE=".github/workflows/ci.yml"
            shift
            ;;
        --docker-dry-run)
            JOB_NAME="docker-dry-run"
            WORKFLOW_FILE=".github/workflows/ci.yml"
            shift
            ;;
        --codeql|--analyze)
            JOB_NAME="analyze"
            WORKFLOW_FILE=".github/workflows/codeql.yml"
            shift
            ;;
        --docs)
            JOB_NAME="build"
            WORKFLOW_FILE=".github/workflows/docs.yml"
            shift
            ;;
        --deploy)
            JOB_NAME="deploy"
            WORKFLOW_FILE=".github/workflows/docs.yml"
            shift
            ;;
        --check-changes)
            JOB_NAME="check-changes"
            WORKFLOW_FILE=".github/workflows/cd.yml"
            shift
            ;;
        --publish-images)
            JOB_NAME="publish-images"
            WORKFLOW_FILE=".github/workflows/cd.yml"
            shift
            ;;
        --package-distribution)
            JOB_NAME="package-distribution"
            WORKFLOW_FILE=".github/workflows/cd.yml"
            shift
            ;;
        --create-release)
            JOB_NAME="create-release"
            WORKFLOW_FILE=".github/workflows/cd.yml"
            shift
            ;;
        *)
            echo -e "${YELLOW}Opción no reconocida: $1${NC}"
            shift
            ;;
    esac
done

if [ "$JOB_NAME" = "sonar" ] && [ "$DRY_RUN" = false ]; then
    echo -e "\n${YELLOW}[sonar] Ejecutando análisis de SonarQube local y actualizando reporte...${NC}"
    ./scripts/run-sonar-local.sh
    ./scripts/get-sonar-report.sh
    exit 0
fi

if ! command -v act >/dev/null 2>&1; then
    echo -e "${RED}[ERROR] El comando 'act' no está instalado en el sistema.${NC}"
    echo -e "Instálalo vía Homebrew: brew install act (o descarga nektos/act)."
    exit 1
fi

if [ -z "$DOCKER_HOST" ] && [ ! -S "/var/run/docker.sock" ]; then
    if [ -S "$HOME/.docker/desktop/docker.sock" ]; then
        export DOCKER_HOST="unix://$HOME/.docker/desktop/docker.sock"
    elif [ -S "/run/user/$(id -u)/docker.sock" ]; then
        export DOCKER_HOST="unix:///run/user/$(id -u)/docker.sock"
    fi
fi

if ! docker info >/dev/null 2>&1; then
    echo -e "${RED}[ERROR] El servicio de Docker no está en ejecución.${NC}"
    echo -e "Asegúrate de iniciar el daemon de Docker antes de usar 'act'."
    exit 1
fi

if [ "$LIST_ONLY" = true ]; then
    echo -e "\n${YELLOW}[act] Listando flujos de trabajo y trabajos disponibles...${NC}"
    act -l
    exit 0
fi

CMD_ARGS=()

if [ "$DRY_RUN" = true ]; then
    CMD_ARGS+=("-n")
fi

if [ -n "$CONCURRENT_JOBS" ]; then
    CMD_ARGS+=("--concurrent-jobs" "$CONCURRENT_JOBS")
    echo -e "${CYAN}[act] Concurrencia configurada a: ${CONCURRENT_JOBS} jobs simultáneos${NC}"
fi

if [ ${#EXTRA_INPUTS[@]} -gt 0 ]; then
    CMD_ARGS+=("${EXTRA_INPUTS[@]}")
fi

# Servidor local de artefactos para compartir entregables entre jobs (build -> test -> sonar)
ARTIFACT_DIR="/tmp/act-artifacts"
mkdir -p "$ARTIFACT_DIR"
CMD_ARGS+=("--artifact-server-path" "$ARTIFACT_DIR")

if [ "$JOB_NAME" = "codeql" ] || [ "$JOB_NAME" = "analyze" ]; then
    JOB_NAME="analyze"
    WORKFLOW_FILE=".github/workflows/codeql.yml"
    if command -v gh >/dev/null 2>&1; then
        TOKEN="$(gh auth token 2>/dev/null || true)"
        if [ -n "$TOKEN" ]; then
            CMD_ARGS+=("--secret" "GITHUB_TOKEN=$TOKEN")
        fi
    fi
fi

if [ -n "$WORKFLOW_FILE" ]; then
    CMD_ARGS+=("-W" "$WORKFLOW_FILE")
fi

if [ -n "$JOB_NAME" ]; then
    CMD_ARGS+=("-j" "$JOB_NAME")
fi

case "$EVENT_TYPE" in
    feature|push-only)
        EVENT_FILE=".github/events/push_feature.json"
        EVENT_NAME="push"
        echo -e "\n${YELLOW}[act] Simulando push de código sin PR (solo test)...${NC}"
        ;;
    pr|pull_request)
        EVENT_FILE=".github/events/pull_request.json"
        EVENT_NAME="pull_request"
        echo -e "\n${YELLOW}[act] Simulando evento Pull Request (test + sonar)...${NC}"
        ;;
    dev|development|merge)
        EVENT_FILE=".github/events/push_development.json"
        EVENT_NAME="push"
        echo -e "\n${YELLOW}[act] Simulando merge a 'development' (suite completa sin windows/terraform)...${NC}"
        ;;
    master|main)
        EVENT_FILE=".github/events/push_master.json"
        EVENT_NAME="push"
        echo -e "\n${YELLOW}[act] Simulando merge/push a 'master'...${NC}"
        ;;
    *)
        echo -e "${RED}[ERROR] Evento '$EVENT_TYPE' no reconocido. Opciones válidas: feature, pr, dev, master, merge${NC}"
        exit 1
        ;;
esac

LOG_DIR=".logs/act/$(date +%Y%m%d_%H%M%S)"
mkdir -p "$LOG_DIR" ".logs/act"
rm -f ".logs/act/latest"
ln -snf "$(basename "$LOG_DIR")" ".logs/act/latest"

ACT_CMD=(act "$EVENT_NAME" "${CMD_ARGS[@]}")
if [ -f "$EVENT_FILE" ]; then
    ACT_CMD=(act "$EVENT_NAME" -e "$EVENT_FILE" "${CMD_ARGS[@]}")
fi

set +e
"${ACT_CMD[@]}" 2>&1 | tee "${LOG_DIR}/act_run.log"
ACT_EXIT=${PIPESTATUS[0]}
set -e

if command -v python3 >/dev/null 2>&1 && [ -f "scripts/analyze-logs.py" ]; then
    python3 scripts/analyze-logs.py --log-dir "$LOG_DIR" --output-markdown "docs/reports/verify_log_analysis.md"
fi

if [ "$ACT_EXIT" -ne 0 ]; then
    echo -e "\n${RED}[ERROR] Ejecución de 'act' falló con código $ACT_EXIT.${NC}"
    exit "$ACT_EXIT"
fi

echo -e "\n${GREEN}[OK] Ejecución de 'act' completada exitosamente.${NC}"

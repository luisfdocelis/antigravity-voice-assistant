#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 2 ]]; then
  echo "Uso: ./start-branch.sh <tipo> <nombre> [--skip-pull]"
  echo "Uso: ./start-branch.sh <tipo> <nombre> [--skip-pull] [--from <rama_base>]"
  echo "Tipos: feature|codigo|documentacion|configuracion|feat|fix|doc|chore|test|refactor|release|patch|hotfix|perf|ci|build|sec|deps|revert"
  exit 1
fi

TYPE="$1"
NAME="$2"
SKIP_PULL="false"
FROM_BRANCH=""

if [[ "${3:-}" == "--skip-pull" ]]; then
  SKIP_PULL="true"
fi
shift 2
while [[ $# -gt 0 ]]; do
  case "$1" in
    --skip-pull)
      SKIP_PULL="true"
      shift
      ;;
    --from)
      FROM_BRANCH="${2:-}"
      shift 2
      ;;
    *)
      shift
      ;;
  esac
done

resolve_prefix() {
  case "$1" in
    feature) echo "feat" ;;
    codigo) echo "fix" ;;
    documentacion) echo "doc" ;;
    configuracion) echo "chore" ;;
    feat|fix|doc|chore|test|refactor|release|patch|hotfix|perf|ci|build|sec|deps|revert) echo "$1" ;;
    *)
      echo "Tipo no valido: $1" >&2
      exit 1
      ;;
  esac
}

to_slug() {
  local s="$1"
  s="$(echo "$s" | tr '[:upper:]' '[:lower:]')"
  s="$(echo "$s" | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//; s/-{2,}/-/g')"

  if [[ -z "$s" ]]; then
    echo "El nombre no contiene caracteres validos para un branch." >&2
    exit 1
  fi

  echo "$s"
}

if [[ ! -d .git ]]; then
  echo "Este comando debe ejecutarse en la raiz del repositorio." >&2
  exit 1
fi

if [[ ! -w .git ]]; then
  echo "Error: El directorio .git está en modo solo lectura (Read-only file system)." >&2
  echo "Causa: El comando se está ejecutando dentro de un entorno sandbox (ej. agente de IA sin BypassSandbox) o en un contenedor/montaje sin permisos de escritura sobre .git." >&2
  echo "Solución: Ejecuta el script fuera del sandbox (activando BypassSandbox: true en agentes) o directamente en tu terminal del sistema anfitrión." >&2
  exit 1
fi

if [[ -n "$(git status --porcelain)" ]]; then
  echo "Hay cambios sin commit. Haz commit o stash antes de crear una nueva rama automatica." >&2
  exit 1
fi

PREFIX="$(resolve_prefix "$TYPE")"
SLUG="$(to_slug "$NAME")"
TARGET_BRANCH="$PREFIX/$SLUG"
CURRENT_BRANCH="$(git rev-parse --abbrev-ref HEAD)"

# Detección contextual de la rama base:
BASE_BRANCH="development"

if [[ -n "$FROM_BRANCH" ]]; then
  BASE_BRANCH="$FROM_BRANCH"
  echo "[CONTINUIDAD] Usando rama base explícita: '$BASE_BRANCH'."
elif [[ ("$PREFIX" == "feat" || "$PREFIX" == "fix") && "$CURRENT_BRANCH" == "doc/$SLUG" ]]; then
  BASE_BRANCH="$CURRENT_BRANCH"
  echo "[CONTINUIDAD] Rama documental activa '$CURRENT_BRANCH' detectada."
  echo "              Desprendiendo rama de desarrollo '$TARGET_BRANCH' a partir de ella."
elif [[ ("$PREFIX" == "feat" || "$PREFIX" == "fix") && -n "$(git branch --list "doc/$SLUG")" ]]; then
  BASE_BRANCH="doc/$SLUG"
  echo "[CONTINUIDAD] Rama documental previa 'doc/$SLUG' detectada en el repositorio."
  echo "              Desprendiendo rama de desarrollo '$TARGET_BRANCH' a partir de ella."
fi

if [[ "$CURRENT_BRANCH" != "$BASE_BRANCH" ]]; then
  git checkout "$BASE_BRANCH"
fi

if [[ "$BASE_BRANCH" == "development" && "$SKIP_PULL" != "true" ]]; then
  echo "Sincronizando 'development' con origin/development..."
  if ! git pull origin development; then
    echo "Advertencia: Falló 'git pull origin development' (posiblemente sin conexión a internet o remote no disponible)." >&2
    echo "Continuando con la versión local de 'development'..." >&2
  fi
fi

if git show-ref --verify --quiet "refs/heads/$TARGET_BRANCH"; then
  echo "La rama '$TARGET_BRANCH' ya existe. Elige otro nombre." >&2
  exit 1
fi

git checkout -b "$TARGET_BRANCH"

echo "Rama creada: $TARGET_BRANCH (base: $BASE_BRANCH)"

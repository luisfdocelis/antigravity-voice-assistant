#!/usr/bin/env bash
set -euo pipefail

TITLE="${1:-}"
BODY="${2:-PR creado por script de automatizacion}"
BASE="${BASE_BRANCH:-development}"
DRAFT="${DRAFT_PR:-false}"
NO_MERGE="${NO_MERGE:-false}"
SKIP_VERIFY="${SKIP_VERIFY:-false}"
SKIP_REMOTE_CHECKS="${SKIP_REMOTE_CHECKS:-false}"

for arg in "$@"; do
  if [[ "$arg" == "--no-merge" ]]; then
    NO_MERGE="true"
  elif [[ "$arg" == "--skip-verify" ]]; then
    SKIP_VERIFY="true"
  elif [[ "$arg" == "--skip-remote-checks" ]]; then
    SKIP_REMOTE_CHECKS="true"
  fi
done

ensure_gh() {
  if ! command -v gh >/dev/null 2>&1; then
    echo "GitHub CLI (gh) no esta instalado o no esta en PATH." >&2
    exit 1
  fi
}

ensure_valid_branch() {
  local branch
  branch="$(git rev-parse --abbrev-ref HEAD)"
  if [[ "$branch" == "master" || "$branch" == "development" || "$branch" == "main" ]]; then
    echo "No se permite operar PR directo desde '$branch'. Usa una rama dedicada." >&2
    exit 1
  fi
  echo "$branch"
}

get_current_pr_url() {
  gh pr view --json url --jq .url 2>/dev/null || true
}

select_merge_method() {
  echo
  echo "Selecciona estrategia de merge:"
  echo "1) Squash"
  echo "2) Rebase"
  echo "3) Merge commit"
  echo "4) Cancelar"
  read -r -p "Opcion: " choice
  case "$choice" in
    1) echo "--squash" ;;
    2) echo "--rebase" ;;
    3) echo "--merge" ;;
    *) echo "" ;;
  esac
}

ensure_gh
BRANCH="$(ensure_valid_branch)"
PR_URL="$(get_current_pr_url)"

if [[ -z "$PR_URL" ]]; then
  if [[ -z "$TITLE" ]]; then
    read -r -p "Titulo del PR: " TITLE
  fi

  if [[ -z "$TITLE" ]]; then
    echo "El titulo del PR es obligatorio." >&2
    exit 1
  fi

  if [[ "$SKIP_VERIFY" != "true" ]]; then
    echo
    echo "========================================================="
    echo " Ejecutando Verificación Previa Local (Quality Gates)   "
    echo "========================================================="
    ./.agents/scripts/verify.sh
  fi

  echo
  echo "========================================================="
  echo " Paso 1: Push de la rama a remoto (sin PR aún)           "
  echo "========================================================="
  git push -u origin "$BRANCH"

  if [[ "$SKIP_REMOTE_CHECKS" != "true" ]]; then
    echo
    echo "========================================================="
    echo " Paso 2: Verificando ejecución remota en rama '$BRANCH'  "
    echo "========================================================="
    sleep 5
    RUN_ID="$(gh run list --branch "$BRANCH" --limit 1 --json databaseId --jq '.[0].databaseId' 2>/dev/null || true)"
    if [[ -n "$RUN_ID" ]]; then
      echo "Monitoreando corrida remota #$RUN_ID..."
      if ! gh run watch "$RUN_ID"; then
        echo "✖ Fallaron las pruebas en la rama remota. Corrige los errores en local antes de crear el PR." >&2
        exit 1
      fi
      echo "✔ Pruebas en remoto de la rama aprobadas con éxito."
    else
      echo "No se detectó workflow en ejecución para la rama '$BRANCH' o ya concluyó."
    fi
  else
    echo
    echo "========================================================="
    echo " Paso 2: Verificación remota omitida (--skip-remote-checks) "
    echo "========================================================="
  fi

  echo
  echo "========================================================="
  echo " Paso 3: Creación de Pull Request                       "
  echo "========================================================="
  CREATE_ARGS=(pr create --base "$BASE" --head "$BRANCH" --title "$TITLE" --body "$BODY")
  if [[ "$DRAFT" == "true" ]]; then
    CREATE_ARGS+=(--draft)
  fi

  gh "${CREATE_ARGS[@]}"
  PR_URL="$(get_current_pr_url)"
fi

echo "PR activo: $PR_URL"

if [[ "$SKIP_REMOTE_CHECKS" != "true" ]]; then
  echo
  echo "Monitoreando checks del PR..."
  set +e
  CHECKS_OUTPUT="$(gh pr checks --watch 2>&1)"
  CHECKS_EXIT=$?
  set -e
  echo "$CHECKS_OUTPUT"

  if [[ "$NO_MERGE" == "true" ]]; then
    echo
    echo "✔ PR creado y verificado: $PR_URL"
    echo "✔ [NO_MERGE activo]: El PR permanecerá abierto para revisión asíncrona."
    exit 0
  fi

  if [[ $CHECKS_EXIT -ne 0 ]]; then
    if grep -qi "no checks reported" <<< "$CHECKS_OUTPUT"; then
      read -r -p "No hay checks configurados/reportados. Continuar con merge? (y/n): " CONTINUE_WITHOUT_CHECKS
      if [[ ! "$CONTINUE_WITHOUT_CHECKS" =~ ^[Yy]$ ]]; then
        echo "Merge cancelado por ausencia de checks."
        exit 0
      fi
    else
      echo "Checks en estado no exitoso. Extrayendo logs de fallos de GitHub Actions..." >&2
      gh run view --log-failed || true
      exit 1
    fi
  fi
else
  echo
  echo "Monitoreo de checks remotos omitido (--skip-remote-checks activo)."
  if [[ "$NO_MERGE" == "true" ]]; then
    echo
    echo "✔ PR creado: $PR_URL"
    echo "✔ [NO_MERGE activo]: El PR permanecerá abierto para revisión asíncrona."
    exit 0
  fi
fi

MERGE_FLAG="$(select_merge_method)"
if [[ -z "$MERGE_FLAG" ]]; then
  echo "Merge cancelado por usuario."
  exit 0
fi

read -r -p "Eliminar rama remota al finalizar? (la rama local debe eliminarse manualmente) (y/n): " DELETE_BRANCH
MERGE_ARGS=(pr merge "$MERGE_FLAG")
if [[ "$DELETE_BRANCH" =~ ^[Yy]$ ]]; then
  MERGE_ARGS+=(--delete-branch)
fi

gh "${MERGE_ARGS[@]}"
echo "Merge completado con estrategia $MERGE_FLAG"

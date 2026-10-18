#!/usr/bin/env bash
# =============================================================================
# context-builder.sh — CrowKit Minimal Context Builder
# =============================================================================
# Genera el contexto mínimo necesario para un tipo de tarea específico.
# En lugar de cargar todos los skills, selecciona solo los relevantes.
#
# El resultado se imprime a stdout — el agente lo puede leer bajo demanda.
# Esto es especialmente útil para sesiones de subagentes especializados.
#
# Uso:
#   ./context-builder.sh <tipo-de-tarea> [--list] [--dry-run]
#
# Tipos de tarea disponibles:
#   feature      → feature-planner + crow-rest-api-architecture + cpp
#   bugfix       → bug-hunter + code-review-runner + verify-runner
#   qa           → qa-orchestrator + test-generator + verify-runner
#   ci           → ci-manager + verify-runner
#   cd           → cd-manager + infra-manager
#   infra        → infra-manager + terraform-manager
#   git          → git-manager
#   docs         → docs-generator + verify-runner
#   crud         → crud-generator + crow-rest-api-architecture
#   review       → code-review-runner + bug-hunter
#   refactor     → refactor-optimizer + code-review-runner + cpp
#   db           → db-migration-manager
#   hotfix       → bug-hunter + verify-runner + git-manager + code-review-runner
#   full         → Todos los skills (no recomendado)
#
# Opciones:
#   --list       Solo lista los skills que se cargarían (sin imprimir contenido)
#   --dry-run    Muestra el costo estimado en tokens sin imprimir contenido
#   --tokens     Imprime estimación de tokens al final (para auditoría)
# =============================================================================
set -euo pipefail

AGENTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SKILLS_DIR="${AGENTS_DIR}/skills"
CHARS_PER_TOKEN=3.5

# ─── Opciones ─────────────────────────────────────────────────────────────────
TASK_TYPE="${1:-}"
LIST_ONLY=false
DRY_RUN=false
SHOW_TOKENS=false

for arg in "$@"; do
  case "$arg" in
    --list)     LIST_ONLY=true ;;
    --dry-run)  DRY_RUN=true; LIST_ONLY=true ;;
    --tokens)   SHOW_TOKENS=true ;;
  esac
done

if [[ -z "$TASK_TYPE" ]]; then
  echo "Uso: $0 <tipo-de-tarea> [--list] [--dry-run] [--tokens]"
  echo ""
  echo "Tipos disponibles:"
  echo "  feature   bugfix    qa        ci        cd"
  echo "  infra     git       docs      crud      review"
  echo "  refactor  db        hotfix    full"
  echo ""
  echo "Ejemplo: $0 feature --dry-run"
  exit 1
fi

# ─── Mapa de skills por tipo de tarea ─────────────────────────────────────────
declare -A TASK_SKILLS
TASK_SKILLS=(
  ["feature"]="feature-planner crow-rest-api-architecture cpp"
  ["bugfix"]="bug-hunter code-review-runner verify-runner"
  ["qa"]="qa-orchestrator test-generator verify-runner"
  ["ci"]="ci-manager verify-runner"
  ["cd"]="cd-manager infra-manager"
  ["infra"]="infra-manager terraform-manager"
  ["git"]="git-manager"
  ["docs"]="docs-generator verify-runner"
  ["crud"]="crud-generator crow-rest-api-architecture"
  ["review"]="code-review-runner bug-hunter"
  ["refactor"]="refactor-optimizer code-review-runner cpp"
  ["db"]="db-migration-manager"
  ["hotfix"]="bug-hunter verify-runner git-manager code-review-runner"
  ["full"]="feature-planner crow-rest-api-architecture cpp qa-orchestrator test-generator verify-runner code-review-runner bug-hunter docs-generator git-manager ci-manager cd-manager infra-manager terraform-manager refactor-optimizer db-migration-manager crud-generator cicd-architect"
)

if [[ -z "${TASK_SKILLS[$TASK_TYPE]+_}" ]]; then
  echo "❌ Tipo de tarea desconocido: '${TASK_TYPE}'"
  echo "   Tipos válidos: ${!TASK_SKILLS[*]}"
  exit 1
fi

IFS=' ' read -ra SELECTED_SKILLS <<< "${TASK_SKILLS[$TASK_TYPE]}"

# ─── Calcular costo ──────────────────────────────────────────────────────────
calc_tokens() {
  local total_bytes=0
  for skill in "${SELECTED_SKILLS[@]}"; do
    local skill_file="${SKILLS_DIR}/${skill}/SKILL.md"
    [[ -f "$skill_file" ]] && total_bytes=$(( total_bytes + $(wc -c < "$skill_file") ))
  done
  echo "$(echo "scale=0; $total_bytes / $CHARS_PER_TOKEN" | bc)"
}

# ─── Modo list / dry-run ──────────────────────────────────────────────────────
if [[ "$LIST_ONLY" == "true" ]]; then
  echo "📦 Contexto para tarea: ${TASK_TYPE}"
  echo "   Skills seleccionados (${#SELECTED_SKILLS[@]}):"
  total_bytes=0
  for skill in "${SELECTED_SKILLS[@]}"; do
    skill_file="${SKILLS_DIR}/${skill}/SKILL.md"
    if [[ -f "$skill_file" ]]; then
      bytes=$(wc -c < "$skill_file")
      total_bytes=$(( total_bytes + bytes ))
      printf "   ✓  %-38s %5d bytes\n" "${skill}" "$bytes"
    else
      printf "   ⚠️  %-38s (no encontrado)\n" "${skill}"
    fi
  done
  echo ""
  tokens=$(echo "scale=0; $total_bytes / $CHARS_PER_TOKEN" | bc)
  echo "   Total estimado: ~${tokens} tokens  (${total_bytes} bytes)"
  echo ""
  echo "   Comparar con carga total de skills:"
  all_bytes=$(find "$SKILLS_DIR" \( -name "SKILL.md" -o -name "SKILL.MD" \) \
    -exec wc -c {} + 2>/dev/null | tail -1 | awk '{print $1}' || echo 1)
  all_tokens=$(echo "scale=0; $all_bytes / $CHARS_PER_TOKEN" | bc)
  savings=$(( all_tokens - tokens ))
  pct=$(echo "scale=0; $savings * 100 / $all_tokens" | bc 2>/dev/null || echo 0)
  echo "   Total todos los skills: ~${all_tokens} tokens"
  echo "   Ahorro con contexto mínimo: ~${savings} tokens (${pct}%)"
  exit 0
fi

# ─── Modo de salida completa — imprimir contenido ────────────────────────────
SEPARATOR="════════════════════════════════════════════════════════════════"

echo "# 🔧 Contexto Mínimo CrowKit — Tarea: ${TASK_TYPE}"
echo "# Skills incluidos: ${SELECTED_SKILLS[*]}"
echo "# Generado: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo ""

for skill in "${SELECTED_SKILLS[@]}"; do
  skill_file="${SKILLS_DIR}/${skill}/SKILL.md"
  if [[ -f "$skill_file" ]]; then
    echo ""
    echo "# ${SEPARATOR}"
    echo "# SKILL: ${skill}"
    echo "# ${SEPARATOR}"
    cat "$skill_file"
  else
    echo ""
    echo "# ⚠️  SKILL '${skill}' no encontrado en ${SKILLS_DIR}/${skill}/SKILL.md"
  fi
done

if [[ "$SHOW_TOKENS" == "true" ]]; then
  echo ""
  echo "# 📊 Estimación de tokens para contexto '${TASK_TYPE}': ~$(calc_tokens) tokens"
fi

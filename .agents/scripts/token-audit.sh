#!/usr/bin/env bash
# =============================================================================
# token-audit.sh — CrowKit Agent Token Auditor
# =============================================================================
# Audita el ecosistema .agents/ y estima el consumo de tokens por archivo.
# Detecta violaciones de presupuesto y genera un reporte de optimización.
#
# Uso:
#   ./token-audit.sh [--verbose] [--fail-on-violations] [--json]
#
# Opciones:
#   --verbose           Muestra detalles de cada sección dentro de los archivos
#   --fail-on-violations  Retorna exit code 1 si hay archivos fuera del límite
#   --json              Salida en formato JSON para integración con CI
#
# Constantes de presupuesto:
#   SKILL_MAX_BYTES    = 5000  bytes (~1400 tokens)  → soft limit
#   SKILL_HARD_BYTES   = 8000  bytes (~2300 tokens)  → hard limit (falla audit)
#   AGENTS_MAX_BYTES   = 12000 bytes (~3400 tokens)  → target para AGENTS.md
#   CHARS_PER_TOKEN    = 3.5   (promedio español técnico con código)
# =============================================================================
set -euo pipefail

# ─── Colores ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# ─── Constantes ───────────────────────────────────────────────────────────────
SKILL_SOFT_BYTES=5000
SKILL_HARD_BYTES=8000
AGENTS_TARGET_BYTES=12000
WORKFLOWS_TARGET_BYTES=5000
CHARS_PER_TOKEN=3.5
AGENTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SKILLS_DIR="${AGENTS_DIR}/skills"

# ─── Opciones ─────────────────────────────────────────────────────────────────
VERBOSE=false
FAIL_ON_VIOLATIONS=false
JSON_OUTPUT=false
VIOLATIONS=0
TOTAL_TOKENS=0

for arg in "$@"; do
  case "$arg" in
    --verbose)           VERBOSE=true ;;
    --fail-on-violations) FAIL_ON_VIOLATIONS=true ;;
    --json)              JSON_OUTPUT=true ;;
  esac
done

# ─── Funciones ────────────────────────────────────────────────────────────────
bytes_to_tokens() {
  local bytes=$1
  echo "$(echo "scale=0; $bytes / $CHARS_PER_TOKEN" | bc)"
}

status_icon() {
  local bytes=$1
  local soft=$2
  local hard=$3
  if   [[ $bytes -gt $hard ]]; then echo "🔴"
  elif [[ $bytes -gt $soft ]]; then echo "🟡"
  else                               echo "✅"
  fi
}

print_file_row() {
  local label=$1
  local file=$2
  local soft=$3
  local hard=$4

  if [[ ! -f "$file" ]]; then
    printf "  %-52s %s\n" "$label" "⚠️  ARCHIVO NO ENCONTRADO"
    return
  fi

  local bytes
  bytes=$(wc -c < "$file")
  local tokens
  tokens=$(bytes_to_tokens "$bytes")
  local lines
  lines=$(wc -l < "$file")
  local icon
  icon=$(status_icon "$bytes" "$soft" "$hard")

  TOTAL_TOKENS=$(( TOTAL_TOKENS + tokens ))

  if [[ $bytes -gt $hard ]]; then
    VIOLATIONS=$(( VIOLATIONS + 1 ))
    printf "  ${RED}%-52s %s %6d bytes  ~%4d tok  %3d líneas${NC}\n" \
      "$label" "$icon" "$bytes" "$tokens" "$lines"
  elif [[ $bytes -gt $soft ]]; then
    printf "  ${YELLOW}%-52s %s %6d bytes  ~%4d tok  %3d líneas${NC}\n" \
      "$label" "$icon" "$bytes" "$tokens" "$lines"
  else
    printf "  ${GREEN}%-52s %s %6d bytes  ~%4d tok  %3d líneas${NC}\n" \
      "$label" "$icon" "$bytes" "$tokens" "$lines"
  fi

  if [[ "$VERBOSE" == "true" ]]; then
    # Detectar bloques de código largos (> 20 líneas)
    local code_blocks
    code_blocks=$(grep -c '^\`\`\`' "$file" 2>/dev/null || echo 0)
    local mermaid_blocks
    mermaid_blocks=$(grep -c '^\`\`\`mermaid' "$file" 2>/dev/null || echo 0)
    if [[ $code_blocks -gt 4 ]]; then
      printf "    ${CYAN}→ Bloques de código: %d  (considera moverlos a examples/)${NC}\n" \
        "$(( code_blocks / 2 ))"
    fi
    if [[ $mermaid_blocks -gt 0 ]]; then
      printf "    ${CYAN}→ Diagramas Mermaid: %d  (considera moverlos a resources/)${NC}\n" \
        "$mermaid_blocks"
    fi
  fi
}

# ─── Salida JSON ──────────────────────────────────────────────────────────────
if [[ "$JSON_OUTPUT" == "true" ]]; then
  echo "{"
  echo "  \"audit_date\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\","
  echo "  \"files\": ["
  first=true
  # AGENTS.md
  f="${AGENTS_DIR}/AGENTS.md"
  bytes=$(wc -c < "$f" 2>/dev/null || echo 0)
  tokens=$(bytes_to_tokens "$bytes")
  lines=$(wc -l < "$f" 2>/dev/null || echo 0)
  status="ok"; [[ $bytes -gt $AGENTS_TARGET_BYTES ]] && status="violation"
  [[ "$first" == "true" ]] && first=false || echo ","
  printf '    {"file": "AGENTS.md", "bytes": %d, "tokens": %d, "lines": %d, "status": "%s"}' \
    "$bytes" "$tokens" "$lines" "$status"
  # Skills
  while IFS= read -r -d '' skill_file; do
    skill_name=$(basename "$(dirname "$skill_file")")
    bytes=$(wc -c < "$skill_file" 2>/dev/null || echo 0)
    tokens=$(bytes_to_tokens "$bytes")
    lines=$(wc -l < "$skill_file" 2>/dev/null || echo 0)
    status="ok"
    [[ $bytes -gt $SKILL_HARD_BYTES ]] && status="violation"
    [[ $bytes -gt $SKILL_SOFT_BYTES && $bytes -le $SKILL_HARD_BYTES ]] && status="warning"
    echo ","
    printf '    {"file": "skills/%s/SKILL.md", "bytes": %d, "tokens": %d, "lines": %d, "status": "%s"}' \
      "$skill_name" "$bytes" "$tokens" "$lines" "$status"
  done < <(find "$SKILLS_DIR" -name "SKILL.md" -o -name "SKILL.MD" | sort | tr '\n' '\0')
  echo ""
  echo "  ]"
  echo "}"
  exit 0
fi

# ─── Reporte en consola ───────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}╔══════════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║       🔋 CrowKit — Agent Token Consumption Audit                    ║${NC}"
echo -e "${BOLD}╚══════════════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "  ${CYAN}Presupuesto objetivo por SKILL.md:${NC}  ≤ 5 000 bytes (~1 400 tok)  🟡 warn > 5k  🔴 fail > 8k"
echo -e "  ${CYAN}Estimación:${NC}                          ~3.5 chars/token (español técnico + código)"
echo ""

# ── Archivos del orquestador (system prompt fijo) ────────────────────────────
echo -e "${BOLD}📌 System Prompt Fijo (cargado en TODA sesión)${NC}"
echo "  ─────────────────────────────────────────────────────────────────────"
print_file_row "AGENTS.md" "${AGENTS_DIR}/AGENTS.md" \
  "$AGENTS_TARGET_BYTES" "$(( AGENTS_TARGET_BYTES * 2 ))"
print_file_row "WORKFLOWS.md  [⚠️  debería ser lazy-load]" \
  "${AGENTS_DIR}/WORKFLOWS.md" "$WORKFLOWS_TARGET_BYTES" "$AGENTS_TARGET_BYTES"
echo ""

# ── Skills ───────────────────────────────────────────────────────────────────
echo -e "${BOLD}🧩 Skills (cargados bajo demanda)${NC}"
echo "  ─────────────────────────────────────────────────────────────────────"

skill_total_tokens=0
while IFS= read -r skill_file; do
  skill_name=$(basename "$(dirname "$skill_file")")
  bytes=$(wc -c < "$skill_file" 2>/dev/null || echo 0)
  tok=$(bytes_to_tokens "$bytes")
  skill_total_tokens=$(( skill_total_tokens + tok ))
  print_file_row "skills/${skill_name}/SKILL.md" "$skill_file" \
    "$SKILL_SOFT_BYTES" "$SKILL_HARD_BYTES"
done < <(find "$SKILLS_DIR" \( -name "SKILL.md" -o -name "SKILL.MD" \) | sort)

echo ""

# ── Ejemplos en examples/ ────────────────────────────────────────────────────
EXAMPLES_COUNT=$(find "$SKILLS_DIR" -name "*.cpp" -o -name "*.hpp" | wc -l)
EXAMPLES_BYTES=$(find "$SKILLS_DIR" \( -name "*.cpp" -o -name "*.hpp" \) \
  -exec wc -c {} + 2>/dev/null | tail -1 | awk '{print $1}' || echo 0)
echo -e "${BOLD}📁 Archivos en examples/ (lazy, no cuestan tokens automáticamente)${NC}"
printf "  ${GREEN}%-52s ✅ %6d bytes  (%.0f archivos)${NC}\n" \
  "skills/*/examples/*" "$EXAMPLES_BYTES" "$EXAMPLES_COUNT"
echo ""

# ── Totales ───────────────────────────────────────────────────────────────────
FIXED_TOKENS=$(bytes_to_tokens "$(cat "${AGENTS_DIR}/AGENTS.md" "${AGENTS_DIR}/WORKFLOWS.md" \
  2>/dev/null | wc -c || echo 0)")

echo "  ─────────────────────────────────────────────────────────────────────"
printf "  ${BOLD}%-52s         ~%4d tok${NC}\n" "Costo fijo por sesión (AGENTS + WORKFLOWS)" "$FIXED_TOKENS"
printf "  %-52s         ~%4d tok\n" "Pool total de skills (si todos se cargan)" "$skill_total_tokens"
echo "  ─────────────────────────────────────────────────────────────────────"
echo ""

# ── Violaciones ───────────────────────────────────────────────────────────────
if [[ $VIOLATIONS -gt 0 ]]; then
  echo -e "  ${RED}${BOLD}🚨 Violaciones detectadas: $VIOLATIONS archivo(s) superan el límite de ${SKILL_HARD_BYTES} bytes${NC}"
  echo -e "  ${RED}   Ejecuta: ./.agents/scripts/skill-lint.sh --fix-hints para ver sugerencias${NC}"
else
  echo -e "  ${GREEN}${BOLD}✅ Ningún archivo supera el límite de ${SKILL_HARD_BYTES} bytes${NC}"
fi
echo ""

# ── Recomendaciones ───────────────────────────────────────────────────────────
echo -e "${BOLD}💡 Comandos relacionados${NC}"
echo "  ./.agents/scripts/skill-lint.sh              → Linting detallado por skill"
echo "  ./.agents/scripts/skill-lint.sh --fix-hints  → Sugerencias de refactoring"
echo "  ./.agents/scripts/lazy-skill.sh <nombre>     → Imprimir skill bajo demanda"
echo "  ./.agents/scripts/context-builder.sh <tarea> → Contexto mínimo para una tarea"
echo ""

[[ "$FAIL_ON_VIOLATIONS" == "true" && $VIOLATIONS -gt 0 ]] && exit 1
exit 0

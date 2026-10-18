#!/usr/bin/env bash
# =============================================================================
# skill-lint.sh — CrowKit SKILL.md Linter
# =============================================================================
# Valida que cada SKILL.md del ecosistema .agents/skills/ cumpla el estándar
# de token budget, estructura y convenciones del proyecto.
#
# Reglas validadas:
#   [L001] Tamaño ≤ 5 000 bytes (soft) / ≤ 8 000 bytes (hard)
#   [L002] Líneas ≤ 150 (soft) / ≤ 250 (hard)
#   [L003] Frontmatter YAML presente (--- ... ---)
#   [L004] Campo 'name:' presente en frontmatter
#   [L005] Campo 'description:' de 1 sola línea (≤ 120 chars)
#   [L006] Bloques de código ≤ 3 en el cuerpo (resto deben ir a examples/)
#   [L007] No contiene diagramas Mermaid (deben ir a resources/)
#   [L008] Nombre de archivo es exactamente 'SKILL.md' (no SKILL.MD)
#   [L009] Si existen examples/, deben referenciarse en el SKILL.md
#   [L010] No tiene plantillas/templates embebidas (deben ir a templates/)
#
# Uso:
#   ./skill-lint.sh [<skill-name>] [--fix-hints] [--strict] [--json]
#
# Opciones:
#   <skill-name>    Auditar solo ese skill (sin arg = todos)
#   --fix-hints     Muestra sugerencias de cómo solucionar cada issue
#   --strict        Convierte warnings en errores (exit 1)
#   --json          Salida en JSON para CI
# =============================================================================
set -euo pipefail

# ─── Colores ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# ─── Configuración ────────────────────────────────────────────────────────────
AGENTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SKILLS_DIR="${AGENTS_DIR}/skills"
SKILL_SOFT_BYTES=5000
SKILL_HARD_BYTES=8000
SKILL_SOFT_LINES=150
SKILL_HARD_LINES=250
MAX_CODE_BLOCKS=3
MAX_DESC_CHARS=120

FIX_HINTS=false
STRICT=false
JSON_OUTPUT=false
TARGET_SKILL=""
TOTAL_ERRORS=0
TOTAL_WARNINGS=0

for arg in "$@"; do
  case "$arg" in
    --fix-hints) FIX_HINTS=true ;;
    --strict)    STRICT=true ;;
    --json)      JSON_OUTPUT=true ;;
    --*)         ;;
    *)           TARGET_SKILL="$arg" ;;
  esac
done

# ─── Funciones ────────────────────────────────────────────────────────────────
emit_error() {
  local code=$1 msg=$2 hint=$3
  echo -e "    ${RED}✗ [${code}] ${msg}${NC}"
  [[ "$FIX_HINTS" == "true" ]] && echo -e "      ${CYAN}→ ${hint}${NC}"
  TOTAL_ERRORS=$(( TOTAL_ERRORS + 1 ))
}

emit_warning() {
  local code=$1 msg=$2 hint=$3
  echo -e "    ${YELLOW}⚠ [${code}] ${msg}${NC}"
  [[ "$FIX_HINTS" == "true" ]] && echo -e "      ${CYAN}→ ${hint}${NC}"
  if [[ "$STRICT" == "true" ]]; then
    TOTAL_ERRORS=$(( TOTAL_ERRORS + 1 ))
  else
    TOTAL_WARNINGS=$(( TOTAL_WARNINGS + 1 ))
  fi
}

emit_ok() {
  local code=$1 msg=$2
  echo -e "    ${GREEN}✓ [${code}] ${msg}${NC}"
}

lint_skill() {
  local skill_dir=$1
  local skill_name
  skill_name=$(basename "$skill_dir")

  # Buscar SKILL.md (case-insensitive)
  local skill_file=""
  if [[ -f "${skill_dir}/SKILL.md" ]]; then
    skill_file="${skill_dir}/SKILL.md"
  elif [[ -f "${skill_dir}/SKILL.MD" ]]; then
    skill_file="${skill_dir}/SKILL.MD"
  fi

  echo ""
  echo -e "  ${BOLD}── ${skill_name}${NC}"

  # L008 — Nombre de archivo
  if [[ -f "${skill_dir}/SKILL.MD" && ! -f "${skill_dir}/SKILL.md" ]]; then
    emit_error "L008" "Archivo llamado 'SKILL.MD' (mayúsculas)" \
      "Renombrar: git mv SKILL.MD SKILL.md"
  elif [[ -z "$skill_file" ]]; then
    emit_error "L008" "No se encontró SKILL.md ni SKILL.MD en ${skill_name}/" \
      "Crear el archivo: touch .agents/skills/${skill_name}/SKILL.md"
    return
  else
    emit_ok "L008" "Nombre de archivo correcto: SKILL.md"
  fi

  local bytes lines
  bytes=$(wc -c < "$skill_file")
  lines=$(wc -l < "$skill_file")

  # L001 — Tamaño en bytes
  if [[ $bytes -gt $SKILL_HARD_BYTES ]]; then
    emit_error "L001" "${bytes} bytes → supera límite hard de ${SKILL_HARD_BYTES} bytes" \
      "Mover bloques de código a examples/ y diagramas a resources/"
  elif [[ $bytes -gt $SKILL_SOFT_BYTES ]]; then
    emit_warning "L001" "${bytes} bytes → supera límite soft de ${SKILL_SOFT_BYTES} bytes" \
      "Objetivo: ≤ 5 000 bytes. Extraer snippets a examples/"
  else
    emit_ok "L001" "${bytes} bytes ≤ ${SKILL_SOFT_BYTES} bytes ✓"
  fi

  # L002 — Número de líneas
  if [[ $lines -gt $SKILL_HARD_LINES ]]; then
    emit_error "L002" "${lines} líneas → supera límite hard de ${SKILL_HARD_LINES}" \
      "Condensar reglas en prosa, mover ejemplos a examples/"
  elif [[ $lines -gt $SKILL_SOFT_LINES ]]; then
    emit_warning "L002" "${lines} líneas → supera límite soft de ${SKILL_SOFT_LINES}" \
      "Objetivo: ≤ 150 líneas. Revisar si hay contenido que puede externalizarse"
  else
    emit_ok "L002" "${lines} líneas ≤ ${SKILL_SOFT_LINES} líneas ✓"
  fi

  # L003 — Frontmatter YAML
  if head -1 "$skill_file" | grep -q '^---$'; then
    emit_ok "L003" "Frontmatter YAML presente"
  else
    emit_error "L003" "Frontmatter YAML ausente (el archivo no empieza con ---)" \
      "Añadir bloque --- name: ... description: ... --- al inicio del archivo"
  fi

  # L004 — Campo 'name:'
  if grep -q '^name:' "$skill_file"; then
    local name_val
    name_val=$(grep '^name:' "$skill_file" | head -1 | cut -d: -f2- | xargs)
    emit_ok "L004" "Campo 'name:' presente → '${name_val}'"
  else
    emit_error "L004" "Campo 'name:' ausente en frontmatter" \
      "Añadir: name: nombre-del-skill en el bloque YAML"
  fi

  # L005 — description: de 1 sola línea
  if grep -q '^description:' "$skill_file"; then
    local desc_line
    desc_line=$(grep '^description:' "$skill_file" | head -1)
    local desc_chars=${#desc_line}
    if [[ $desc_chars -gt $MAX_DESC_CHARS ]]; then
      emit_warning "L005" "description: muy larga (${desc_chars} chars > ${MAX_DESC_CHARS})" \
        "Acortar a 1 línea concisa ≤ ${MAX_DESC_CHARS} chars. El detalle va en el cuerpo del SKILL.md"
    else
      emit_ok "L005" "description: concisa (${desc_chars} chars) ✓"
    fi
  else
    emit_error "L005" "Campo 'description:' ausente en frontmatter" \
      "Añadir: description: descripción de 1 línea"
  fi

  # L006 — Bloques de código en el cuerpo
  local code_fence_count
  code_fence_count=$(grep -c '^```' "$skill_file" 2>/dev/null || true)
  [[ -z "$code_fence_count" ]] && code_fence_count=0
  local code_block_count=$(( code_fence_count / 2 ))
  if [[ $code_block_count -gt $MAX_CODE_BLOCKS ]]; then
    emit_warning "L006" "${code_block_count} bloques de código → supera límite de ${MAX_CODE_BLOCKS}" \
      "Mover snippets a examples/<nombre>.cpp y referenciarlos con un link"
  else
    emit_ok "L006" "${code_block_count} bloque(s) de código ≤ ${MAX_CODE_BLOCKS} ✓"
  fi

  # L007 — Diagramas Mermaid
  local mermaid_count
  mermaid_count=$(grep -c '^```mermaid' "$skill_file" 2>/dev/null || true)
  [[ -z "$mermaid_count" ]] && mermaid_count=0
  if [[ $mermaid_count -gt 0 ]]; then
    emit_warning "L007" "${mermaid_count} diagrama(s) Mermaid embebido(s)" \
      "Mover diagramas a resources/diagram.md o docs/ y referenciarlos con un link"
  else
    emit_ok "L007" "Sin diagramas Mermaid en el cuerpo ✓"
  fi

  # L009 — Si existe examples/ debe estar referenciado
  if [[ -d "${skill_dir}/examples" ]]; then
    local ex_count
    ex_count=$(find "${skill_dir}/examples" -type f | wc -l)
    if grep -qi 'examples/' "$skill_file"; then
      emit_ok "L009" "examples/ (${ex_count} archivos) referenciado en SKILL.md ✓"
    else
      emit_warning "L009" "Directorio examples/ existe (${ex_count} archivos) pero no se referencia en SKILL.md" \
        "Añadir tabla de referencia: | [archivo](examples/archivo.cpp) | descripción |"
    fi
  fi

  # L010 — Templates embebidas
  local template_block_lines
  template_block_lines=$(grep -c -E '^(#{1,3} .*[Tt]emplate|^```.*markdown)' "$skill_file" 2>/dev/null || true)
  [[ -z "$template_block_lines" ]] && template_block_lines=0
  if [[ $template_block_lines -gt 2 ]]; then
    emit_warning "L010" "Posibles templates/plantillas embebidas detectadas (${template_block_lines} marcadores)" \
      "Mover plantillas a templates/<nombre>.md y referenciar con: > Template: templates/<nombre>.md"
  else
    emit_ok "L010" "Sin plantillas embebidas detectadas ✓"
  fi
}

# ─── Ejecución ────────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}╔══════════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║       🧹 CrowKit SKILL.md Linter — Token Budget Validator           ║${NC}"
echo -e "${BOLD}╚══════════════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "  Reglas: L001 bytes≤8k  L002 lines≤250  L003-L005 frontmatter"
echo -e "          L006 code-blocks≤3  L007 no-mermaid  L008 filename  L009 examples-ref"
[[ "$STRICT" == "true" ]] && echo -e "  ${YELLOW}Modo: --strict (warnings = errors)${NC}"
[[ "$FIX_HINTS" == "true" ]] && echo -e "  ${CYAN}Modo: --fix-hints habilitado${NC}"

if [[ -n "$TARGET_SKILL" ]]; then
  skill_dir="${SKILLS_DIR}/${TARGET_SKILL}"
  if [[ ! -d "$skill_dir" ]]; then
    echo -e "${RED}Error: skill '${TARGET_SKILL}' no encontrado en ${SKILLS_DIR}/${NC}"
    exit 1
  fi
  lint_skill "$skill_dir"
else
  while IFS= read -r -d '' skill_dir; do
    lint_skill "$skill_dir"
  done < <(find "$SKILLS_DIR" -mindepth 1 -maxdepth 1 -type d -print0 | sort -z)
fi

# ─── Resumen ──────────────────────────────────────────────────────────────────
echo ""
echo "  ─────────────────────────────────────────────────────────────────────"
if [[ $TOTAL_ERRORS -gt 0 ]]; then
  echo -e "  ${RED}${BOLD}🚨 Resultado: $TOTAL_ERRORS error(s) | $TOTAL_WARNINGS advertencia(s)${NC}"
  exit 1
elif [[ $TOTAL_WARNINGS -gt 0 ]]; then
  echo -e "  ${YELLOW}${BOLD}⚠️  Resultado: 0 errores | $TOTAL_WARNINGS advertencia(s)${NC}"
  echo -e "  ${YELLOW}   Ejecuta con --strict para tratarlas como errores${NC}"
  exit 0
else
  echo -e "  ${GREEN}${BOLD}✅ Todos los skills cumplen el estándar de token budget${NC}"
  exit 0
fi

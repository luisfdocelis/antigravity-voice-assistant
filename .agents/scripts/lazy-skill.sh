#!/usr/bin/env bash
# =============================================================================
# lazy-skill.sh — CrowKit On-Demand Skill Loader
# =============================================================================
# Carga e imprime el contenido de un skill específico bajo demanda.
# Los agentes usan este script para leer un skill solo cuando lo necesitan,
# evitando cargar el sistema completo de skills en el contexto.
#
# También puede cargar archivos de examples/, templates/ o resources/ de un
# skill, permitiendo acceso granular al contenido de referencia.
#
# Uso:
#   ./lazy-skill.sh <skill-name> [--section <sección>] [--example <archivo>]
#                                [--template <archivo>] [--info]
#
# Ejemplos:
#   ./lazy-skill.sh cpp                          → Carga cpp/SKILL.md
#   ./lazy-skill.sh cpp --example lambdas.cpp    → Carga cpp/examples/lambdas.cpp
#   ./lazy-skill.sh qa-orchestrator --template qa-report.md
#   ./lazy-skill.sh feature-planner --info       → Muestra metadata sin contenido
#   ./lazy-skill.sh --list                       → Lista todos los skills disponibles
# =============================================================================
set -euo pipefail

AGENTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SKILLS_DIR="${AGENTS_DIR}/skills"
CHARS_PER_TOKEN=3.5

# ─── Colores ──────────────────────────────────────────────────────────────────
CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BOLD='\033[1m'
NC='\033[0m'

# ─── Parseo de argumentos ──────────────────────────────────────────────────────
SKILL_NAME=""
EXAMPLE_FILE=""
TEMPLATE_FILE=""
SHOW_INFO=false
LIST_ALL=false

i=1
for arg in "$@"; do
  case "$arg" in
    --list)     LIST_ALL=true ;;
    --info)     SHOW_INFO=true ;;
    --example)  ;;
    --template) ;;
    --section)  ;;
    *)
      # Argumento posicional o valor de flag
      prev="${*:$((i-1)):1}"
      case "$prev" in
        --example)  EXAMPLE_FILE="$arg" ;;
        --template) TEMPLATE_FILE="$arg" ;;
        --section)  ;; # reservado para futura implementación
        *)          [[ -z "$SKILL_NAME" && ! "$arg" =~ ^-- ]] && SKILL_NAME="$arg" ;;
      esac
      ;;
  esac
  i=$(( i + 1 ))
done

# ─── Listar todos los skills ──────────────────────────────────────────────────
if [[ "$LIST_ALL" == "true" ]]; then
  echo ""
  echo -e "${BOLD}📦 Skills disponibles en CrowKit${NC}"
  echo "  ─────────────────────────────────────────────────────────"
  printf "  %-36s %6s  %5s  %s\n" "SKILL" "BYTES" "~TOK" "EXTRAS"
  echo "  ─────────────────────────────────────────────────────────"
  while IFS= read -r -d '' skill_dir; do
    name=$(basename "$skill_dir")
    skill_file="${skill_dir}/SKILL.md"
    [[ ! -f "$skill_file" ]] && skill_file="${skill_dir}/SKILL.MD"
    if [[ -f "$skill_file" ]]; then
      bytes=$(wc -c < "$skill_file")
      tokens=$(echo "scale=0; $bytes / $CHARS_PER_TOKEN" | bc)
      extras=""
      [[ -d "${skill_dir}/examples" ]]  && extras+="examples/ "
      [[ -d "${skill_dir}/templates" ]] && extras+="templates/ "
      [[ -d "${skill_dir}/resources" ]] && extras+="resources/ "
      [[ -d "${skill_dir}/references" ]] && extras+="references/ "
      printf "  %-36s %6d  %5d  %s\n" "$name" "$bytes" "$tokens" "$extras"
    fi
  done < <(find "$SKILLS_DIR" -mindepth 1 -maxdepth 1 -type d -print0 | sort -z)
  echo ""
  echo -e "  ${CYAN}Uso: $0 <skill-name>                    → cargar SKILL.md${NC}"
  echo -e "  ${CYAN}     $0 <skill-name> --example <file>   → cargar examples/<file>${NC}"
  echo -e "  ${CYAN}     $0 <skill-name> --info             → mostrar metadata${NC}"
  echo ""
  exit 0
fi

# ─── Validar skill ────────────────────────────────────────────────────────────
if [[ -z "$SKILL_NAME" ]]; then
  echo "Uso: $0 <skill-name> [--example <archivo>] [--template <archivo>] [--info]"
  echo "     $0 --list"
  exit 1
fi

SKILL_DIR="${SKILLS_DIR}/${SKILL_NAME}"
if [[ ! -d "$SKILL_DIR" ]]; then
  # Intentar búsqueda parcial
  MATCH=$(find "$SKILLS_DIR" -mindepth 1 -maxdepth 1 -type d -name "*${SKILL_NAME}*" | head -1 || true)
  if [[ -n "$MATCH" ]]; then
    echo -e "${YELLOW}⚠️  Skill '${SKILL_NAME}' no encontrado exactamente. ¿Quisiste decir '$(basename "$MATCH")'?${NC}" >&2
    SKILL_DIR="$MATCH"
    SKILL_NAME=$(basename "$MATCH")
  else
    echo -e "${RED}❌ Skill '${SKILL_NAME}' no encontrado en ${SKILLS_DIR}/${NC}" >&2
    echo "   Ejecuta: $0 --list para ver los skills disponibles" >&2
    exit 1
  fi
fi

SKILL_FILE="${SKILL_DIR}/SKILL.md"
[[ ! -f "$SKILL_FILE" ]] && SKILL_FILE="${SKILL_DIR}/SKILL.MD"

# ─── Modo --info ─────────────────────────────────────────────────────────────
if [[ "$SHOW_INFO" == "true" ]]; then
  echo ""
  echo -e "${BOLD}📋 Info — ${SKILL_NAME}${NC}"
  echo "  ─────────────────────────────────────────────────────────"
  if [[ -f "$SKILL_FILE" ]]; then
    bytes=$(wc -c < "$SKILL_FILE")
    lines=$(wc -l < "$SKILL_FILE")
    tokens=$(echo "scale=0; $bytes / $CHARS_PER_TOKEN" | bc)
    printf "  ${GREEN}%-20s${NC} %s\n" "SKILL.md:" "${bytes} bytes, ${lines} líneas, ~${tokens} tokens"

    # Extraer metadata del frontmatter
    name_val=$(grep '^name:' "$SKILL_FILE" 2>/dev/null | head -1 | cut -d: -f2- | xargs || echo "(no definido)")
    desc_val=$(grep '^description:' "$SKILL_FILE" 2>/dev/null | head -1 | cut -d: -f2- | xargs || echo "(no definido)")
    printf "  ${GREEN}%-20s${NC} %s\n" "name:" "$name_val"
    printf "  ${GREEN}%-20s${NC} %s\n" "description:" "$desc_val"
  fi

  # Extras
  for subdir in examples templates resources references; do
    subpath="${SKILL_DIR}/${subdir}"
    if [[ -d "$subpath" ]]; then
      count=$(find "$subpath" -type f | wc -l)
      files=$(find "$subpath" -type f -exec basename {} \; | sort | tr '\n' '  ')
      printf "  ${CYAN}%-20s${NC} %d archivo(s): %s\n" "${subdir}/:" "$count" "$files"
    fi
  done
  echo ""
  exit 0
fi

# ─── Cargar ejemplo ───────────────────────────────────────────────────────────
if [[ -n "$EXAMPLE_FILE" ]]; then
  target="${SKILL_DIR}/examples/${EXAMPLE_FILE}"
  if [[ ! -f "$target" ]]; then
    echo -e "${RED}❌ Ejemplo '${EXAMPLE_FILE}' no encontrado en ${SKILL_DIR}/examples/${NC}" >&2
    echo "   Archivos disponibles:" >&2
    find "${SKILL_DIR}/examples" -type f -exec basename {} \; 2>/dev/null | sort >&2 || true
    exit 1
  fi
  bytes=$(wc -c < "$target")
  tokens=$(echo "scale=0; $bytes / $CHARS_PER_TOKEN" | bc)
  echo "# skill: ${SKILL_NAME} | example: ${EXAMPLE_FILE} | ~${tokens} tokens"
  echo ""
  cat "$target"
  exit 0
fi

# ─── Cargar template ──────────────────────────────────────────────────────────
if [[ -n "$TEMPLATE_FILE" ]]; then
  target="${SKILL_DIR}/templates/${TEMPLATE_FILE}"
  if [[ ! -f "$target" ]]; then
    echo -e "${RED}❌ Template '${TEMPLATE_FILE}' no encontrado en ${SKILL_DIR}/templates/${NC}" >&2
    find "${SKILL_DIR}/templates" -type f -exec basename {} \; 2>/dev/null | sort >&2 || true
    exit 1
  fi
  bytes=$(wc -c < "$target")
  tokens=$(echo "scale=0; $bytes / $CHARS_PER_TOKEN" | bc)
  echo "# skill: ${SKILL_NAME} | template: ${TEMPLATE_FILE} | ~${tokens} tokens"
  echo ""
  cat "$target"
  exit 0
fi

# ─── Cargar SKILL.md principal ────────────────────────────────────────────────
if [[ ! -f "$SKILL_FILE" ]]; then
  echo -e "${RED}❌ SKILL.md no encontrado en ${SKILL_DIR}/${NC}" >&2
  exit 1
fi

bytes=$(wc -c < "$SKILL_FILE")
tokens=$(echo "scale=0; $bytes / $CHARS_PER_TOKEN" | bc)
echo "# skill: ${SKILL_NAME} | ~${tokens} tokens | $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo ""
cat "$SKILL_FILE"

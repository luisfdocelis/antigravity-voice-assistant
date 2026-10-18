#!/usr/bin/env bash
# ==============================================================================
# Antigravity Voice Assistant — Quality Gates & Local Verification 🎙️
# Valida manifiesto plugin.json, scripts Python, templates HTML y skills.
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# Colores ANSI
CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
BOLD='\033[1m'
NC='\033[0m'

cd "$REPO_ROOT"

echo -e "${BOLD}${CYAN}=========================================================${NC}"
echo -e "${BOLD}${CYAN} Antigravity Voice Assistant — Quality Gates Suite 🎙️     ${NC}"
echo -e "${BOLD}${CYAN}=========================================================${NC}"

# 1. Validación de Manifiesto
echo -e "\n${YELLOW}[1/4] Validando manifiesto plugin.json...${NC}"
if [ ! -f "plugin.json" ]; then
    echo -e "${RED}[ERROR] No se encontró plugin.json en la raíz del repositorio.${NC}" >&2
    exit 1
fi
python3 -m json.tool plugin.json > /dev/null
python3 -c "
import json
with open('plugin.json') as f:
    d = json.load(f)
assert 'name' in d, 'Falta campo name'
assert 'version' in d, 'Falta campo version'
assert 'description' in d, 'Falta campo description'
"
echo -e "${GREEN}✔ plugin.json es válido y estructurado.${NC}"

# 2. Validación de Scripts Python (CLI)
echo -e "\n${YELLOW}[2/4] Validando scripts Python y sintaxis CLI...${NC}"
python3 -m py_compile scripts/*.py
python3 scripts/voice_tts.py --help > /dev/null
echo -e "${GREEN}✔ Scripts de scripts/*.py compilados y validados.${NC}"

# 3. Validación de Plantillas HTML y Artefactos
echo -e "\n${YELLOW}[3/4] Validando integridad de plantillas del asistente...${NC}"
TEMPLATE_PATH=".agents/skills/accessible-voice-assistant/resources/audio-assistant-template.html"
if [ ! -f "$TEMPLATE_PATH" ]; then
    echo -e "${RED}[ERROR] No se encontró la plantilla en $TEMPLATE_PATH${NC}" >&2
    exit 1
fi
python3 -c "
with open('$TEMPLATE_PATH') as f:
    c = f.read()
assert 'play-btn' in c, 'Falta play-btn en template'
assert 'reading-bar' in c, 'Falta reading-bar en template'
assert 'theme-select' in c, 'Falta theme-select en template'
assert 'voice-profile' in c, 'Falta voice-profile en template'
assert 'window.speechSynthesis' in c, 'Falta window.speechSynthesis en template'
"
echo -e "${GREEN}✔ Plantilla HTML base y controles de accesibilidad íntegros.${NC}"

# 4. Validación de Skills y Documentación
echo -e "\n${YELLOW}[4/4] Validando frontmatter YAML en skills...${NC}"
SKILL_COUNT=0
for skill in .agents/skills/*/SKILL.md; do
    if [ -f "$skill" ]; then
        python3 -c "
with open('$skill') as f:
    lines = f.readlines()
assert lines[0].strip() == '---', 'Frontmatter YAML no inicia con ---'
has_closing = any(l.strip() == '---' for l in lines[1:])
assert has_closing, 'Frontmatter YAML no tiene cierre ---'
"
        SKILL_COUNT=$((SKILL_COUNT + 1))
    fi
done
echo -e "${GREEN}✔ $SKILL_COUNT skills validadas con frontmatter YAML correcto.${NC}"

echo -e "\n${BOLD}${GREEN}=========================================================${NC}"
echo -e "${BOLD}${GREEN} ¡Todos los Quality Gates han sido aprobados con éxito!   ${NC}"
echo -e "${BOLD}${GREEN}=========================================================${NC}"

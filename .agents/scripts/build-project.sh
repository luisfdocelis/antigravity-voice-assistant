#!/usr/bin/env bash
# =============================================================================
# build-project.sh — Automated C++20 Release Builder for CrowKit Projects
# =============================================================================
# Compila proyectos consumidores de CrowKit en modo Release con LTO, aplica
# stripping estricto y valida que el tamaño del binario no exceda 5 MB.
#
# Uso:
#   ./build-project.sh [opciones] [<directorio-del-proyecto>]
#
# Opciones:
#   --run-tests       Ejecuta la suite CTest tras una compilación exitosa
#   --clean           Limpia el directorio build antes de compilar
#   --max-size-mb <N> Límite de tamaño en MB para el binario (default: 5)
# =============================================================================
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m'

RUN_TESTS=false
CLEAN_BUILD=false
MAX_SIZE_MB=5
PROJECT_DIR="."

while [[ $# -gt 0 ]]; do
  case "$1" in
    --run-tests)
      RUN_TESTS=true
      shift
      ;;
    --clean)
      CLEAN_BUILD=true
      shift
      ;;
    --max-size-mb)
      MAX_SIZE_MB="$2"
      shift 2
      ;;
    -*)
      echo -e "${RED}Error: Opción desconocida $1${NC}" >&2
      exit 1
      ;;
    *)
      PROJECT_DIR="$1"
      shift
      ;;
  esac
done

if [[ ! -f "${PROJECT_DIR}/CMakeLists.txt" ]]; then
  echo -e "${RED}Error: No se encontró CMakeLists.txt en '${PROJECT_DIR}'${NC}" >&2
  exit 1
fi

PROJECT_DIR=$(cd "${PROJECT_DIR}" && pwd)
BUILD_DIR="${PROJECT_DIR}/build"

if [[ "$CLEAN_BUILD" == "true" && -d "$BUILD_DIR" ]]; then
  echo -e "${YELLOW}Limpiando directorio de compilación previo...${NC}"
  rm -rf "$BUILD_DIR"
fi

echo -e "${BOLD}Configurando CMake en modo Release con LTO...${NC}"
cmake -B "$BUILD_DIR" -S "$PROJECT_DIR" \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INTERPROCEDURAL_OPTIMIZATION=ON

NPROC=$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 2)
echo -e "${BOLD}Compilando con ${NPROC} hilos concurrentes...${NC}"
cmake --build "$BUILD_DIR" -j"${NPROC}"

echo -e "${BOLD}Aplicando stripping a los binarios ejecutables...${NC}"
find "$BUILD_DIR" -maxdepth 2 -type f -executable ! -name "*.sh" ! -name "*.py" | while read -r bin; do
  if file "$bin" | grep -q 'ELF.*executable'; then
    strip --strip-all "$bin" 2>/dev/null || true
    BYTES=$(stat -c%s "$bin" 2>/dev/null || stat -f%z "$bin" 2>/dev/null || echo 0)
    MB=$(( BYTES / 1048576 ))
    MAX_BYTES=$(( MAX_SIZE_MB * 1048576 ))

    if [[ $BYTES -gt $MAX_BYTES ]]; then
      echo -e "${RED}⚠️ Alerta: El binario '$(basename "$bin")' mide ${MB} MB (supera el límite de ${MAX_SIZE_MB} MB)${NC}" >&2
    else
      echo -e "${GREEN}✓ Binario '$(basename "$bin")': ${BYTES} bytes (${MB} MB) ≤ ${MAX_SIZE_MB} MB${NC}"
    fi
  fi
done

if [[ "$RUN_TESTS" == "true" ]]; then
  echo -e "${BOLD}Ejecutando pruebas CTest...${NC}"
  ctest --test-dir "$BUILD_DIR" --output-on-failure
fi

echo -e "${GREEN}✓ Proceso de compilación completado exitosamente.${NC}"

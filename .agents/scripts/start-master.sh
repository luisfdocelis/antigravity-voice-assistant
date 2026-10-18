#!/usr/bin/env bash
# Script para iniciar el entorno de desarrollo SaaS Master en Bash (Linux/macOS/Git Bash)

set -e

echo -e "\033[36m=============================================\033[0m"
echo -e "\033[36m Iniciando Entorno de Desarrollo SaaS Master \033[0m"
echo -e "\033[36m=============================================\033[0m"

# 1. Verificar Docker
echo -e "\n\033[33m[1/3] Verificando estado del motor Docker...\033[0m"
if ! docker info > /dev/null 2>&1; then
    echo "Docker no está corriendo. Intentando iniciar Docker..."
    if command -v open > /dev/null 2>&1; then
        open -a Docker
    elif command -v systemctl > /dev/null 2>&1; then
        sudo systemctl start docker
    fi
    sleep 5
fi
echo -e "\033[32m[OK] Docker motor está activo.\033[0m"

# 2. Levantar db, redis, minio, pgadmin
echo -e "\n\033[33m[2/3] Levantando servicios base en contenedores (db, redis, minio, pgadmin)...\033[0m"
if [ ! -f ".env" ] && [ -f ".env.example" ]; then
    cp .env.example .env
fi
docker compose up -d db redis minio pgadmin
echo -e "\033[32m[OK] Servicios db, redis, minio y pgadmin activos.\033[0m"

# 3. Levantar Master API y Master Web localmente
echo -e "\n\033[33m[3/3] Iniciando Master API y Master Web de manera local...\033[0m"

SCRIPTS_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
ROOT_DIR="$( cd "$SCRIPTS_DIR/../.." && pwd )"

if [ -f "$ROOT_DIR/.venv/bin/activate" ]; source "$ROOT_DIR/.venv/bin/activate"; fi

echo "Iniciando Master Backend API en http://localhost:8000 ..."
(cd "$ROOT_DIR/apps/master-api" && PYTHONPATH="$ROOT_DIR/apps/master-api" uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload) &

echo "Iniciando Master Frontend Web en http://localhost:3000 ..."
(cd "$ROOT_DIR/apps/master-web" && npm run dev) &

echo -e "\n\033[32m==========================================================\033[0m"
echo -e "\033[32m Entorno SaaS Master iniciado exitosamente de forma local! \033[0m"
echo -e "\033[32m==========================================================\033[0m"

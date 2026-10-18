#!/usr/bin/env bash
# Script para detener los servicios locales y contenedores del entorno SaaS Master en Bash

echo -e "\033[36m=============================================\033[0m"
echo -e "\033[36m Deteniendo Entorno de Desarrollo SaaS Master \033[0m"
echo -e "\033[36m=============================================\033[0m"

# 1. Detener procesos de uvicorn y node
echo -e "\n\033[33m[1/2] Deteniendo procesos de master-api y master-web...\033[0m"
pkill -f uvicorn || true
pkill -f "next-dev" || true
pkill -f node || true
echo -e "\033[32m[OK] Procesos locales detenidos.\033[0m"

# 2. Detener contenedores Docker
echo -e "\n\033[33m[2/2] Deteniendo contenedores base de Docker Compose...\033[0m"
docker compose stop db redis minio pgadmin || true
echo -e "\033[32m[OK] Contenedores Docker detenidos.\033[0m"

echo -e "\n\033[32m==========================================================\033[0m"
echo -e "\033[32m Todos los servicios de SaaS Master han sido detenidos.  \033[0m"
echo -e "\033[32m==========================================================\033[0m"

# Script para detener los servicios locales y contenedores del entorno SaaS Master

$ErrorActionPreference = "SilentlyContinue"

Write-Host "=============================================" -ForegroundColor Cyan
Write-Host " Deteniendo Entorno de Desarrollo SaaS Master " -ForegroundColor Cyan
Write-Host "=============================================" -ForegroundColor Cyan

# 1. Detener procesos locales Node / Next.js de master-web
Write-Host "`n[1/3] Deteniendo procesos de master-web (Node.js)..." -ForegroundColor Yellow
$nodeProcesses = Get-Process -Name node -ErrorAction SilentlyContinue
if ($nodeProcesses) {
    Stop-Process -Name node -Force -ErrorAction SilentlyContinue
    Write-Host "[OK] Procesos de Node.js detenidos." -ForegroundColor Green
} else {
    Write-Host "No se encontraron procesos de Node.js en ejecución." -ForegroundColor Gray
}

# 2. Detener procesos locales Python / Uvicorn de master-api
Write-Host "`n[2/3] Deteniendo procesos de master-api (Python / Uvicorn)..." -ForegroundColor Yellow
$pythonProcesses = Get-Process -Name python -ErrorAction SilentlyContinue | Where-Object { $_.CommandLine -like "*uvicorn*" -or $_.CommandLine -like "*master-api*" }
if ($pythonProcesses) {
    $pythonProcesses | Stop-Process -Force -ErrorAction SilentlyContinue
    Write-Host "[OK] Procesos de master-api detenidos." -ForegroundColor Green
} else {
    # Detener por si acaso cualquier proceso uvicorn
    Stop-Process -Name python -Force -ErrorAction SilentlyContinue
    Write-Host "[OK] Procesos de Python / Uvicorn detenidos." -ForegroundColor Green
}

# 3. Detener contenedores Docker (db, redis, minio, pgadmin)
Write-Host "`n[3/3] Deteniendo contenedores base de Docker Compose (db, redis, minio, pgadmin)..." -ForegroundColor Yellow
docker compose stop db redis minio pgadmin
if ($LASTEXITCODE -eq 0) {
    Write-Host "[OK] Contenedores Docker detenidos." -ForegroundColor Green
} else {
    Write-Host "No se requirió detener contenedores o Docker no estaba activo." -ForegroundColor Gray
}

Write-Host "`n==========================================================" -ForegroundColor Green
Write-Host " Todos los servicios de SaaS Master han sido detenidos.  " -ForegroundColor Green
Write-Host "==========================================================" -ForegroundColor Green

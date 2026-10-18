# Script para iniciar el entorno de desarrollo SaaS Master
# Requisitos previos:
# 1. Verifica/inicia el servicio de Docker Desktop.
# 2. Levanta los contenedores base (db, redis, minio, pgadmin).
# 3. Ejecuta de manera local los servidores de master-api y master-web.

$ErrorActionPreference = "Stop"

Write-Host "=============================================" -ForegroundColor Cyan
Write-Host " Iniciando Entorno de Desarrollo SaaS Master " -ForegroundColor Cyan
Write-Host "=============================================" -ForegroundColor Cyan

# 1. Verificar si Docker está corriendo
Write-Host "`n[1/3] Verificando estado del motor Docker..." -ForegroundColor Yellow
$dockerRunning = $false
try {
    $null = docker info 2>&1
    if ($LASTEXITCODE -eq 0) {
        $dockerRunning = $true
    }
} catch {
    $dockerRunning = $false
}

if (-not $dockerRunning) {
    Write-Host "Docker no está corriendo. Intentando iniciar Docker Desktop..." -ForegroundColor Warning
    $dockerPath = "${env:ProgramFiles}\Docker\Docker\Docker Desktop.exe"
    if (Test-Path $dockerPath) {
        Start-Process -FilePath $dockerPath
        Write-Host "Esperando a que Docker Desktop se inicie..." -ForegroundColor Yellow
        $timeout = 60
        $elapsed = 0
        while (-not $dockerRunning -and $elapsed -lt $timeout) {
            Start-Sleep -Seconds 3
            $elapsed += 3
            try {
                $null = docker info 2>&1
                if ($LASTEXITCODE -eq 0) { $dockerRunning = $true }
            } catch {}
        }
        if (-not $dockerRunning) {
            Write-Error "Tiempo de espera agotado. Por favor, inicia Docker Desktop manualmente."
        }
    } else {
        Write-Error "Docker Desktop no fue encontrado en $dockerPath. Por favor inícialo manualmente."
    }
}
Write-Host "[OK] Docker motor está activo." -ForegroundColor Green

# 2. Levantar servicios dependientes con Docker Compose (db, redis, minio, pgadmin)
Write-Host "`n[2/3] Levantando servicios base en contenedores (db, redis, minio, pgadmin)..." -ForegroundColor Yellow
if (-not (Test-Path ".env")) {
    if (Test-Path ".env.example") {
        Copy-Item .env.example .env
        Write-Host "Archivo .env creado desde .env.example" -ForegroundColor Gray
    }
}

docker compose up -d db redis minio pgadmin
if ($LASTEXITCODE -ne 0) {
    Write-Error "Fallo al levantar los servicios base con Docker Compose."
}
Write-Host "[OK] Servicios db, redis, minio y pgadmin activos." -ForegroundColor Green

# 3. Levantar Master API y Master Web localmente
Write-Host "`n[3/3] Iniciando Master API y Master Web de manera local..." -ForegroundColor Yellow

$rootPath = Resolve-Path "$PSScriptRoot\..\.."
$apiPath = "$rootPath\apps\master-api"
$webPath = "$rootPath\apps\master-web"
$venvPath = "$rootPath\.venv\Scripts\python.exe"

# Iniciar Master API en segundo plano
Write-Host "Iniciando Master Backend API en http://localhost:8000 ..." -ForegroundColor Cyan
Start-Process powershell -WindowStyle Hidden -ArgumentList "-Command", "cd '$apiPath'; `$env:PYTHONPATH='$apiPath'; & '$venvPath' -m uvicorn app.main:app --host 0.0.0.0 --port 8000"

# Iniciar Master Web en segundo plano
Write-Host "Iniciando Master Frontend Web en http://localhost:3000 ..." -ForegroundColor Cyan
Start-Process powershell -WindowStyle Hidden -ArgumentList "-Command", "cd '$webPath'; npm run dev"

# Esperar verificación de red
Start-Sleep -Seconds 3

Write-Host "`n==========================================================" -ForegroundColor Green
Write-Host " Entorno SaaS Master iniciado exitosamente de forma local! " -ForegroundColor Green
Write-Host " - Master API: http://localhost:8000 (Docs: http://localhost:8000/docs) " -ForegroundColor Green
Write-Host " - Master Web: http://localhost:3000                        " -ForegroundColor Green
Write-Host "==========================================================" -ForegroundColor Green

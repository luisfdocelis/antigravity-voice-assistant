# PowerShell script para ejecutar pruebas locales de workflows con act
param(
    [string]$Event = "pr",
    [switch]$List,
    [switch]$DryRun,
    [string]$Job
)

$ErrorActionPreference = "Stop"

Write-Host "=============================================" -ForegroundColor Cyan
Write-Host " Pruebas Locales de Workflows con 'act'      " -ForegroundColor Cyan
Write-Host "=============================================" -ForegroundColor Cyan

if (-not (Get-Command act -ErrorAction SilentlyContinue)) {
    Write-Error "El comando 'act' no está instalado en el sistema. Instálalo para continuar."
}

if ($List) {
    Write-Host "`n[act] Listando flujos de trabajo y trabajos disponibles..." -ForegroundColor Yellow
    act -l
    exit 0
}

$actArgs = @()

if ($DryRun) {
    $actArgs += "-n"
}

if ($Job) {
    $actArgs += "-j", $Job
}

switch ($Event.ToLower()) {
    { $_ -in "pr", "pull_request" } {
        $eventFile = ".github/events/pull_request.json"
        $eventName = "pull_request"
        Write-Host "`n[act] Simulando evento Pull Request..." -ForegroundColor Yellow
    }
    { $_ -in "dev", "development" } {
        $eventFile = ".github/events/push_development.json"
        $eventName = "push"
        Write-Host "`n[act] Simulando merge/push a 'development'..." -ForegroundColor Yellow
    }
    { $_ -in "master", "main" } {
        $eventFile = ".github/events/push_master.json"
        $eventName = "push"
        Write-Host "`n[act] Simulando merge/push a 'master'..." -ForegroundColor Yellow
    }
    default {
        Write-Error "Evento '$Event' no reconocido. Opciones válidas: pr, dev, master"
    }
}

if (Test-Path $eventFile) {
    act $eventName -e $eventFile @actArgs
} else {
    act $eventName @actArgs
}

Write-Host "`n[OK] Ejecución de 'act' completada exitosamente." -ForegroundColor Green

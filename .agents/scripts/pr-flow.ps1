param(
    [string]$Title,
    [string]$Body,
    [string]$Base = "development",
    [switch]$Draft,
    [switch]$NoMerge
)

$ErrorActionPreference = "Stop"

function Ensure-GhCli {
    if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
        throw "GitHub CLI (gh) no esta instalado o no esta en PATH."
    }
}

function Ensure-ValidBranch {
    $branch = (git rev-parse --abbrev-ref HEAD).Trim()
    if ($branch -in @("master", "development", "main")) {
        throw "No se permite operar PR directo desde '$branch'. Usa una rama dedicada."
    }
    return $branch
}

function Get-CurrentPrUrl {
    try {
        $view = gh pr view --json url 2>$null | ConvertFrom-Json
        return $view.url
    } catch {
        return $null
    }
}

function Prompt-IfEmpty {
    param([string]$Value, [string]$Message)
    if ([string]::IsNullOrWhiteSpace($Value)) {
        return (Read-Host $Message)
    }
    return $Value
}

function Select-MergeMethod {
    Write-Host "" 
    Write-Host "Selecciona estrategia de merge:" -ForegroundColor Cyan
    Write-Host "1) Squash" -ForegroundColor Yellow
    Write-Host "2) Rebase" -ForegroundColor Yellow
    Write-Host "3) Merge commit" -ForegroundColor Yellow
    Write-Host "4) Cancelar" -ForegroundColor Yellow

    $choice = Read-Host "Opcion"
    switch ($choice) {
        "1" { return "--squash" }
        "2" { return "--rebase" }
        "3" { return "--merge" }
        default { return $null }
    }
}

Ensure-GhCli
$branch = Ensure-ValidBranch

$prUrl = Get-CurrentPrUrl
if (-not $prUrl) {
    $Title = Prompt-IfEmpty -Value $Title -Message "Titulo del PR"
    if ([string]::IsNullOrWhiteSpace($Title)) {
        throw "El titulo del PR es obligatorio."
    }

    $createArgs = @("pr", "create", "--base", $Base, "--head", $branch, "--title", $Title)
    if (-not [string]::IsNullOrWhiteSpace($Body)) {
        $createArgs += @("--body", $Body)
    } else {
        $createArgs += @("--body", "PR creado por script de automatizacion")
    }
    if ($Draft) {
        $createArgs += "--draft"
    }

    & gh @createArgs
    if ($LASTEXITCODE -ne 0) {
        throw "No se pudo crear el PR."
    }

    $prUrl = Get-CurrentPrUrl
}

Write-Host "PR activo: $prUrl" -ForegroundColor Green

Write-Host "" 
Write-Host "Monitoreando checks del PR..." -ForegroundColor Cyan
$checksOutput = & gh pr checks --watch 2>&1
$checksExitCode = $LASTEXITCODE
$checksText = ($checksOutput | Out-String)
Write-Host $checksText

if ($NoMerge) {
    Write-Host ""
    Write-Host "✔ PR creado y verificado: $prUrl" -ForegroundColor Green
    Write-Host "✔ [NoMerge activo]: El PR permanecerá abierto para revisión asíncrona." -ForegroundColor Green
    exit 0
}

if ($checksExitCode -ne 0) {
    if ($checksText -match "no checks reported") {
        $continueWithoutChecks = Read-Host "No hay checks configurados/reportados. Continuar con merge? (y/n)"
        if ($continueWithoutChecks -notmatch "^[Yy]") {
            Write-Host "Merge cancelado por ausencia de checks." -ForegroundColor Yellow
            exit 0
        }
    } else {
        Write-Host "Checks en estado no exitoso. Extrayendo logs de fallos de GitHub Actions..." -ForegroundColor Red
        & gh run view --log-failed 2>&1 | Write-Host -ForegroundColor Yellow
        exit 1
    }
}

$mergeFlag = Select-MergeMethod
if (-not $mergeFlag) {
    Write-Host "Merge cancelado por usuario." -ForegroundColor Yellow
    exit 0
}

$deleteBranch = Read-Host "Eliminar rama remota al finalizar? (la rama local debe eliminarse manualmente) (y/n)"
$mergeArgs = @("pr", "merge", $mergeFlag)
if ($deleteBranch -match "^[Yy]") {
    $mergeArgs += "--delete-branch"
}

& gh @mergeArgs
if ($LASTEXITCODE -ne 0) {
    throw "Fallo al ejecutar el merge del PR."
}

Write-Host "Merge completado con estrategia $mergeFlag" -ForegroundColor Green

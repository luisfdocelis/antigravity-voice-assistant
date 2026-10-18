param(
    [Parameter(Mandatory = $true)]
    [ValidateSet(
        "feature",
        "codigo",
        "documentacion",
        "configuracion",
        "feat",
        "fix",
        "doc",
        "chore",
        "test",
        "refactor",
        "release",
        "patch",
        "hotfix",
        "perf",
        "ci",
        "build",
        "sec",
        "deps",
        "revert"
    )]
    [string]$Type,

    [Parameter(Mandatory = $true)]
    [string]$Name,

    [switch]$SkipPull
    [switch]$SkipPull,

    [string]$From
)

$ErrorActionPreference = "Stop"

function Resolve-Prefix {
    param([string]$BranchType)

    switch ($BranchType) {
        "feature" { return "feat" }
        "codigo" { return "fix" }
        "documentacion" { return "doc" }
        "configuracion" { return "chore" }
        default { return $BranchType }
    }
}

function To-Slug {
    param([string]$InputName)

    $slug = $InputName.ToLower()
    $slug = $slug -replace "[^a-z0-9]+", "-"
    $slug = $slug -replace "(^-+)|(-+$)", ""
    $slug = $slug -replace "-{2,}", "-"

    if ([string]::IsNullOrWhiteSpace($slug)) {
        throw "El nombre no contiene caracteres validos para un branch."
    }

    return $slug
}

if (-not (Test-Path ".git")) {
    throw "Este comando debe ejecutarse en la raiz del repositorio."
}

# Verificar si .git es escribible
try {
    $testFile = Join-Path ".git" ".write_test_$([System.Guid]::NewGuid().ToString('N'))"
    [System.IO.File]::WriteAllText($testFile, "")
    Remove-Item -Force $testFile
} catch {
    throw "Error: El directorio .git está en modo solo lectura (Read-only file system). Verifica que no estés ejecutando en un sandbox aislado o contenedor sin permisos de escritura."
}

$prefix = Resolve-Prefix -BranchType $Type
$slug = To-Slug -InputName $Name
$targetBranch = "$prefix/$slug"

$dirty = git status --porcelain
if ($dirty) {
    throw "Hay cambios sin commit. Haz commit o stash antes de crear una nueva rama automatica."
}

$currentBranch = (git rev-parse --abbrev-ref HEAD).Trim()

# Detección contextual de rama base
$baseBranch = "development"
if (-not [string]::IsNullOrWhiteSpace($From)) {
    $baseBranch = $From
    Write-Host "[CONTINUIDAD] Usando rama base explícita: '$baseBranch'." -ForegroundColor Cyan
} elseif (($prefix -eq "feat" -or $prefix -eq "fix") -and $currentBranch -eq "doc/$slug") {
    $baseBranch = $currentBranch
    Write-Host "[CONTINUIDAD] Rama documental activa '$currentBranch' detectada." -ForegroundColor Cyan
    Write-Host "              Desprendiendo rama de desarrollo '$targetBranch' a partir de ella." -ForegroundColor Cyan
} elseif (($prefix -eq "feat" -or $prefix -eq "fix") -and (git branch --list "doc/$slug")) {
    $baseBranch = "doc/$slug"
    Write-Host "[CONTINUIDAD] Rama documental previa 'doc/$slug' detectada en el repositorio." -ForegroundColor Cyan
    Write-Host "              Desprendiendo rama de desarrollo '$targetBranch' a partir de ella." -ForegroundColor Cyan
}

if ($currentBranch -ne $baseBranch) {
    git checkout $baseBranch
}

if ($baseBranch -eq "development" -and (-not $SkipPull)) {
    Write-Host "Sincronizando 'development' con origin/development..."
    try {
        git pull origin development
    } catch {
        Write-Warning "No se pudo sincronizar con origin/development (sin conexión o remote inaccesible). Continuando con la rama local 'development'..."
    }
}

$existingBranch = git branch --list $targetBranch
if ($existingBranch) {
    throw "La rama '$targetBranch' ya existe. Elige otro nombre."
}

git checkout -b $targetBranch

Write-Host "Rama creada: $targetBranch" -ForegroundColor Green
Write-Host "Rama creada: $targetBranch (base: $baseBranch)" -ForegroundColor Green

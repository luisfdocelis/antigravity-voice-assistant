# ==============================================================================
# CrowKit Verification Script (PowerShell) 🦅
# Suite de Verificación Automática Local Pre-Push / Pre-Merge
# ==============================================================================

param (
    [Parameter(Position=0)]
    [string]$Command,
    [Parameter(Position=1)]
    [string]$SubCommand,
    [switch]$DocsOnly,
    [switch]$Full,
    [switch]$Act,
    [switch]$Sonar,
    [switch]$InstallSonar,
    [string[]]$Docker,
    [string[]]$Local,
    [string]$Config = "verify.config",
    [switch]$InitConfig,
    [switch]$Help
)

$ErrorActionPreference = "Stop"

$ValidJobs = @("test", "docs", "cppcheck", "sanitizers", "sonar", "docker-dry-run")

function Normalize-JobName([string]$name) {
    $n = $name.Trim().ToLower()
    switch ($n) {
        { $_ -in @("test", "tests", "build", "ctest") } { return "test" }
        { $_ -in @("doc", "docs", "mkdocs", "documentation") } { return "docs" }
        { $_ -in @("cppcheck", "lint", "static") } { return "cppcheck" }
        { $_ -in @("sanitizer", "sanitizers", "test-sanitizers", "asan", "ubsan") } { return "sanitizers" }
        { $_ -in @("sonar", "sonarqube", "sonar-scan") } { return "sonar" }
        { $_ -in @("docker", "docker-dry-run", "docker-dryrun", "container", "containers") } { return "docker-dry-run" }
        default { return $n }
    }
}

function Show-Help() {
    Write-Host "Uso: .\verify.ps1 [OPCIONES]" -ForegroundColor Cyan
    Write-Host "     .\verify.ps1 update config -Docker '...' -Local '...'" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Opciones de Ejecucion Granular (Local vs Docker):" -ForegroundColor Yellow
    Write-Host "  -Docker <jobs>       Ejecuta los jobs especificados en Docker via act (ej: -Docker test,cppcheck)"
    Write-Host "  -Local <jobs>        Ejecuta los jobs especificados en host local (ej: -Local docs,test)"
    Write-Host ""
    Write-Host "Gestion de Archivo de Configuracion (verify.config):" -ForegroundColor Yellow
    Write-Host "  -Config <ruta>       Carga la configuracion de jobs desde verify.config (o la ruta provista)"
    Write-Host "  -InitConfig          Crea el archivo verify.config a partir de verify.config.example"
    Write-Host "  update config        Actualiza programaticamente verify.config por CLI:"
    Write-Host "                       .\verify.ps1 update config -Docker 'cppcheck, docker-dry-run' -Local 'docs, test'"
    Write-Host ""
    Write-Host "Modos Rapidos y Suites Estandar:" -ForegroundColor Yellow
    Write-Host "  -DocsOnly            Verificacion rapida documental exclusivamente (~10-15s)"
    Write-Host "  -Full                Verificacion completa con Helm y Terraform"
    Write-Host "  -Act                 Fuerza la ejecucion de pruebas con act en contenedor Docker"
    Write-Host "  -Sonar               Ejecuta escaneo de codigo con SonarQube"
    Write-Host "  -InstallSonar        Ejecuta el instalador oficial de sonarqube-cli"
    Write-Host "  -Help                Muestra este mensaje de ayuda"
    Write-Host ""
    Write-Host "Catalogo de Jobs Disponibles:" -ForegroundColor Yellow
    Write-Host "  test                 Compilacion C++20 Release con CMake y Pruebas CTest"
    Write-Host "  docs                 Validacion documental (MkDocs, Doxygen, OpenAPI, i18n)"
    Write-Host "  cppcheck             Analisis estatico de codigo C++ con Cppcheck"
    Write-Host "  sanitizers           Analisis dinamico de memoria con ASan y UBSan"
    Write-Host "  sonar                Analisis de calidad de codigo y SAST con SonarQube"
    Write-Host "  docker-dry-run       Validacion de build y hardening de imagenes Docker"
}

if ($Help) {
    Show-Help
    exit 0
}

# Subcomando: config o update config
if ($Command -eq "config" -or ($Command -eq "update" -and $SubCommand -eq "config")) {
    $upLocal = @()
    $upDocker = @()

    if ($Local) {
        $upLocal = @($Local | ForEach-Object { $_ -split "[, ]+" } | Where-Object { $_ -ne "" } | ForEach-Object { Normalize-JobName $_ })
    }
    if ($Docker) {
        $upDocker = @($Docker | ForEach-Object { $_ -split "[, ]+" } | Where-Object { $_ -ne "" } | ForEach-Object { Normalize-JobName $_ })
    }

    # Si no se pasaron jobs, mostrar la configuración actual y salir inmediatamente
    if ($upLocal.Count -eq 0 -and $upDocker.Count -eq 0) {
        Write-Host "=============================================" -ForegroundColor Cyan
        Write-Host " Configuracion Actual de $Config             " -ForegroundColor Cyan
        Write-Host "=============================================" -ForegroundColor Cyan
        if (Test-Path $Config) {
            Get-Content $Config
        } else {
            Write-Host "No existe el archivo '$Config'." -ForegroundColor Yellow
            Write-Host "Ejecuta '.\verify.ps1 -InitConfig' o '.\verify.ps1 config -Docker ... -Local ...' para crearlo."
        }
        exit 0
    }

    foreach ($j in $upLocal) {
        if ($j -notin $ValidJobs) { Write-Error "Job desconocido en local: '$j'. Disponibles: $($ValidJobs -join ' ')"; exit 1 }
    }
    foreach ($j in $upDocker) {
        if ($j -notin $ValidJobs) { Write-Error "Job desconocido en docker: '$j'. Disponibles: $($ValidJobs -join ' ')"; exit 1 }
    }
    foreach ($lj in $upLocal) {
        if ($lj -in $upDocker) { Write-Error "Conflicto: El job '$lj' no puede asignarse simultaneamente a Local y Docker."; exit 1 }
    }

    $content = @"
# ==============================================================================
# CrowKit — Configuración de Verificación Local & Docker (verify.config) 🦅
# ==============================================================================
local=$($upLocal -join ',')
docker=$($upDocker -join ',')
"@
    Set-Content -Path $Config -Value $content -Encoding utf8
    Write-Host "[OK] Archivo '$Config' actualizado exitosamente." -ForegroundColor Green
    Write-Host "     • Local:  $($upLocal -join ',')"
    Write-Host "     • Docker: $($upDocker -join ',')"
    exit 0
}

# Inicialización de configuración
if ($InitConfig) {
    if (Test-Path "verify.config") {
        Write-Host "[AVISO] El archivo 'verify.config' ya existe." -ForegroundColor Yellow
        exit 0
    }
    if (Test-Path "verify.config.example") {
        Copy-Item -Path "verify.config.example" -Destination "verify.config"
        Write-Host "[OK] Archivo 'verify.config' creado a partir de 'verify.config.example'." -ForegroundColor Green
    } else {
        Set-Content -Path "verify.config" -Value "local=docs,test`ndocker=cppcheck,docker-dry-run,sonar" -Encoding utf8
        Write-Host "[OK] Archivo 'verify.config' creado." -ForegroundColor Green
    }
    exit 0
}

# Carga de verify.config si existe o si se pasó -Config
$ConfigLocalJobs = @()
$ConfigDockerJobs = @()

if ((Test-Path $Config) -and (-not $PSBoundParameters.ContainsKey('Docker')) -and (-not $PSBoundParameters.ContainsKey('Local')) -and (-not $DocsOnly) -and (-not $Full)) {
    Write-Host "[Config] Cargando configuracion desde '$Config'..." -ForegroundColor Cyan
    Get-Content $Config | ForEach-Object {
        $line = $_.Trim()
        if (-not $line.StartsWith("#") -and $line.Contains("=")) {
            $parts = $line.Split("=", 2)
            $key = $parts[0].Trim().ToLower()
            $rawVals = $parts[1].Split("#")[0].Trim()
            $vals = @($rawVals -split "[, ]+" | Where-Object { $_ -ne "" } | ForEach-Object { Normalize-JobName $_ })
            if ($key -eq "local") { $ConfigLocalJobs += $vals }
            elseif ($key -eq "docker") { $ConfigDockerJobs += $vals }
        }
    }
}

$FinalLocalJobs = @()
$FinalDockerJobs = @()

if ($Local) {
    $FinalLocalJobs = ($Local -split "[, ]+") | Where-Object { $_ -ne "" } | ForEach-Object { Normalize-JobName $_ }
} elseif ($ConfigLocalJobs.Count -gt 0) {
    $FinalLocalJobs = $ConfigLocalJobs
}

if ($Docker) {
    $FinalDockerJobs = ($Docker -split "[, ]+") | Where-Object { $_ -ne "" } | ForEach-Object { Normalize-JobName $_ }
} elseif ($ConfigDockerJobs.Count -gt 0) {
    $FinalDockerJobs = $ConfigDockerJobs
}

# Ejecución granular explícita
if ($FinalLocalJobs.Count -gt 0 -or $FinalDockerJobs.Count -gt 0) {
    foreach ($j in $FinalLocalJobs) {
        if ($j -notin $ValidJobs) { Write-Error "Job desconocido en local: '$j'. Disponibles: $($ValidJobs -join ' ')"; exit 1 }
    }
    foreach ($j in $FinalDockerJobs) {
        if ($j -notin $ValidJobs) { Write-Error "Job desconocido en docker: '$j'. Disponibles: $($ValidJobs -join ' ')"; exit 1 }
    }
    foreach ($lj in $FinalLocalJobs) {
        if ($lj -in $FinalDockerJobs) { Write-Error "Conflicto: El job '$lj' no puede asignarse simultaneamente a Local y Docker."; exit 1 }
    }

    Write-Host "=============================================" -ForegroundColor Cyan
    Write-Host " Ejecutando Mapeo Granular de Jobs           " -ForegroundColor Cyan
    Write-Host "=============================================" -ForegroundColor Cyan
    Write-Host "  • En Host Local: [$($FinalLocalJobs -join ' ')]"
    Write-Host "  • En Docker:     [$($FinalDockerJobs -join ' ')]`n"

    $results = @()

    foreach ($job in $FinalLocalJobs) {
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        $status = "SUCCESS"
        Write-Host "`n[LOCAL] Ejecutando: $job..." -ForegroundColor Yellow

        try {
            switch ($job) {
                "test" {
                    cmake -B build -S . -DCMAKE_BUILD_TYPE=Release
                    cmake --build build --config Release
                    ctest --test-dir build -C Release --output-on-failure
                }
                "docs" {
                    if (Test-Path "scripts/verify-docs.sh") { bash ./scripts/verify-docs.sh }
                }
                "cppcheck" {
                    if (Test-Path "scripts/run-cppcheck.sh") { bash ./scripts/run-cppcheck.sh }
                }
                "sanitizers" {
                    cmake -B build-sanitizers -S . -DCMAKE_BUILD_TYPE=Debug -DCROWKIT_BUILD_TESTS=ON -DCROWKIT_ENABLE_SANITIZERS=ON
                    cmake --build build-sanitizers -j2
                    ctest --test-dir build-sanitizers --output-on-failure
                }
                "sonar" {
                    if (Test-Path "scripts/run-sonar-local.sh") { bash ./scripts/run-sonar-local.sh }
                }
                "docker-dry-run" {
                    if (Test-Path "scripts/build-docker.sh") { bash ./scripts/build-docker.sh }
                }
            }
            if ($LASTEXITCODE -ne 0) { $status = "FAILED" }
        } catch {
            $status = "FAILED"
        }
        $sw.Stop()
        $results += [PSCustomObject]@{ Target = "LOCAL"; Job = $job; Status = $status; Duration = "$([math]::Round($sw.Elapsed.TotalSeconds))s" }
    }

    foreach ($job in $FinalDockerJobs) {
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        $status = "SUCCESS"
        Write-Host "`n[DOCKER] Ejecutando: $job (via contenedor)..." -ForegroundColor Yellow

        try {
            switch ($job) {
                "test" { bash ./.agents/scripts/test-workflow-act.sh --job test }
                "docs" { bash ./.agents/scripts/test-workflow-act.sh --job build }
                "cppcheck" { bash ./.agents/scripts/test-workflow-act.sh --job cppcheck }
                "sanitizers" { bash ./.agents/scripts/test-workflow-act.sh --job test-sanitizers }
                "sonar" { bash ./.agents/scripts/test-workflow-act.sh --sonar }
                "docker-dry-run" { bash ./.agents/scripts/test-workflow-act.sh -e dev --job docker-dry-run }
            }
            if ($LASTEXITCODE -ne 0) { $status = "FAILED" }
        } catch {
            $status = "FAILED"
        }
        $sw.Stop()
        $results += [PSCustomObject]@{ Target = "DOCKER"; Job = $job; Status = $status; Duration = "$([math]::Round($sw.Elapsed.TotalSeconds))s" }
    }

    Write-Host "`n=====================================================" -ForegroundColor Cyan
    Write-Host "            RESUMEN DE EJECUCION CROWKIT             " -ForegroundColor Cyan
    Write-Host "=====================================================" -ForegroundColor Cyan
    $hasFailure = $false
    foreach ($r in $results) {
        $icon = if ($r.Status -eq "SUCCESS") { "OK APROBADO" } else { $hasFailure = $true; "FALLO" }
        $color = if ($r.Status -eq "SUCCESS") { "Green" } else { "Red" }
        Write-Host ("  [{0,-6}] {1,-16} -> {2} ({3})" -f $r.Target, $r.Job, $icon, $r.Duration) -ForegroundColor $color
    }
    Write-Host "=====================================================" -ForegroundColor Cyan
    if ($hasFailure) {
        Write-Host "  ESTADO GLOBAL: FALLARON ALGUNOS QUALITY GATES     " -ForegroundColor Red
        Write-Host "=====================================================`n" -ForegroundColor Cyan
        exit 1
    } else {
        Write-Host "  ESTADO GLOBAL: TODOS LOS QUALITY GATES EN VERDE   " -ForegroundColor Green
        Write-Host "=====================================================`n" -ForegroundColor Cyan
        exit 0
    }
}

Write-Host "=============================================" -ForegroundColor Cyan
Write-Host " Iniciando Verificacion Pre-Push / Pre-Merge " -ForegroundColor Cyan
Write-Host " (Suite de Verificacion Automatica Local)    " -ForegroundColor Cyan
Write-Host "=============================================" -ForegroundColor Cyan

# Detección automática de cambios exclusivamente documentales
if (-not $Full -and -not $DocsOnly -and -not $Act -and -not $Sonar) {
    $baseBranch = "development"
    $branchExists = git rev-parse --verify $baseBranch 2>$null
    if (-not $branchExists) { $baseBranch = "main" }

    $branchDiff = git diff --name-only "$baseBranch...HEAD" 2>$null
    $workingDiff = git diff --name-only HEAD 2>$null
    $stagedDiff = git diff --name-only --cached 2>$null
    $untracked = git ls-files --others --exclude-standard 2>$null

    $allFiles = @($branchDiff; $workingDiff; $stagedDiff; $untracked) | Where-Object { $_ -ne "" } | Select-Object -Unique

    $isDocsOnly = $false
    if ($allFiles.Count -gt 0) {
        $isDocsOnly = $true
        foreach ($file in $allFiles) {
            if ($file -notmatch '^(docs/|.*\.md$|.*\.markdown$|.*\.txt$|LICENSE|Doxyfile|mkdocs\.yml|scripts/verify-.*\.sh|\.agents/skills/|\.agents/.*\.md|AGENTS\.md|verify\.config.*|\.gitignore)') {
                $isDocsOnly = $false
                break
            }
        }
    }

    $currentBranch = git rev-parse --abbrev-ref HEAD 2>$null
    if ($currentBranch -like "doc/*" -or $currentBranch -like "docs/*") {
        $DocsOnly = $true
        Write-Host "`n[AUTO-DETECT] Rama documental detectada ('$currentBranch')." -ForegroundColor Yellow
    } elseif ($isDocsOnly) {
        $DocsOnly = $true
        Write-Host "`n[AUTO-DETECT] Cambios detectados exclusivamente en documentacion." -ForegroundColor Yellow
    }
}

# Verificación Rápida Documental
if ($DocsOnly) {
    Write-Host "`n=============================================" -ForegroundColor Cyan
    Write-Host " Verificacion Rapida de Documentacion (Docs) " -ForegroundColor Cyan
    Write-Host "=============================================" -ForegroundColor Cyan

    if (Test-Path "scripts/verify-docs.sh") {
        bash ./scripts/verify-docs.sh
        if ($LASTEXITCODE -ne 0) { Write-Error "Fallo la verificacion de documentacion. Abortando." }
    } else {
        if (Test-Path "scripts/verify-i18n.sh") { bash ./scripts/verify-i18n.sh }
        if (Test-Path "scripts/verify-mkdocs.sh") { bash ./scripts/verify-mkdocs.sh }
        if (Test-Path "scripts/verify-openapi.sh") { bash ./scripts/verify-openapi.sh }
        if (Test-Path "scripts/verify-doxygen.sh") { bash ./scripts/verify-doxygen.sh }
    }

    Write-Host "`n=============================================" -ForegroundColor Green
    Write-Host " Documentacion al 100%! Verificacion exitosa. " -ForegroundColor Green
    Write-Host "=============================================" -ForegroundColor Green
    exit 0
}

# 1. Proyectos C / C++ (CMake)
if (Test-Path "CMakeLists.txt") {
    Write-Host "`n[CMake] Configurando y compilando proyecto C++..." -ForegroundColor Yellow
    cmake -B build -S . -DCMAKE_BUILD_TYPE=Release
    if ($LASTEXITCODE -ne 0) { Write-Error "Fallo en la configuracion CMake." }

    cmake --build build --config Release
    if ($LASTEXITCODE -ne 0) { Write-Error "Fallo en la compilacion con CMake." }
    Write-Host "[OK] Compilacion con CMake completada exitosamente." -ForegroundColor Green

    if (Test-Path "build/CTestTestfile.cmake") {
        Write-Host "`n[CTest] Ejecutando pruebas unitarias de CTest..." -ForegroundColor Yellow
        ctest --test-dir build -C Release --output-on-failure
        if ($LASTEXITCODE -ne 0) { Write-Error "Fallo en las pruebas de CTest." }
        Write-Host "[OK] Pruebas de CTest aprobadas." -ForegroundColor Green
    }
}

# 2. Plantillas Helm de Kubernetes
if ((Test-Path "scripts/verify-helm.sh") -and (Test-Path "templates/helm/crow-service")) {
    Write-Host "`n[Helm] Validando templates y linting de Helm..." -ForegroundColor Yellow
    bash ./scripts/verify-helm.sh
    if ($LASTEXITCODE -ne 0) { Write-Error "Fallo en la validacion de Helm." }
    Write-Host "[OK] Validaciones de Helm aprobadas." -ForegroundColor Green
}

# 3. Módulos de Terraform Multi-Cloud
if ((Test-Path "scripts/verify-terraform.sh") -and (Test-Path "terraform")) {
    Write-Host "`n[Terraform] Validando sintaxis y formato de Terraform Multi-Cloud..." -ForegroundColor Yellow
    bash ./scripts/verify-terraform.sh
    if ($LASTEXITCODE -ne 0) { Write-Error "Fallo en la validacion de Terraform." }
    Write-Host "[OK] Validaciones de Terraform aprobadas." -ForegroundColor Green
}

# 4. Validaciones de Documentación
if (Test-Path "scripts/verify-docs.sh") {
    Write-Host "`n[Docs] Validando suite de documentacion..." -ForegroundColor Yellow
    bash ./scripts/verify-docs.sh
    if ($LASTEXITCODE -ne 0) { Write-Error "Fallo en la suite de documentacion." }
    Write-Host "[OK] Suite de documentacion aprobada." -ForegroundColor Green
}

# 5. Pruebas Locales con Act
if ($Act) {
    if (Test-Path "$PSScriptRoot/test-workflow-act.ps1") {
        & "$PSScriptRoot/test-workflow-act.ps1" -Job test
        if ($LASTEXITCODE -ne 0) { Write-Error "Fallo en la prueba de workflows con act." }
        Write-Host "[OK] Pruebas de workflows con act aprobadas." -ForegroundColor Green
    }
}

# 6. SonarQube
if ($InstallSonar) {
    Write-Host "`n[Sonar] Instalando sonarqube-cli..." -ForegroundColor Yellow
    bash -c "curl -o- https://raw.githubusercontent.com/SonarSource/sonarqube-cli/refs/heads/master/user-scripts/install.sh | bash"
    exit 0
}

if ($Sonar) {
    if (Test-Path "scripts/run-sonar-local.sh") {
        bash ./scripts/run-sonar-local.sh
        if ($LASTEXITCODE -ne 0) { Write-Error "Fallo el analisis de SonarQube local." }
        Write-Host "[OK] Analisis de SonarQube completado exitosamente." -ForegroundColor Green
    }
}

Write-Host "`n=============================================" -ForegroundColor Green
Write-Host " Todo verde! Es seguro hacer merge y push.  " -ForegroundColor Green
Write-Host "=============================================" -ForegroundColor Green

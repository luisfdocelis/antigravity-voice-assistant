# Install Python BDD dependencies locally
Write-Host "Installing Python BDD dependencies..." -ForegroundColor Cyan
if (Test-Path ".venv") {
    & .venv/Scripts/pip install -r apps/e2e-python/requirements.txt
} else {
    python -m pip install -r apps/e2e-python/requirements.txt
}

# Install NPM dependencies for Playwright E2E locally
Write-Host "Installing NPM dependencies for E2E..." -ForegroundColor Cyan
Push-Location apps/e2e
try {
    npm install
    npx playwright install --with-deps
} finally {
    Pop-Location
}

# Ensure Docker containers are up
Write-Host "Ensuring Docker containers are up and updated..." -ForegroundColor Cyan
docker compose up -d --build

# Wait for Next.js web application (port 3000)
Write-Host "Waiting for Next.js web application (port 3000) to be ready..." -ForegroundColor Cyan
$maxAttempts = 60
for ($attempt = 1; $attempt -le $maxAttempts; $attempt++) {
    try {
        $response = Invoke-WebRequest -Uri "http://localhost:3000" -UseBasicParsing -TimeoutSec 2 -ErrorAction Stop
        if ($response.StatusCode -eq 200) { break }
    } catch {
        # Silent retry
    }
    if ($attempt -eq $maxAttempts) { throw "Timed out waiting for web at http://localhost:3000" }
    Start-Sleep -Seconds 2
}

# Wait for FastAPI backend API (port 8000)
Write-Host "Waiting for FastAPI backend API (port 8000) to be ready..." -ForegroundColor Cyan
$maxAttempts = 60
for ($attempt = 1; $attempt -le $maxAttempts; $attempt++) {
    try {
        $response = Invoke-WebRequest -Uri "http://localhost:8000/health" -UseBasicParsing -TimeoutSec 2 -ErrorAction Stop
        if ($response.StatusCode -eq 200) { break }
    } catch {
        # Silent retry
    }
    if ($attempt -eq $maxAttempts) { throw "Timed out waiting for API at http://localhost:8000/health" }
    Start-Sleep -Seconds 2
}

# Run E2E Playwright tests
Write-Host "Running E2E Playwright tests..." -ForegroundColor Green
Push-Location apps/e2e
try {
    npm test -- $args
} finally {
    Pop-Location
}

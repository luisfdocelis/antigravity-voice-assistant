#!/bin/bash
set -euo pipefail

# Install Python BDD dependencies locally
echo "Installing Python BDD dependencies..."
if [ -d ".venv" ]; then
  .venv/bin/pip install -r apps/e2e-python/requirements.txt
else
  python3 -m pip install -r apps/e2e-python/requirements.txt
fi

# Install NPM dependencies for Playwright E2E locally
echo "Installing NPM dependencies for E2E..."
cd apps/e2e
npm install
npx playwright install --with-deps
cd ../..

# Start Docker containers (rebuilding if configurations/requirements changed)
echo "Ensuring Docker containers are up and updated..."
docker compose up -d --build

wait_for_url() {
  local url="$1"
  local name="$2"
  local max_attempts="${3:-60}"
  local attempt=1

  echo "Waiting for ${name} to be ready..."
  until curl -fsS "$url" > /dev/null; do
    if [ "$attempt" -ge "$max_attempts" ]; then
      echo "Timed out waiting for ${name} at ${url}" >&2
      return 1
    fi
    attempt=$((attempt + 1))
    sleep 2
  done
}

wait_for_url "http://localhost:3000" "Next.js web application (port 3000)"
wait_for_url "http://localhost:8000/health" "FastAPI backend API (port 8000)"

echo "Running E2E Playwright tests..."
cd apps/e2e
npm test -- "$@"

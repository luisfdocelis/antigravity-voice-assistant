#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PYTHON_BIN="$(which python3 || echo "python")"

if [[ $# -eq 0 ]]; then
  echo "Uso: ./sync-chat-name.sh \"<Título Estandarizado>\" [--cid <UUID>]"
  echo "     ./sync-chat-name.sh --list"
  echo ""
  echo "Ejemplo:"
  echo "  ./sync-chat-name.sh \"Wave 3 - v2.4.0 - EPIC 27 - CK-2701: TestServer & TestClient\""
  exit 1
fi

"$PYTHON_BIN" "$SCRIPT_DIR/sync-chat-name.py" "$@"

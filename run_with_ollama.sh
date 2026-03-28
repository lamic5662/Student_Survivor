#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
OLLAMA_URL_FILE="${OLLAMA_URL_FILE:-$ROOT_DIR/ollama.url}"
if [ -f "$ROOT_DIR/.env" ]; then
  set -a
  # shellcheck disable=SC1091
  source "$ROOT_DIR/.env"
  set +a
fi

OLLAMA_HOST="${OLLAMA_HOST:-0.0.0.0:11434}"
OLLAMA_BASE_URL="${OLLAMA_BASE_URL:-}"
if [ -z "${OLLAMA_BASE_URL}" ] && [ -f "${OLLAMA_URL_FILE}" ]; then
  RAW_URL="$(grep -v '^[[:space:]]*$' "${OLLAMA_URL_FILE}" | head -n 1 | tr -d '\r')"
  if [[ "${RAW_URL}" == *=* ]]; then
    OLLAMA_BASE_URL="${RAW_URL#*=}"
  else
    OLLAMA_BASE_URL="${RAW_URL}"
  fi
fi
OLLAMA_BASE_URL="${OLLAMA_BASE_URL:-http://localhost:11434}"
OLLAMA_BIN="${OLLAMA_BIN:-}"

if [ -z "$OLLAMA_BIN" ]; then
  if command -v ollama >/dev/null 2>&1; then
    OLLAMA_BIN="$(command -v ollama)"
  elif [ -x "/opt/homebrew/bin/ollama" ]; then
    OLLAMA_BIN="/opt/homebrew/bin/ollama"
  elif [ -x "/usr/local/bin/ollama" ]; then
    OLLAMA_BIN="/usr/local/bin/ollama"
  fi
fi

if [ -z "$OLLAMA_BIN" ]; then
  echo "Ollama binary not found. Install Ollama first."
  exit 1
fi

is_up() {
  curl -sf --connect-timeout 1 --max-time 3 "$1/api/tags" 2>/dev/null | grep -q "\"models\""
}

start_ollama() {
  echo "Starting Ollama on ${OLLAMA_HOST}..."
  nohup env OLLAMA_HOST="${OLLAMA_HOST}" "$OLLAMA_BIN" serve >/tmp/ollama.log 2>&1 &
}

echo "Using OLLAMA_BASE_URL=${OLLAMA_BASE_URL}"
echo "Using OLLAMA_BIN=${OLLAMA_BIN}"

if ! is_up "${OLLAMA_BASE_URL}" && ! is_up "http://localhost:11434"; then
  echo "Ollama not reachable. Restarting..."
  if command -v lsof >/dev/null 2>&1; then
    PIDS="$(lsof -ti tcp:11434 || true)"
    if [ -n "$PIDS" ]; then
      kill $PIDS || true
      sleep 1
    fi
  fi
  if command -v pkill >/dev/null 2>&1; then
    pkill -f "ollama serve" || true
  fi
  start_ollama
  for i in $(seq 1 10); do
    if is_up "http://localhost:11434" || is_up "${OLLAMA_BASE_URL}"; then
      break
    fi
    sleep 1
  done
  if ! is_up "http://localhost:11434" && ! is_up "${OLLAMA_BASE_URL}"; then
    echo "Ollama failed to start. Check /tmp/ollama.log"
    tail -n 50 /tmp/ollama.log || true
    exit 1
  fi
fi

flutter run "$@"

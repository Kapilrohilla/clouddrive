#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BACKEND_DIR="$ROOT_DIR/backend"
FRONTEND_DIR="$ROOT_DIR/frontend"
COMPOSE_FILE="$BACKEND_DIR/docker-compose.yaml"

BACKEND_PORT="${BACKEND_PORT:-8000}"
FRONTEND_PORT="${FRONTEND_PORT:-5173}"

cleanup() {
  echo
  echo "Stopping dev servers..."
  [[ -n "${BACKEND_PID:-}" ]] && kill "$BACKEND_PID" 2>/dev/null || true
  [[ -n "${FRONTEND_PID:-}" ]] && kill "$FRONTEND_PID" 2>/dev/null || true
}

trap cleanup EXIT INT TERM

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Error: '$1' is required but not installed." >&2
    exit 1
  fi
}

require_command docker
require_command python3
require_command npm

cd "$ROOT_DIR"

if [[ -f .gitmodules ]]; then
  git submodule update --init --recursive
fi

echo "Starting infrastructure (Postgres, Redis, RabbitMQ)..."
docker compose -f "$COMPOSE_FILE" up -d

echo "Waiting for Postgres..."
until docker compose -f "$COMPOSE_FILE" exec -T postgres pg_isready -U postgres >/dev/null 2>&1; do
  sleep 1
done

if [[ ! -f "$BACKEND_DIR/.env" ]]; then
  echo "Creating backend/.env from .env.example"
  cp "$BACKEND_DIR/.env.example" "$BACKEND_DIR/.env"
fi

if [[ ! -d "$BACKEND_DIR/.venv" ]]; then
  echo "Creating Python virtual environment..."
  python3 -m venv "$BACKEND_DIR/.venv"
fi

echo "Installing backend dependencies..."
# shellcheck disable=SC1091
source "$BACKEND_DIR/.venv/bin/activate"
pip install -q -r "$BACKEND_DIR/requirements.txt"

if [[ ! -f "$FRONTEND_DIR/.env" ]]; then
  echo "Creating frontend/.env from .env.example"
  cp "$FRONTEND_DIR/.env.example" "$FRONTEND_DIR/.env"
fi

if [[ ! -d "$FRONTEND_DIR/node_modules" ]]; then
  echo "Installing frontend dependencies..."
  npm install --legacy-peer-deps --prefix "$FRONTEND_DIR"
fi

echo "Starting backend on http://127.0.0.1:${BACKEND_PORT}"
(
  cd "$BACKEND_DIR"
  source .venv/bin/activate
  fastapi dev app/main.py --host 127.0.0.1 --port "$BACKEND_PORT"
) &
BACKEND_PID=$!

echo "Starting frontend on http://127.0.0.1:${FRONTEND_PORT}"
(
  cd "$FRONTEND_DIR"
  npm run dev -- --host 127.0.0.1 --port "$FRONTEND_PORT"
) &
FRONTEND_PID=$!

echo
echo "CloudDrive is running:"
echo "  Frontend:  http://127.0.0.1:${FRONTEND_PORT}"
echo "  Backend:   http://127.0.0.1:${BACKEND_PORT}"
echo "  API docs:  http://127.0.0.1:${BACKEND_PORT}/docs"
echo
echo "Press Ctrl+C to stop the dev servers (Docker services keep running)."

wait "$BACKEND_PID" "$FRONTEND_PID"

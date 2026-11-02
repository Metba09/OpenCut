#!/usr/bin/env bash
# Démarre l'API (wrangler dev / workerd local) et vérifie /health, puis l'arrête.
set -euo pipefail
. "$(dirname "$0")/_env.sh"
cd "$ROOT/apps/api"
PORT="${PORT:-8787}"
wrangler dev --port "$PORT" --ip 127.0.0.1 >/tmp/opencut-smoke.log 2>&1 &
PID=$!
trap 'kill $PID 2>/dev/null || true' EXIT
for _ in $(seq 1 40); do
  curl -sf "http://127.0.0.1:$PORT/health" && { echo; log "smoke API OK"; exit 0; }
  sleep 1
done
tail -20 /tmp/opencut-smoke.log; fail "l'API n'a pas répondu sur :$PORT"

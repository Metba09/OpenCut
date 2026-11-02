#!/usr/bin/env bash
# Vérifications à lancer À LA MAIN avant de conclure (remplace les hooks) :
# garde hors-réseau, typecheck, tests web+API, build web, build API. Code != 0 si échec.
set -uo pipefail
. "$(dirname "$0")/_env.sh"
cd "$ROOT"
[ -x node_modules/.bin/vite ] || bash scripts/setup.sh

FAILED=()
step() { local name="$1"; shift; log "▶ $name"; if "$@"; then log "✔ $name"; else FAILED+=("$name"); fi; }

step "garde hors-réseau"      bash scripts/verify-offline.sh
step "typecheck web"          npm --workspace apps/web exec -- tsc --noEmit
step "tests web"              npm --workspace apps/web run test --silent
step "tests API"              npm --workspace apps/api run test --silent
step "build web"              npm --workspace apps/web run build --silent
step "build API (dry-run)"    bash -c 'cd apps/api && wrangler deploy --dry-run --outdir "${TMPDIR:-/tmp}/opencut-api-dist" >/dev/null'

echo
if [ ${#FAILED[@]} -eq 0 ]; then log "TOUT EST VERT"; else fail "échecs : ${FAILED[*]}"; fi

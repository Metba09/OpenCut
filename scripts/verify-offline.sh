#!/usr/bin/env bash
# Garde : aucune ressource externe chargée par le code applicatif (polices CDN, scripts, images distantes).
# Les liens de documentation, schémas JSON ($schema) et commentaires sont tolérés.
set -euo pipefail
. "$(dirname "$0")/_env.sh"
cd "$ROOT"
PATTERN='(fonts\.(googleapis|gstatic)\.com|cdn\.jsdelivr|unpkg\.com|cdnjs\.cloudflare|assets\.opencut\.app)'
if grep -rnE "$PATTERN" apps/web/src apps/web/public apps/api/src 2>/dev/null; then
  fail "ressource externe détectée dans le code applicatif (voir ci-dessus)."
fi
log "aucune ressource externe dans apps/web et apps/api"

#!/usr/bin/env bash
# Installation idempotente, sans saisie, sans réseau :
#   1. restaure le cache npm vendoré si besoin
#   2. npm ci --offline (versions exactes de package-lock.json)
#   3. exécute les scripts d'install des seuls paquets binaires (esbuild, workerd)
#   4. crée .env depuis .env.example
# Relançable à volonté : ne refait rien si package-lock.json n'a pas changé.
set -euo pipefail
. "$(dirname "$0")/_env.sh"
cd "$ROOT"

command -v node >/dev/null || fail "node introuvable."
node -e 'const [a,b]=process.versions.node.split(".").map(Number); process.exit(a>22||(a===22&&b>=12)||(a===20&&b>=19)?0:1)' \
  || fail "Node $(node -v) trop ancien : Vite 8 exige >= 20.19 ou >= 22.12."

STAMP="node_modules/.opencut-setup-stamp"
WANT="$(sha256sum package-lock.json | cut -d' ' -f1)"
if [ -f "$STAMP" ] && [ "$(cat "$STAMP")" = "$WANT" ] && [ -x node_modules/.bin/vite ]; then
  log "dépendances déjà installées (lockfile inchangé)"
else
  [ -f "$VENDOR_DIR/npm-cache/.restored" ] || bash "$ROOT/scripts/restore-vendor.sh"
  log "npm ci --offline"
  npm ci --offline --ignore-scripts --cache "$VENDOR_DIR/npm-cache" --no-audit --no-fund --loglevel=error
  log "scripts d'installation des binaires natifs (esbuild, workerd)"
  npm rebuild esbuild workerd --offline --cache "$VENDOR_DIR/npm-cache" --loglevel=error >/dev/null 2>&1 || true
  esbuild --version >/dev/null || fail "binaire esbuild inutilisable."
  echo "$WANT" > "$STAMP"
fi

[ -f .env ] || { cp .env.example .env; log ".env créé depuis .env.example"; }
log "setup terminé : node $(node -v), vite $(vite --version | awk '{print $1}')"

#!/usr/bin/env bash
# MAINTENANCE (avec réseau, une fois) : fabrique le bundle npm hermétique à partir de package-lock.json.
# Sortie : $OUT/opencut-npm-cache.tar.part-* (morceaux de 40 Mo) + SHA256SUMS.
#   OUT=<dossier>  (défaut : ./bundle)
set -euo pipefail
. "$(dirname "$0")/_env.sh"
cd "$ROOT"
OUT="${OUT:-$ROOT/bundle}"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

log "cache npm vierge, rempli depuis le lockfile (réseau requis)"
mkdir -p "$WORK/vendor" "$OUT"
rm -rf node_modules
npm ci --ignore-scripts --cache "$WORK/vendor/npm-cache" --no-audit --no-fund --loglevel=error
log "emballage ($(du -sh "$WORK/vendor/npm-cache" | cut -f1))"
rm -f "$OUT"/opencut-npm-cache.tar.part-* "$OUT"/SHA256SUMS
tar -C "$WORK/vendor" -cz npm-cache | split -b 40M -d -a 2 - "$OUT/opencut-npm-cache.tar.part-"
( cd "$OUT" && sha256sum opencut-npm-cache.tar.part-* > SHA256SUMS && cat SHA256SUMS )
log "bundle écrit dans $OUT"

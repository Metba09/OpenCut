#!/usr/bin/env bash
# Reconstitue vendor/npm-cache à partir des morceaux opencut-npm-cache.tar.part-* :
# vérifie SHA256SUMS, concatène, extrait. Idempotent. Aucun réseau.
#   OPENCUT_BUNDLE_DIR=<dossier des morceaux>  (défaut : ./vendor ou ./bundle)
set -euo pipefail
. "$(dirname "$0")/_env.sh"

[ -d "$VENDOR_DIR/npm-cache" ] && [ -f "$VENDOR_DIR/npm-cache/.restored" ] && { log "cache npm déjà restauré"; exit 0; }

SRC=""
for d in "${OPENCUT_BUNDLE_DIR:-}" "$VENDOR_DIR" "$ROOT/bundle" "$ROOT"; do
  [ -n "$d" ] && ls "$d"/opencut-npm-cache.tar.part-* >/dev/null 2>&1 && { SRC="$d"; break; }
done
if [ -z "$SRC" ]; then
  log "bundle local introuvable : téléchargement depuis le fork"
  bash "$ROOT/scripts/fetch-bundle.sh" "$ROOT/bundle" || fail "morceaux opencut-npm-cache.tar.part-* introuvables (voir OPENCUT_BUNDLE_DIR)."
  SRC="$ROOT/bundle"
fi

log "vérification des empreintes dans $SRC"
( cd "$SRC" && sha256sum -c SHA256SUMS ) || fail "empreinte invalide : bundle corrompu."

mkdir -p "$VENDOR_DIR"
log "extraction du cache npm vers $VENDOR_DIR/npm-cache"
cat "$SRC"/opencut-npm-cache.tar.part-* | tar -xz -C "$VENDOR_DIR"
touch "$VENDOR_DIR/npm-cache/.restored"
log "cache npm prêt ($(du -sh "$VENDOR_DIR/npm-cache" | cut -f1))"

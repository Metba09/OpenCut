#!/usr/bin/env bash
# Télécharge le bundle npm (cache hermétique) depuis la branche `sandbox-bundle` du fork : dépôt public, aucun jeton.
# Seul accès réseau : github.com. Appelé automatiquement par restore-vendor.sh si les morceaux manquent.
#   OPENCUT_FORK=<url git>   (défaut : https://github.com/Metba09/OpenCut.git)
#   OPENCUT_BUNDLE_BRANCH=<branche>   (défaut : sandbox-bundle)
set -euo pipefail
. "$(dirname "$0")/_env.sh"
FORK="${OPENCUT_FORK:-https://github.com/Metba09/OpenCut.git}"
BRANCH="${OPENCUT_BUNDLE_BRANCH:-sandbox-bundle}"
[ "${OPENCUT_OFFLINE:-0}" = "1" ] && fail "OPENCUT_OFFLINE=1 : téléchargement du bundle interdit."
DEST="${1:-$ROOT/bundle}"
mkdir -p "$DEST"
if [ -f "$DEST/SHA256SUMS" ] && ( cd "$DEST" && sha256sum -c SHA256SUMS >/dev/null 2>&1 ); then
  log "bundle déjà présent dans $DEST"; exit 0
fi
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
log "téléchargement du bundle (branche $BRANCH, ~146 Mo)"
git clone -q --depth 1 --single-branch --branch "$BRANCH" "$FORK" "$TMP/b" 2>&1 | tail -2 || true
[ -f "$TMP/b/SHA256SUMS" ] || fail "branche $BRANCH introuvable ou vide dans $FORK (voir OPENCUT_FORK / OPENCUT_BUNDLE_BRANCH)."
cp "$TMP"/b/opencut-npm-cache.tar.part-* "$TMP/b/SHA256SUMS" "$DEST/"
( cd "$DEST" && sha256sum -c SHA256SUMS >/dev/null ) || fail "empreinte invalide : bundle corrompu."
log "bundle prêt dans $DEST"

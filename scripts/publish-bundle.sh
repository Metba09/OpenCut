#!/usr/bin/env bash
# MAINTENANCE : publie ./bundle (make vendor) sur la branche orpheline `sandbox-bundle` du fork. Jeton requis (jamais écrit sur disque) :
#   GH_PUSH_TOKEN=<pat fine-grained, Contents RW sur le fork> bash scripts/publish-bundle.sh
set -euo pipefail
. "$(dirname "$0")/_env.sh"
: "${GH_PUSH_TOKEN:?définir GH_PUSH_TOKEN}"
FORK="${OPENCUT_FORK:-https://github.com/Metba09/OpenCut.git}"
BRANCH="${OPENCUT_BUNDLE_BRANCH:-sandbox-bundle}"
[ -f "$ROOT/bundle/SHA256SUMS" ] || fail "./bundle absent : lancer make vendor."
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
cp "$ROOT"/bundle/opencut-npm-cache.tar.part-* "$ROOT/bundle/SHA256SUMS" "$TMP/"
cat > "$TMP/README.md" << 'MD'
# sandbox-bundle
Cache npm hermétique (linux-x64) pour OpenCut en sandbox Claude.ai. Branche orpheline : aucun code ici.
Utilisé par `scripts/fetch-bundle.sh` de la branche `sandbox-skill`. Régénéré par `make vendor` + `scripts/publish-bundle.sh`.
Contenu : paquets npm publics du `package-lock.json` ; vérifier avec `sha256sum -c SHA256SUMS`.
MD
cd "$TMP" && git init -q -b "$BRANCH" && git add -A
git -c user.name=claude -c user.email=noreply@anthropic.com commit -qm "bundle npm hermétique ($(date +%F))"
AUTH="Authorization: Basic $(printf 'x-access-token:%s' "$GH_PUSH_TOKEN" | base64 -w0)"
git -c http.extraheader="$AUTH" push -q --force "$FORK" "$BRANCH" 2>&1 | sed "s/$GH_PUSH_TOKEN/[TOKEN]/g"
log "bundle publié sur $FORK ($BRANCH)"

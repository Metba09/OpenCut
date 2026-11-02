# Sourcé par les autres scripts : environnement hermétique (aucun appel réseau).
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")/.." && pwd)"
export ROOT
export CI=1                              # désactive les invites interactives
export WRANGLER_SEND_METRICS=false       # pas de télémétrie wrangler
export WRANGLER_HIDE_BANNER=true
export DO_NOT_TRACK=1
export NO_UPDATE_NOTIFIER=1 npm_config_update_notifier=false
export npm_config_audit=false npm_config_fund=false
export VITE_CONFIG_NATIVE_IGNORE_WARNING=true
# Cache npm vendoré : ./vendor/npm-cache, ou $OPENCUT_VENDOR_DIR/npm-cache
VENDOR_DIR="${OPENCUT_VENDOR_DIR:-$ROOT/vendor}"
export VENDOR_DIR
export PATH="$ROOT/node_modules/.bin:$PATH"
log()  { printf '\033[36m[opencut]\033[0m %s\n' "$*"; }
fail() { printf '\033[31m[opencut] ERREUR :\033[0m %s\n' "$*" >&2; exit 1; }

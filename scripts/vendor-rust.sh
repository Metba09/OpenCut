#!/usr/bin/env bash
# OPTIONNEL (réseau requis, sans cargo) : vendore les crates de Cargo.lock dans vendor/rust/,
# chaque archive vérifiée contre le checksum du lockfile. Écrit vendor/rust/cargo-config.toml
# à copier dans .cargo/config.toml pour compiler hors-ligne.
# Le desktop (GPUI) est INUTILISABLE dans le sandbox (pas de GPU/affichage) : ce vendoring ne
# sert que pour un autre environnement. ~124 Mo compressés, ~700 crates.
#   LIMIT=<n> pour tester sur n crates.
set -euo pipefail
. "$(dirname "$0")/_env.sh"
cd "$ROOT"
DEST="$ROOT/vendor/rust"; mkdir -p "$DEST"
python3 - "$DEST" "${LIMIT:-0}" << 'PY'
import re, sys, hashlib, tarfile, io, json, os, urllib.request
from concurrent.futures import ThreadPoolExecutor
dest, limit = sys.argv[1], int(sys.argv[2])
t = open('Cargo.lock').read()
pk = re.findall(r'\[\[package\]\]\nname = "([^"]+)"\nversion = "([^"]+)"\nsource = "registry[^"]*"\nchecksum = "([0-9a-f]+)"', t)
if limit: pk = pk[:limit]
def fetch(p):
    n, v, c = p
    out = os.path.join(dest, f'{n}-{v}')
    if os.path.exists(os.path.join(out, '.cargo-checksum.json')): return n
    data = urllib.request.urlopen(f'https://static.crates.io/crates/{n}/{n}-{v}.crate', timeout=60).read()
    if hashlib.sha256(data).hexdigest() != c: raise SystemExit(f'checksum invalide : {n}-{v}')
    tarfile.open(fileobj=io.BytesIO(data)).extractall(dest, filter='data')
    json.dump({'files': {}, 'package': c}, open(os.path.join(out, '.cargo-checksum.json'), 'w'))
    return n
with ThreadPoolExecutor(8) as ex: done = list(ex.map(fetch, pk))
print(len(done), 'crates vendorées')
open(os.path.join(dest, 'cargo-config.toml'), 'w').write(
 '[source.crates-io]\nreplace-with = "vendored-sources"\n\n[source.vendored-sources]\ndirectory = "vendor/rust"\n\n[net]\noffline = true\n')
PY
log "copier vendor/rust/cargo-config.toml vers .cargo/config.toml pour compiler hors-ligne"

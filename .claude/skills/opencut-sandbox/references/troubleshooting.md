# Dépannage (pièges déjà rencontrés)

- **`source: not found` / `time: not found`** : le shell du sandbox est `sh`. Utiliser `. ~/.memenv` et lancer les scripts avec `bash`.
- **`npm ci` n'exécute pas esbuild/workerd** : npm ≥ 11 bloque les scripts d'installation. `scripts/setup.sh` du projet utilise
  `--ignore-scripts` puis `npm rebuild esbuild workerd`. Ne pas lancer `npm ci` à la main sans ces deux étapes.
- **`vitest` : « depsOptimizer is required in dev mode »** : le `vite.config.ts` charge Cloudflare/TanStack. Le projet a un
  `vitest.config.ts` séparé dans chaque app ; ne pas le fusionner avec la config Vite.
- **`WRANGLER_HIDE_BANNER`** doit valoir `true`/`false`, pas `1`. Définir aussi `WRANGLER_SEND_METRICS=false` (déjà dans `scripts/_env.sh`).
- **`wrangler dev` affiche « Unable to fetch the Request.cf object »** : avertissement sans gravité hors-ligne, il bascule sur une valeur par défaut.
- **`SHA256SUMS` en échec** : le bundle est incomplet ou corrompu. Re-télécharger avec `memsync sparse`, ne pas l'ignorer.
- **Preuve d'exécution hors-ligne** : `unshare -rn` coupe le réseau (on est root). La boucle locale y est désactivée : l'activer
  (`ip link set lo up`, ou ioctl SIOCSIFFLAGS en Python si `ip` est absent) sinon `wrangler dev` échoue en `ENETUNREACH 127.0.0.1`.
- **Cargo.lock / Rust** : pas de toolchain ; `scripts/vendor-rust.sh` du projet vendore les crates (~124 Mo) pour un autre environnement.
- **Fichiers > 95 Mo** : `memsync push` les retire ; garder les morceaux du cache à 40 Mo (`make vendor`).
- **`ffmpeg introuvable`** : `apt-get install -y ffmpeg`, ou `pip install --break-system-packages imageio-ffmpeg` (le montage retrouve ce binaire tout seul), ou `FFMPEG_BIN=/chemin/ffmpeg`.
- **`drawtext` ne trouve pas de police** : passer `fontfile` dans le texte ; par défaut DejaVu/Liberation/FreeSans en gras sont essayées.
- **Rendu trop lent** : `output.preset: "ultrafast"`, `crf` plus haut, résolution plus basse ; le sandbox n'a qu'un cœur.

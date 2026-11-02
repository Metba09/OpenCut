# OpenCut — consignes pour Claude

Éditeur vidéo open source en réécriture. Monorepo : `apps/web` (TanStack Start + Vite 8 + React 19, cible Cloudflare Workers),
`apps/api` (Elysia sur Workers), `apps/desktop` (Rust + GPUI), `crates/media` (script de setup FFmpeg), `tools/montage` (montage vidéo headless, ajout du bundle sandbox).
Toute la logique vit dans `scripts/` et le `Makefile` ; `.claude/commands/` ne contient que de fins alias.

## Session Chat (Claude.ai, sandbox isolé)

**Démarrage depuis zéro** (le sandbox est vierge à chaque session ; seul GitHub est joignable) :
1. Depuis le fork public, sans jeton :
   `git clone --depth 1 -b sandbox-skill https://github.com/Metba09/OpenCut.git ~/OpenCut && cd ~/OpenCut`
   (variante via la mémoire privée : `/github-memory`, puis `bash scripts/bootstrap-from-memory.sh`).
2. `make setup` — idempotent, sans saisie : si le cache npm vendoré est absent, il est téléchargé (une fois, ~146 Mo) depuis la
   branche `sandbox-bundle` du fork ; ensuite tout est **hors-réseau** : `npm ci --offline`, scripts natifs, `.env`.
   `OPENCUT_OFFLINE=1` interdit tout téléchargement ; `OPENCUT_BUNDLE_DIR=<dossier>` indique un bundle déjà présent.
3. `make check` — à lancer à la main avant de conclure : garde hors-réseau, typecheck, tests web + API, build web, build API.
   Tout est vert = projet sain. Validé sous `unshare -rn` (réseau coupé) sur une copie vierge.

**Commandes exactes** : `make setup` · `make check` · `make test` · `make build` · `make smoke` (API locale + `/health`).
Outils : Node ≥ 22.12 + npm. **Ne pas utiliser** bun, moon, proto : non installés et non joignables.

**Utilisable dans le sandbox** : build et tests web, tests API (appel direct de `app.fetch`), `wrangler dev` (workerd local, port 8787),
`wrangler deploy --dry-run`, `vite build`, typecheck.

**Inutilisable dans le sandbox** :
- `apps/desktop` (GPUI) : pas de GPU ni d'affichage, pas de toolchain Rust. Sources non modifiées ; `scripts/vendor-rust.sh` vendore les ~700 crates (124 Mo) pour un autre environnement.
- `crates/media` : le prebuilt FFmpeg épinglé renvoie 404 et ffmpeg.org est bloqué ; rien de vendoré.
- `wrangler deploy` réel, `moon run upload-logos` (R2) : exigent des secrets Cloudflare. Aucun secret n'est requis ailleurs.
- `vite dev` n'est pas joignable depuis le navigateur de la personne ; utiliser `make smoke` ou `curl` local.

**Montage vidéo** : l'éditeur OpenCut n'existe pas encore (`/editor` = « Coming soon »). Pour monter dans le sandbox, utiliser
`tools/montage/` : un projet JSON (clips, découpes, vitesse, transitions, textes, musique, sous-titres) rendu par FFmpeg en MP4.
`make montage PROJECT=projet.json` · `make montage-demo` · format et limites : `tools/montage/README.md`. Ne pas le présenter comme
l'éditeur OpenCut ; c'est un rendu scripté, sans aperçu interactif ni timeline graphique.

**Commandes à lire à la demande** : `.claude/commands/setup.md`, `check.md`, `smoke.md`.
**Hooks** : aucun ; remplacés par `scripts/check.sh` (et `scripts/verify-offline.sh`, garde anti-ressources externes).
**MCP** : aucun dans le dépôt (le serveur MCP d'OpenCut n'existe pas encore). Alternative : les scripts ci-dessus en CLI.
**Réseau / secrets** : polices servies par npm (`@fontsource-variable/*`), plus de Google Fonts. Mocks : aucun appel externe dans le code ;
`.env.example` ne contient que des valeurs factices. Ne jamais écrire de jeton dans le dépôt.

## Écarts par rapport à l'amont
`package.json` racine (workspaces) + `package-lock.json` ajoutés ; dépendances `latest` épinglées ; résolution faite avec
`npm install --before=<aujourd'hui − 7 jours>` pour respecter `minimumReleaseAge` de `bunfig.toml`. `apps/web/vitest.config.ts`
isolé (le `vite.config.ts` plante vitest) ; 3 erreurs TypeScript corrigées (`calendar`, `scroll-area`, `spinner`) ; tests d'amorçage ajoutés.
Régénérer le bundle après un changement du lockfile : `make vendor` (réseau requis), puis le pousser sur la branche orpheline `sandbox-bundle`
(`scripts/publish-bundle.sh`).

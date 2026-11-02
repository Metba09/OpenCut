# sandbox-bundle
Cache npm hermétique (linux-x64) pour OpenCut en sandbox Claude.ai. Branche orpheline : aucun code ici.
Utilisé par `scripts/fetch-bundle.sh` de la branche `sandbox-skill`. Régénéré par `make vendor` + `scripts/publish-bundle.sh`.
Contenu : paquets npm publics du `package-lock.json` ; vérifier avec `sha256sum -c SHA256SUMS`.

# Interface unique (humain, CI, session Chat). Tout est dans scripts/ ; ce fichier n'est qu'un alias.
.PHONY: setup check test build smoke vendor clean help
help:
	@echo "make setup  - installation hors-ligne, idempotente"
	@echo "make check  - garde réseau + typecheck + tests + builds (à lancer avant de conclure)"
	@echo "make test   - tests web + API"
	@echo "make build  - build web + dry-run API"
	@echo "make smoke  - démarre l'API en local et teste /health"
	@echo "make vendor - (réseau) régénère le bundle npm dans ./bundle"
setup:
	@bash scripts/setup.sh
check: setup
	@bash scripts/check.sh
test: setup
	@npm --workspace apps/web run test --silent && npm --workspace apps/api run test --silent
build: setup
	@npm --workspace apps/web run build --silent && cd apps/api && npx wrangler deploy --dry-run --outdir /tmp/opencut-api-dist
smoke: setup
	@bash scripts/smoke.sh
vendor:
	@bash scripts/make-vendor.sh
clean:
	rm -rf node_modules apps/*/node_modules apps/web/dist apps/web/.wrangler apps/api/.wrangler

SHELL := bash
.DEFAULT_GOAL := help
ENV_FILE := environments/.env
COMPOSE := docker compose --env-file $(ENV_FILE)

# BuildKit attaches a provenance attestation that differs on every build, so a
# fully cached build still gets a new image ID and Compose recreates the
# container. The `provenance: false` build key in the Compose file does not
# prevent this (Compose v5.1); this variable does.
export BUILDX_NO_DEFAULT_ATTESTATIONS := 1

help: ## Show available targets
	@awk 'BEGIN {FS = ":.*## "}; /^[a-zA-Z0-9_-]+:.*## / {printf "%-12s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

$(ENV_FILE):
	@cp environments/.env.example $@
	@for key in POSTGRES_PASSWORD GEOSERVER_DB_PASSWORD GEOSERVER_ADMIN_PASSWORD; do \
		sed -i "s/^$$key=$$/$$key=$$(openssl rand -hex 16)/" $@; \
	done
	@echo "Created $@ with generated passwords"

env: $(ENV_FILE) ## Create environments/.env with generated passwords (if missing)

up: $(ENV_FILE) ## Start or rebuild the stack, import data if missing, apply the GeoServer catalog
	$(COMPOSE) up -d --build --wait
	@# GeoLibre renders its templates from the bind-mounted geolibre/ directory at
	@# startup. Edits there don't change the container config, so recreate it.
	$(COMPOSE) up -d --force-recreate --no-deps --wait geolibre
	@if [ "$$($(COMPOSE) exec -T postgis psql -U postgres -d gis -tAc "SELECT to_regclass('public.osm_import') IS NOT NULL")" != "t" ]; then \
		echo "No OSM data found, importing"; \
		$(MAKE) --no-print-directory load-data; \
	fi
	$(MAKE) --no-print-directory bootstrap
	@$(MAKE) --no-print-directory urls

urls: ## Print the addresses of the running services
	@set -a; . ./$(ENV_FILE); set +a; \
	gs="http://127.0.0.1:$${GEOSERVER_PORT:-8085}/geoserver"; \
	gl="http://127.0.0.1:$${GEOLIBRE_PORT:-8086}"; \
	echo "GeoServer: $$gs/web/"; \
	echo "GeoLibre:  $$gl/?url=$$gl/projects/osm.geolibre.json"; \
	echo "PostGIS:   127.0.0.1:$${POSTGIS_PORT:-5440}, database gis"

bootstrap: ## Apply the Terraform-managed GeoServer catalog
	$(COMPOSE) run --rm bootstrap

down: ## Stop the stack (keeps data)
	$(COMPOSE) down

load-data: $(ENV_FILE) ## Download (if needed) and import OSM data into PostGIS
	$(COMPOSE) run --rm --build loader
	@# Clear GeoServer's cached table structures, if GeoServer is running.
	@$(COMPOSE) exec -T geoserver sh -c 'curl -sf -o /dev/null -u "admin:$$GEOSERVER_ADMIN_PASSWORD" -X POST http://localhost:8080/geoserver/rest/reset' 2>/dev/null || true

psql: ## Open psql in the PostGIS container
	$(COMPOSE) exec postgis psql -U postgres -d gis

logs: ## Tail logs (SERVICE=name to filter)
	$(COMPOSE) logs -f $(SERVICE)

reset: ## Stop the stack and delete all volumes (database, GeoServer config)
	$(COMPOSE) --profile tools down -v

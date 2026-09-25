SHELL := bash
.DEFAULT_GOAL := help
ENV_FILE := environments/.env
COMPOSE := docker compose --env-file $(ENV_FILE)

help: ## Show available targets
	@awk 'BEGIN {FS = ":.*## "}; /^[a-zA-Z0-9_-]+:.*## / {printf "%-12s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

$(ENV_FILE):
	@cp environments/.env.example $@
	@for key in POSTGRES_PASSWORD GEOSERVER_DB_PASSWORD GEOSERVER_ADMIN_PASSWORD; do \
		sed -i "s/^$$key=$$/$$key=$$(openssl rand -hex 16)/" $@; \
	done
	@echo "Created $@ with generated passwords"

env: $(ENV_FILE) ## Create environments/.env with generated passwords (if missing)

up: $(ENV_FILE) ## Start the stack, import data if missing, apply the GeoServer catalog
	$(COMPOSE) up -d --build --wait
	@if [ "$$($(COMPOSE) exec -T postgis psql -U postgres -d gis -tAc "SELECT to_regclass('public.osm_import') IS NOT NULL")" != "t" ]; then \
		echo "No OSM data found, importing"; \
		$(MAKE) --no-print-directory load-data; \
	fi
	$(MAKE) --no-print-directory bootstrap

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

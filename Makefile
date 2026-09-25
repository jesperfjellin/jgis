.PHONY: help env up urls bootstrap down load-data psql logs reset
SHELL := bash
.DEFAULT_GOAL := help
ENV_FILE := environments/.env
COMPOSE := docker compose --env-file $(ENV_FILE)

# BuildKit attaches a provenance attestation that differs on every build, so a
# fully cached build still gets a new image ID and Compose recreates the
# container. The `provenance: false` build key in the Compose file does not
# prevent this (Compose v5.1); this variable does.
export BUILDX_NO_DEFAULT_ATTESTATIONS := 1

# Services that read config files bind-mounted from the repo get a label with a
# hash of those files (see docker-compose.yml). Editing a file changes the label,
# so `make up` recreates exactly the services whose config changed.
config_hash = $(shell find $(1) -type f -print0 | sort -z | xargs -0 sha1sum | sha1sum | cut -c1-12)
export GEOLIBRE_CONFIG_HASH := $(call config_hash,geolibre)
export ALLOY_CONFIG_HASH := $(call config_hash,observability/alloy)
export PROMETHEUS_CONFIG_HASH := $(call config_hash,observability/prometheus)
export LOKI_CONFIG_HASH := $(call config_hash,observability/loki)
# Dashboards are reloaded by Grafana itself; only provisioning needs a restart.
export GRAFANA_CONFIG_HASH := $(call config_hash,observability/grafana/provisioning)

help: ## Show available targets
	@awk 'BEGIN {FS = ":.*## "}; /^[a-zA-Z0-9_-]+:.*## / {printf "%-12s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

env: ## Create or update environments/.env (adds missing keys, generates empty passwords)
	@test -f $(ENV_FILE) || { cp environments/.env.example $(ENV_FILE); echo "Created $(ENV_FILE)"; }
	@grep -E '^[A-Z0-9_]+=' environments/.env.example | while IFS= read -r line; do \
		key="$${line%%=*}"; \
		grep -q "^$$key=" $(ENV_FILE) || { echo "$$line" >> $(ENV_FILE); echo "Added $$key to $(ENV_FILE)"; }; \
	done
	@for key in $$(grep -oE '^[A-Z0-9_]+_PASSWORD=$$' $(ENV_FILE) | tr -d =); do \
		sed -i "s/^$$key=$$/$$key=$$(openssl rand -hex 16)/" $(ENV_FILE); \
		echo "Generated $$key"; \
	done

up: env ## Start or rebuild the stack, import data if missing, apply the GeoServer catalog
	$(COMPOSE) up -d --build --wait
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
	echo "GeoServer:  $$gs/web/"; \
	echo "GeoLibre:   $$gl/?url=$$gl/projects/osm.geolibre.json"; \
	echo "PostGIS:    127.0.0.1:$${POSTGIS_PORT:-5440}, database gis"; \
	echo "Grafana:    http://127.0.0.1:$${GRAFANA_PORT:-8087}"; \
	echo "Prometheus: http://127.0.0.1:$${PROMETHEUS_PORT:-8088}"

bootstrap: ## Apply the Terraform-managed GeoServer catalog
	$(COMPOSE) run --rm bootstrap

down: ## Stop the stack (keeps data)
	$(COMPOSE) down

load-data: env ## Download (if needed) and import OSM data into PostGIS
	$(COMPOSE) run --rm --build loader
	@# Clear GeoServer's cached table structures, if GeoServer is running.
	@$(COMPOSE) exec -T geoserver sh -c 'curl -sf -o /dev/null -u "admin:$$GEOSERVER_ADMIN_PASSWORD" -X POST http://localhost:8080/geoserver/rest/reset' 2>/dev/null || true

psql: ## Open psql in the PostGIS container
	$(COMPOSE) exec postgis psql -U postgres -d gis

logs: ## Tail logs (SERVICE=name to filter)
	$(COMPOSE) logs -f $(SERVICE)

reset: ## Stop the stack and delete all volumes (database, GeoServer config)
	$(COMPOSE) --profile tools down -v

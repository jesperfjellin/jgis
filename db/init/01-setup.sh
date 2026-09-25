#!/usr/bin/env bash
# Runs once, when the PostGIS volume is first created.
set -euo pipefail

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" -v geoserver_password="$GEOSERVER_DB_PASSWORD" <<'SQL'
CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;

CREATE SCHEMA IF NOT EXISTS osm;

-- Read-only role used by GeoServer.
CREATE ROLE geoserver LOGIN PASSWORD :'geoserver_password';
GRANT CONNECT ON DATABASE gis TO geoserver;
GRANT USAGE ON SCHEMA osm TO geoserver;
ALTER DEFAULT PRIVILEGES IN SCHEMA osm GRANT SELECT ON TABLES TO geoserver;
SQL

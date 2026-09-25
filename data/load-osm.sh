#!/usr/bin/env bash
# Downloads the OSM extract (if not cached) and imports it into the "osm" schema.
# Re-running replaces the existing tables.
set -euo pipefail

: "${OSM_EXTRACT_URL:?}" "${PGHOST:?}" "${PGDATABASE:?}" "${PGUSER:?}" "${PGPASSWORD:?}"
cache_dir=/cache
pbf="$cache_dir/$(basename "$OSM_EXTRACT_URL")"

if [[ ! -s "$pbf" ]]; then
    echo "Downloading $OSM_EXTRACT_URL"
    curl -fSL --retry 3 -o "$pbf.part" "$OSM_EXTRACT_URL"
    mv "$pbf.part" "$pbf"
else
    echo "Using cached extract $pbf (delete it to download a fresh one)"
fi

# Marks the import as incomplete until post-import.sql finishes.
psql -v ON_ERROR_STOP=1 -qc "DROP TABLE IF EXISTS public.osm_import"

osm2pgsql \
    --create --slim --drop \
    --output=flex --style=/opt/loader/osm.lua \
    --cache="${OSM2PGSQL_CACHE_MB:-1500}" \
    --number-processes="${OSM2PGSQL_PROCESSES:-4}" \
    "$pbf"

psql -v ON_ERROR_STOP=1 -v source="$(basename "$pbf")" -f /opt/loader/post-import.sql
echo "OSM import finished"

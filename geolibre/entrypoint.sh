#!/bin/sh
# Renders the project and service catalog templates with the browser-facing
# GeoServer URL, then starts the stock GeoLibre entrypoint. The project is
# served at /projects/; the catalog is read by the stock entrypoint through
# GEOLIBRE_SERVICES_FILE.
set -eu
: "${GEOSERVER_URL:?}" "${GEOLIBRE_SERVICES_FILE:?}"

render() {
    python3 -c '
import os, string, sys
sys.stdout.write(string.Template(sys.stdin.read()).substitute(GEOSERVER_URL=os.environ["GEOSERVER_URL"]))
' < "$1" > "$2"
}

mkdir -p /usr/share/nginx/html/projects "$(dirname "$GEOLIBRE_SERVICES_FILE")"
render /opt/jgis/osm.geolibre.json.template /usr/share/nginx/html/projects/osm.geolibre.json
render /opt/jgis/services.json.template "$GEOLIBRE_SERVICES_FILE"
exec /usr/local/bin/entrypoint.sh

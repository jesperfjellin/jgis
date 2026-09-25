#!/bin/sh
# Renders the project template with the browser-facing GeoServer URL, then
# starts the stock GeoLibre entrypoint. The project is served at /projects/.
set -eu
: "${GEOSERVER_URL:?}"
mkdir -p /usr/share/nginx/html/projects
python3 -c '
import os, string, sys
sys.stdout.write(string.Template(sys.stdin.read()).substitute(GEOSERVER_URL=os.environ["GEOSERVER_URL"]))
' < /opt/jgis/osm.geolibre.json.template > /usr/share/nginx/html/projects/osm.geolibre.json
exec /usr/local/bin/entrypoint.sh

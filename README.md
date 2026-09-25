# JGIS

A local GIS stack for testing how well PostGIS and GeoServer perform together.
PostGIS holds the data, GeoServer publishes it through standard OGC services,
and everything is configured from this repository. Nothing has to be set up by
hand in the GeoServer UI.

It loads the OpenStreetMap extract for Norway (about 10 million features), so
there is enough data for performance problems to show up.

This is a development and benchmarking setup for a single machine. It has no
authentication, TLS or hardening, and is not meant to be exposed to a network.

## Status

| Part                                             | State       |
|--------------------------------------------------|-------------|
| PostGIS, OSM data loader, GeoServer, Terraform   | Done        |
| Metrics and logs (Prometheus, Grafana, Loki)     | Done        |
| Load tests (k6)                                  | Done        |
| Baseline measurements and tuning                 | Not started |
| Browser client for visual checks (GeoLibre)      | Done        |

## Requirements

- Linux, macOS or Windows with WSL2
- Docker with Docker Compose v2
- GNU Make and OpenSSL
- About 12 GB of free disk space (database plus the downloaded extract)
- About 5 GB of RAM available to Docker

## Setup

```bash
git clone <repository-url> jgis
cd jgis
make up
```

`make up` does the following:

1. Creates `environments/.env` from `environments/.env.example` if it does not
   exist, adds settings that are new in `.env.example`, and generates random
   values for empty passwords.
2. Builds the images and starts all services.
3. If the database has no OSM data, downloads the Norway extract (1.4 GB,
   cached in `data/cache/`) and imports it. This takes about 10 minutes on a
   recent machine.
4. Applies the GeoServer configuration with Terraform.
5. Prints the service addresses (also available with `make urls`).

Later runs skip the download and the import. `make up` is also the command for
rebuilding: it rebuilds images whose files changed (using the Docker build
cache) and recreates the containers whose image, settings or config files
changed. The database volume is kept, so the data is not imported again. Only `make reset` (deletes all volumes) or `make load-data`
trigger a new import.

When it has finished:

| Service   | Address                              | Login                                  |
|-----------|--------------------------------------|----------------------------------------|
| GeoServer | http://127.0.0.1:8085/geoserver/web/ | `admin` / `GEOSERVER_ADMIN_PASSWORD`   |
| GeoLibre  | http://127.0.0.1:8086/?url=http://127.0.0.1:8086/projects/osm.geolibre.json | none |
| PostGIS   | `127.0.0.1:5440`, database `gis`     | `postgres` / `POSTGRES_PASSWORD`       |
|           |                                      | `geoserver` / `GEOSERVER_DB_PASSWORD` (read-only) |
| Grafana   | http://127.0.0.1:8087                | none to view; `admin` / `GRAFANA_ADMIN_PASSWORD` to edit |
| Prometheus| http://127.0.0.1:8088                | none                                   |
| Loki      | http://127.0.0.1:8089                | none (HTTP API only)                   |

The passwords are in `environments/.env`. All ports are bound to 127.0.0.1.

## Commands

| Command          | Description                                                         |
|------------------|---------------------------------------------------------------------|
| `make up`        | Start or rebuild the stack, import data if missing, apply the GeoServer config |
| `make down`      | Stop the stack. Data is kept.                                       |
| `make load-data` | Import the OSM data again. Replaces the tables in the `osm` schema. |
| `make bootstrap` | Apply the GeoServer config again                                    |
| `make urls`      | Print the service addresses                                         |
| `make loadtest`  | Run a k6 load test and write a report, see [loadtest/README.md](loadtest/README.md) |
| `make psql`      | Open psql as `postgres`                                             |
| `make logs`      | Follow the logs. `SERVICE=geoserver` limits it to one service.      |
| `make reset`     | Stop the stack and delete all volumes (database and GeoServer config) |

To run Docker Compose directly, pass the env file:
`docker compose --env-file environments/.env ps`.

## Configuration

Settings are in `environments/.env`. See `environments/.env.example` for all
options.

| Variable                   | Default                                                   |
|----------------------------|-----------------------------------------------------------|
| `POSTGIS_PORT`             | `5440`                                                    |
| `GEOSERVER_PORT`           | `8085`                                                    |
| `GEOLIBRE_PORT`            | `8086`                                                    |
| `GRAFANA_PORT`             | `8087`                                                    |
| `PROMETHEUS_PORT`          | `8088`                                                    |
| `LOKI_PORT`                | `8089`                                                    |
| `PROMETHEUS_RETENTION`     | `15d`                                                     |
| `GEOSERVER_VERSION`        | `3.0.1`                                                   |
| `GEOSERVER_JAVA_OPTS`      | `-Xms1g -Xmx2g`                                           |
| `PG_SHARED_BUFFERS`        | `1GB`                                                     |
| `PG_EFFECTIVE_CACHE_SIZE`  | `3GB`                                                     |
| `OSM_EXTRACT_URL`          | `https://download.geofabrik.de/europe/norway-latest.osm.pbf` |
| `OSM2PGSQL_CACHE_MB`       | `1500`                                                    |
| `OSM2PGSQL_PROCESSES`      | `4`                                                       |

To use a different area, set `OSM_EXTRACT_URL` to another
[Geofabrik](https://download.geofabrik.de/) extract and run `make load-data`.
Downloaded extracts are kept in `data/cache/`. To get a newer copy of the same
extract, delete the file there first.

## Repository layout

```
docker-compose.yml   Services: postgis, geoserver, geolibre, prometheus, loki, alloy,
                     postgres-exporter, grafana. One-off jobs: loader, bootstrap.
environments/        .env.example (committed) and .env (local, ignored by git)
db/init/             Runs once on a new database: extensions, "osm" schema, read-only role
data/                Loader image: osm2pgsql style (osm.lua) and post-import SQL
geoserver/           GeoServer image: extensions, JMX exporter, JSON access log
geolibre/            GeoLibre project template and container entrypoint
terraform/           GeoServer config: workspace, datastore, layers, styles, tile cache
observability/       Alloy, Loki, Prometheus and Grafana config; dashboards as JSON
loadtest/            k6 load tests, self-contained (see loadtest/README.md)
```

## Data

osm2pgsql imports the extract into these tables in the `osm` schema:

| Table        | Geometry     | Approx. rows (Norway) |
|--------------|--------------|-----------------------|
| `buildings`  | MultiPolygon | 4.2 M                 |
| `roads`      | LineString   | 1.9 M                 |
| `landcover`  | MultiPolygon | 1.5 M                 |
| `water`      | MultiPolygon | 1.1 M                 |
| `waterways`  | LineString   | 0.8 M                 |
| `pois`       | Point        | 220 k                 |
| `places`     | Point        | 22 k                  |
| `railways`   | LineString   | 15 k                  |
| `boundaries` | MultiPolygon | 400                   |

Geometries are stored in EPSG:3857 (Web Mercator), the projection web clients
request, so GeoServer does not reproject. Each table has a spatial index, a
primary key and is sorted by geometry.

## GeoServer

Terraform in `terraform/` owns the GeoServer configuration: the `osm` workspace
and datastore, one layer per table, an SLD style per layer, and the tile cache
settings. Changes made in the GeoServer UI are not tracked and are overwritten
by `make bootstrap`.

The image includes the `vectortiles` and `ogcapi-features` extensions, and the
`ogcapi-tiles` community module (installed from the versioned jar in the OSGeo
Maven repository, as community modules have no release downloads).

Endpoints, relative to `http://127.0.0.1:8085/geoserver`:

| Service                 | Path                                                                          |
|-------------------------|-------------------------------------------------------------------------------|
| OGC API Features        | `/ogc/features/v1/collections/osm:roads/items`                                |
| OGC API Tiles, vector   | `/ogc/tiles/v1/collections/osm:roads/tiles/WebMercatorQuad/{z}/{y}/{x}?f=application/vnd.mapbox-vector-tile` |
| OGC API Tiles, map (PNG)| `/ogc/tiles/v1/collections/osm:roads/map/tiles/WebMercatorQuad/{z}/{y}/{x}?f=image/png` |
| OGC API Tiles, TileJSON | `/ogc/tiles/v1/collections/osm:roads/tiles/WebMercatorQuad/metadata?f=application/json` |
| WMS, WFS                | `/osm/ows?service=WMS&request=GetCapabilities` (or `service=WFS`)             |
| WMTS                    | `/gwc/service/wmts?request=GetCapabilities`                                   |
| TMS                     | `/gwc/service/tms/1.0.0/osm:roads@WebMercatorQuad@png/{z}/{x}/{-y}.png`       |

All tile endpoints are served from the same GeoWebCache cache, in the
`WebMercatorQuad` tile matrix set, with `Cache-Control: max-age=3600`. TMS counts
tile rows from the bottom (`{-y}` in MapLibre and OpenLayers URL templates) and
needs the file extension.

### Adding a layer

1. Add a table in `data/osm.lua` and run `make load-data`.
2. Add the table to `local.layers` in `terraform/layers.tf`.
3. Add a style with the same name in `terraform/styles/`.
4. Run `make bootstrap`.

## GeoLibre

[GeoLibre](https://github.com/opengeos/GeoLibre) is included as a browser
client for checking that the published data renders correctly. It runs from the
upstream image with project sharing, collaboration and the Python sidecar turned
off. It is not part of what is being measured.

The URL from `make urls` opens `geolibre/osm.geolibre.json.template`, with the
GeoServer address filled in when the container starts. The project loads the
same data through different GeoServer paths, so they can be compared:

| Delivery                 | Endpoint                           | Layers                                         |
|--------------------------|------------------------------------|------------------------------------------------|
| WMS, rendered per tile   | `/osm/wms` (not cached)            | land cover, water, waterways, boundaries, railways, POIs, places |
| OGC API vector tiles     | `/ogc/tiles/...` (cached)          | roads, buildings                               |
| OGC API map tiles (PNG)  | `/ogc/tiles/.../map/...` (cached)  | roads, buildings (hidden by default)           |

Buildings are drawn from zoom 14 and roads from zoom 7, matching the scale
limits in their GeoServer styles. Changes made in GeoLibre are not written back
to the template. To change the default project or the service catalog, edit the
template and run `make up`, which recreates the GeoLibre container when the
templates change.

### Adding layers in GeoLibre

The Browser panel (left edge) lists every GeoServer layer under **Services**,
from `geolibre/services.json.template`. Click an entry to add it:

- **WMS**: all layers, rendered per request.
- **XYZ**: all layers as OGC API map tiles (cached PNG).
- **WFS**: `places`, `railways` and `boundaries` only, limited to 25,000
  features. WFS loads the features into the browser, which does not work for
  the larger layers.

GeoLibre's service catalog has no entry type for vector tiles. To add a layer as
OGC API vector tiles, use **Add Data → OGC Vector Tiles** and enter the TileJSON
URL, for example:

```
http://127.0.0.1:8085/geoserver/ogc/tiles/v1/collections/osm:roads/tiles/WebMercatorQuad/metadata?f=application/json
```

GeoLibre runs from an unreleased main-branch image (`sha-e9df9e2`), because the
service catalog is not in a release yet (latest is `v3.0.0`).

## Observability

Every request to GeoServer is timed, and GeoServer, the JVM and PostgreSQL are
monitored. The results are in Grafana at http://127.0.0.1:8087, in three
dashboards:

| Dashboard          | Shows                                                                        |
|--------------------|------------------------------------------------------------------------------|
| GeoServer requests | Requests per second, P50/P95/P99 latency per service, tile cache hit ratio, cache hit vs miss latency, status codes, bytes sent, per-layer latency, slowest requests |
| GeoServer JVM      | Heap, GC time, memory pools, CPU, Tomcat and JVM threads, GeoServer warnings |
| PostGIS            | Connections, transactions, rows scanned vs returned, buffer cache hit ratio, temp files, top queries by total time, slow query plans |

How the data is collected:

| Source | Collected by | Stored in |
|--------|--------------|-----------|
| Tomcat access log, one JSON line per request with duration and GeoWebCache cache result | Alloy, which turns it into the `geoserver_request_duration_seconds` histogram (labels `service`, `cache`, `status_class`) | Prometheus (metrics), Loki (raw lines, with the layer name) |
| JVM and Tomcat MBeans | JMX exporter agent in the GeoServer JVM (`geoserver:9404`) | Prometheus |
| `pg_stat_database`, `pg_stat_activity`, `pg_stat_statements` | postgres_exporter | Prometheus |
| Container logs, including PostgreSQL `auto_explain` plans for statements over 500 ms | Alloy, through the Docker socket | Loki |

`service` is derived from the request path: `ogcapi-tiles`, `ogcapi-maptiles`,
`ogcapi-features`, `wms`, `wfs`, `wmts`, `tms`, `rest`, `web` or `other`. The
Docker healthcheck requests show up as `web` and are excluded from the
dashboards by default.

Metrics are kept for 15 days (`PROMETHEUS_RETENTION`), logs for 7 days.
Dashboards and data sources are provisioned from `observability/grafana/` and
cannot be changed in the UI; edit the JSON files instead. Grafana picks up
dashboard changes within about 10 seconds.

Alloy needs read access to `/var/run/docker.sock` to collect container logs.

## Load tests

`loadtest/` contains k6 scenarios that simulate users browsing a map (OGC API
tiles, WMS, OGC API Features, or a mix). `make loadtest` runs one and writes a
report to `loadtest/results/<id>/report.md`: client and server latency per
service, layer and cache result, JVM, container and PostgreSQL metrics, top SQL
statements and slow plans, GeoServer warnings, and optionally a JFR CPU profile
of GeoServer. Tests can be repeated to measure noise and compared with a
baseline (`BASE=<id>`). Results also appear in the **Load test** Grafana
dashboard. See [loadtest/README.md](loadtest/README.md).

## License

The code in this repository is licensed under the [MIT License](LICENSE).

Map data © OpenStreetMap contributors, available under the
[Open Database License](https://www.openstreetmap.org/copyright). The data is
downloaded at setup time and is not part of this repository.

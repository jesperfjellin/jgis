# Load tests

k6 scenarios that put load on GeoServer the way map clients do, so you can see
how the stack performs on your hardware. Results show up in Grafana next to
GeoServer's own request timings, JVM and database metrics.

The tests run in a container on the stack's Docker network (k6 2.3.0), so
there is nothing to install. The stack must be running (`make up`).

## Running

```bash
make loadtest                                   # tiles scenario, 10 users, 2 minutes
make loadtest SCENARIO=tiles COLD_CACHE=true    # empty the tile cache first
make loadtest SCENARIO=wms VUS=20 DURATION=5m
make loadtest SCENARIO=mixed VUS=30 DURATION=10m
```

At the end, k6 prints a summary, and `make` prints:

- the path of a JSON summary in `loadtest/results/` (ignored by git)
- a link to the **Load test** dashboard in Grafana, with the run selected and
  the time range set to it

Each run gets a test id (`<UTC timestamp>-<scenario>`), which is the
`testid` label on all k6 metrics.

## Scenarios

Every scenario simulates users browsing a map. A user lands on a town at a
random zoom level, then makes four more moves (pan half a screen, zoom in or
zoom out), waiting 1–3 seconds between views. Requests the user already made
in the session are not repeated, as a browser would have them cached. Each view
is 6 × 4 tiles of 256 px, roughly a 1536 × 1024 map.

| Scenario   | Requests per view |
|------------|-------------------|
| `tiles`    | OGC API tiles for each layer in `TILE_LAYERS`, at zooms and within bounds where the layer has content (read from GeoServer's TileJSON). Vector tiles by default, PNG map tiles with `TILE_FORMAT=map`. Served through GeoWebCache. |
| `wms`      | One WMS GetMap per tile, with all `WMS_LAYERS` combined. Not cached: every request is rendered. |
| `features` | One OGC API Features items request per layer in `FEATURE_LAYERS`, for the view's bounding box (up to 1000 features). |
| `mixed`    | The three above at the same time, with `VUS` split 60 / 25 / 15. |

With `COLD_CACHE=true`, `tiles` and `mixed` empty GeoWebCache for their layers
before starting, so early requests measure rendering from PostGIS.

The views are generated from a seeded random number generator (`SEED`): the
same settings give the same sequence of requests, so runs can be compared.

## Settings

Pass them to `make loadtest` as `NAME=value`.

| Setting          | Default | Meaning |
|------------------|---------|---------|
| `SCENARIO`       | `tiles` | File name in `scenarios/` |
| `VUS`            | `10`    | Concurrent users |
| `DURATION`       | `2m`    | Run time (k6 duration, e.g. `30s`, `10m`) |
| `SEED`           | `1`     | Seed for the generated views |
| `COLD_CACHE`     | unset   | `true` empties the tile cache first |
| `TILE_FORMAT`    | `vector`| `vector` or `map` |
| `TILE_LAYERS`    | `landcover,water,waterways,roads,railways,buildings` | Layers requested as tiles |
| `WMS_LAYERS`     | `landcover,water,roads,buildings,places` | Layers combined in each GetMap |
| `FEATURE_LAYERS` | `places,pois,railways` | Layers requested as features |
| `ZOOMS`          | `8:1,10:2,12:3,13:3,14:4,15:3,16:2` | Zoom levels users land on, as `zoom:weight` |
| `AREAS`          | 10 Norwegian towns | JSON list of `[lon, lat, spread in degrees]` |
| `VIEW_COLS`, `VIEW_ROWS` | `6`, `4` | Viewport size in tiles |
| `THINK_MIN`, `THINK_MAX` | `1`, `3` | Seconds between views |
| `WORKSPACE`      | `osm`   | GeoServer workspace |
| `BASE_URL`       | `http://geoserver:8080/geoserver` | GeoServer, as seen from the k6 container |

## Reading the results

The **Load test** dashboard (Grafana, folder *JGIS load tests*) has three parts:

- **Client (k6):** users, requests per second, P50/P95/P99 per service, failed
  requests, time to first byte vs transfer time, and a table of latency per
  service and layer.
- **GeoServer:** server-side P95 from the access log, tile cache hit ratio,
  CPU, Tomcat threads, heap and GC time.
- **PostGIS:** active connections, rows scanned vs returned, block reads.

The GeoServer and PostGIS panels show everything in the time window, not only
the test's requests. Comparing client and server P95 shows how much time is
spent outside GeoServer (connection queueing, transfer).

For more detail, open the **GeoServer requests**, **GeoServer JVM** and
**PostGIS** dashboards for the same time range (links at the top).

## Things to keep in mind

- k6 runs on the same machine as the stack and uses CPU too. At high `VUS`,
  check that the machine itself is not the limit.
- After a warm run, most tile requests are cache hits and measure GeoWebCache,
  not rendering. Use `COLD_CACHE=true` or the `wms` scenario to measure
  rendering.
- PostgreSQL and the OS cache data between runs. The first run after
  `make up` is slower than the ones after it.

## Layout

```
compose.yaml   k6 service, used together with the main docker-compose.yml
scenarios/     one k6 script per scenario
lib/           settings, tile maths, request builders, map session model
grafana/       the Load test dashboard (provisioned by the main stack's Grafana)
results/       JSON summaries of past runs (ignored by git)
```

# Load tests

k6 scenarios that put load on GeoServer the way map clients do, and a report
for each test that combines the client's view with GeoServer, JVM, PostgreSQL
and container metrics, logs and an optional CPU profile. The report is plain
Markdown and JSON, so it can be read by a person or a coding agent.

Everything runs in containers on the stack's Docker network (k6 2.3.0, Python
3.13 for the report); there is nothing to install. The stack must be running
(`make up`).

## Running

```bash
make loadtest                                        # tiles scenario, 10 users, 2 minutes
make loadtest SCENARIO=wms VUS=20 DURATION=5m
make loadtest SCENARIO=tiles COLD_CACHE=true WARMUP=30s REPEAT=3
make loadtest PROFILE=true                           # add a JFR CPU profile of GeoServer
make loadtest TESTID=after-fix REPEAT=3 BASE=before-fix   # compare with an earlier test
```

When it finishes, `make` prints:

- `loadtest/results/<id>/report.md`: the report
- `loadtest/results/<id>/compare-<base>.md`: the comparison, with `BASE`
- a link to the **Load test** dashboard in Grafana, scoped to the test

The test id is `<UTC timestamp>-<scenario>` unless `TESTID` is set. It is the
`testid` label on all k6 metrics; each repeat also has a `run` label.

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

The views are generated from a seeded random number generator (`SEED`): the
same settings give the same sequence of requests, so runs can be compared.

## Settings

Pass them to `make loadtest` as `NAME=value`. Scenario defaults are in
`lib/defaults.json`.

| Setting          | Default | Meaning |
|------------------|---------|---------|
| `SCENARIO`       | `tiles` | File name in `scenarios/` |
| `VUS`            | `10`    | Concurrent users |
| `DURATION`       | `2m`    | Measured run time (k6 duration, e.g. `30s`, `10m`) |
| `WARMUP`         | none    | Load before the measured part, e.g. `30s`. Excluded from the report. |
| `REPEAT`         | `1`     | Number of runs; the report shows the spread between them |
| `COOLDOWN`       | `15`    | Seconds between repeats |
| `COLD_CACHE`     | none    | `true` empties GeoWebCache for the tile layers before each run |
| `PROFILE`        | none    | `true` records a JFR CPU profile of GeoServer during the measured part |
| `BASE`           | none    | Test id to compare with |
| `TESTID`         | timestamp-scenario | Name of the test and its results directory |
| `SEED`           | `1`     | Seed for the generated views |
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

## The report

`report.md` for a test contains:

- **Context:** git commit and uncommitted changes, CPUs and memory available to
  Docker, host CPU, settings that differ from the defaults.
- **Findings:** rule-of-thumb flags that point at where to look, for example a
  high cache hit ratio (the run measured the cache, not rendering), cache hits
  waiting on metatile renders, CPU saturation, rows scanned per row returned,
  frequent GeoServer warnings, and the largest CPU component in the profile.
- **Key metrics over all runs** (with `REPEAT` > 1): median, min, max and
  spread of throughput, latency percentiles, cache hit ratio, CPU, GC and
  database metrics.
- For each run (`runs/<n>/report.md`, included in the test report when there
  is one run):
  - **Client (k6):** requests, failures and P50/P95/P99 per service and layer.
  - **GeoServer:** from the access log, per service, layer and cache result
    (hit, miss, none): requests, errors, P50/P95/P99, max and total time.
  - **Resources:** GeoServer JVM CPU, heap, GC and Tomcat threads, and CPU and
    memory per container (sampled with `docker stats`).
  - **PostgreSQL:** rows scanned vs returned, buffer cache hit ratio, temp
    files, connections, the top statements by total time with calls, mean time
    and rows per call, and the slowest `auto_explain` plans (over 500 ms).
  - **GeoServer warnings:** grouped by message with numbers masked, with counts.
  - **CPU profile** (with `PROFILE=true`): CPU of GeoServer request threads by
    component (JTS, rendering, vector tile encoding, JDBC, image encoding, ...),
    the hottest methods inclusive and self, and where threads block in native
    code (mostly waiting for PostgreSQL).

`report.json` has the same data. Each `runs/<n>/` directory also has the k6
summary, the resource samples and, with profiling, `profile.jfr` for JDK
Mission Control.

The measured window is the run after `WARMUP`. The GeoServer, JVM, PostgreSQL
and resource numbers cover everything in that window, so avoid other traffic
(GeoLibre, other tests) while a test runs.

## Comparing

`BASE=<id>` compares the test with an earlier one. For each key metric, the
comparison shows both medians, the change and a verdict: `better`, `worse`, or
`same` when the change is within 10% or within the run-to-run spread of either
test, whichever is larger. It warns when the tests ran on different hardware,
when only one ran with `PROFILE=true`, or when a side has fewer than 3 runs.

To check whether a change helps:

1. Run the baseline: `make loadtest TESTID=before REPEAT=3 WARMUP=30s ...`
2. Make the change (`make up` applies config and image changes).
3. Run the same settings: `make loadtest TESTID=after REPEAT=3 WARMUP=30s ... BASE=before`

Use the same settings, `PROFILE` value and machine for both, and run them close
together. PostgreSQL's and the OS's caches keep warming after a restart, so the
first test after `make up` can look slower than later ones; a warm-up run
before the baseline avoids that.

## Querying the data directly

All data is also available over HTTP on the host, for questions the report
does not answer.

| Service    | Address                  |
|------------|--------------------------|
| Prometheus | http://127.0.0.1:8088    |
| Loki       | http://127.0.0.1:8089    |
| PostgreSQL | `127.0.0.1:5440`, database `gis` (`make psql`) |

Prometheus (`/api/v1/query?query=...&time=<unix>`):

```promql
# Server P95 per service over the last 5 minutes
histogram_quantile(0.95, sum by (le, service, cache) (rate(geoserver_request_duration_seconds_bucket[5m])))
# Client P95 per service and layer for one test
histogram_quantile(0.95, sum by (name, layer) (rate(k6_http_req_duration_seconds{testid="<id>"}[5m])))
# Statements run by GeoServer, time per second, with the SQL text
topk(10, rate(pg_stat_statements_seconds_total{user="geoserver"}[5m]))
  * on (queryid) group_left(query) max by (queryid, query) (pg_stat_statements_query_id)
# GeoServer JVM CPU (cores) and Tomcat busy threads
rate(process_cpu_seconds_total{job="geoserver-jvm"}[1m])
tomcat_threadpool_currentthreadsbusy
```

Loki (`/loki/api/v1/query_range?query=...&start=<ns>&end=<ns>`):

```logql
# Access log: requests slower than 1 s (elapsedTime is in microseconds)
{job="geoserver-access"} | json | elapsedTime > 1000000
# P95 per layer and cache result
quantile_over_time(0.95, {job="geoserver-access"} | json | unwrap elapsedTime [5m]) by (layer, cache)
# PostgreSQL slow statement plans
{service="postgis"} |= "duration:" |= "plan:"
# GeoServer warnings and errors
{service="geoserver"} |~ "^\\d{2} \\w{3} [\\d:]{8} (WARN|ERROR|SEVERE) "
```

The access log labels are `service` (`ogcapi-tiles`, `ogcapi-maptiles`,
`ogcapi-features`, `wms`, `wfs`, `wmts`, `tms`, ...), `cache` (`hit`, `miss`,
`none`) and `status_class`; `layer` is structured metadata. Container logs have
a `service` label with the Compose service name.

## Things to keep in mind

- k6 runs on the same machine as the stack and uses CPU too. The report shows
  k6's CPU use and warns when it is high.
- After a warm run, most tile requests are cache hits and measure GeoWebCache,
  not rendering. Use `COLD_CACHE=true`, the cache=miss rows, or the `wms`
  scenario to measure rendering.
- JFR profiling (`PROFILE=true`) adds some CPU overhead. Compare profiled runs
  only with profiled runs.

## Layout

```
run.sh         runs a test: context, repeats, profiling, resource samples, reports
compose.yaml   k6 and report services, used together with the main docker-compose.yml
scenarios/     one k6 script per scenario
lib/           settings and defaults, tile maths, request builders, map session model
report/        report.py: builds reports and comparisons (Python standard library only)
grafana/       the Load test dashboard (provisioned by the main stack's Grafana)
results/       one directory per test (ignored by git)
```

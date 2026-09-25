"""Load test reports, built from Prometheus, Loki, container samples and JFR.

  report.py run <run dir>          report for one run (results/<id>/runs/<n>)
  report.py aggregate <test dir>   combine the runs of one test (results/<id>)
  report.py compare <base> <test>  compare two tests' aggregated reports

Standard library only. Runs in a container on the stack network (see
loadtest/compose.yaml); paths are relative to loadtest/.
"""

import json
import math
import os
import re
import statistics
import sys
import urllib.parse
import urllib.error
import urllib.request
from collections import Counter, defaultdict

PROMETHEUS = os.environ.get("PROMETHEUS_URL", "http://prometheus:9090")
LOKI = os.environ.get("LOKI_URL", "http://loki:3100")
HERE = os.path.dirname(os.path.abspath(__file__))
DEFAULTS = os.path.join(HERE, "..", "lib", "defaults.json")

# Services that are not map traffic (healthchecks, admin UI, REST).
IGNORED_SERVICES = "web|rest|other"
# Relative change treated as noise in comparisons when runs give no spread.
NOISE = 0.10
# Percentiles from fewer requests than this per run are too noisy for a verdict.
MIN_SAMPLES = 300


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


def read_env(path):
    out = {}
    if os.path.exists(path):
        for line in open(path, encoding="utf-8"):
            line = line.rstrip("\n")
            if "=" in line:
                key, value = line.split("=", 1)
                out[key] = value
    return out


def http_json(base, path, params):
    url = f"{base}{path}?{urllib.parse.urlencode(params)}"
    try:
        with urllib.request.urlopen(url, timeout=300) as res:
            body = json.load(res)
    except urllib.error.HTTPError as e:
        raise RuntimeError(f"HTTP {e.code} for query {params.get('query')!r}: {e.read().decode(errors='replace')[:500]}") from None
    if body.get("status") != "success":
        raise RuntimeError(f"Query failed: {url}: {body}")
    return body["data"]["result"]


def prom(query, time):
    """Instant Prometheus query -> list of (labels, float)."""
    out = []
    for r in http_json(PROMETHEUS, "/api/v1/query", {"query": query, "time": time}):
        value = float(r["value"][1])
        if not math.isnan(value):
            out.append((r["metric"], value))
    return out


def prom_one(query, time):
    rows = prom(query, time)
    return rows[0][1] if rows else None


def loki(query, time):
    out = []
    for r in http_json(LOKI, "/loki/api/v1/query", {"query": query, "time": str(time * 10**9)}):
        out.append((r["metric"], float(r["value"][1])))
    return out


def loki_lines(query, start, end, limit=1000):
    params = {"query": query, "start": str(start * 10**9), "end": str(end * 10**9), "limit": limit, "direction": "backward"}
    lines = []
    for stream in http_json(LOKI, "/loki/api/v1/query_range", params):
        lines += [v[1] for v in stream["values"]]
    return lines


def ms(seconds):
    return None if seconds is None else round(seconds * 1000, 2)


def fmt_ms(v):
    if v is None:
        return "-"
    return f"{v:.0f}" if v >= 100 else f"{v:.1f}" if v >= 1 else f"{v:.2f}"


def fmt_num(v, digits=0):
    return "-" if v is None else f"{v:,.{digits}f}"


def pct(v):
    return "-" if v is None else f"{v * 100:.1f}%"


def md_table(headers, rows):
    lines = ["| " + " | ".join(headers) + " |", "|" + "|".join("---" for _ in headers) + "|"]
    for r in rows:
        lines.append("| " + " | ".join(str(c) for c in r) + " |")
    return "\n".join(lines)


def settings(context):
    """Effective scenario settings: defaults.json overlaid with what was set."""
    effective = json.load(open(DEFAULTS, encoding="utf-8"))
    for key, value in context.items():
        if key.startswith("SETTING_"):
            effective[key[len("SETTING_"):]] = value
    return effective


# ---------------------------------------------------------------------------
# Collection for one run
# ---------------------------------------------------------------------------


def collect_client(testid, run, end, window):
    """k6's view, per service (name) and layer, from Prometheus."""
    sel = f'testid="{testid}", run="{run}", name!="setup", scenario!~".*_warmup"'
    rng = f"[{window}s]"
    groups = defaultdict(dict)
    for labels, v in prom(f"sum by (name, layer) (increase(k6_http_reqs_total{{{sel}}}{rng}))", end):
        groups[(labels.get("name", ""), labels.get("layer", ""))]["requests"] = round(v)
    for labels, v in prom(f'sum by (name, layer) (increase(k6_http_reqs_total{{{sel}, expected_response="false"}}{rng}))', end):
        groups[(labels.get("name", ""), labels.get("layer", ""))]["failed"] = round(v)
    for q in ("0.5", "0.95", "0.99"):
        expr = f"histogram_quantile({q}, sum by (name, layer) (increase(k6_http_req_duration_seconds{{{sel}}}{rng})))"
        for labels, v in prom(expr, end):
            groups[(labels.get("name", ""), labels.get("layer", ""))][f"p{int(float(q) * 100)}_ms"] = ms(v)
    rows = []
    for (name, layer), g in sorted(groups.items()):
        if not g.get("requests"):
            continue
        rows.append({"service": name, "layer": layer, "requests": g.get("requests", 0), "failed": g.get("failed", 0),
                     "p50_ms": g.get("p50_ms"), "p95_ms": g.get("p95_ms"), "p99_ms": g.get("p99_ms")})
    total_req = prom_one(f"sum(increase(k6_http_reqs_total{{{sel}}}{rng}))", end) or 0
    total_failed = prom_one(f'sum(increase(k6_http_reqs_total{{{sel}, expected_response="false"}}{rng}))', end) or 0
    overall = {"requests": round(total_req), "failed": round(total_failed), "rps": round(total_req / window, 1) if window else None}
    for q in ("0.5", "0.95", "0.99"):
        overall[f"p{int(float(q) * 100)}_ms"] = ms(prom_one(f"histogram_quantile({q}, sum(increase(k6_http_req_duration_seconds{{{sel}}}{rng})))", end))
    overall["vus"] = prom_one(f'max(max_over_time(k6_vus{{testid="{testid}", run="{run}"}}{rng}))', end)
    return {"overall": overall, "by_service_layer": rows}


def collect_server(end, window):
    """GeoServer's view from the access log in Loki: per service, layer and cache result."""
    base = f'{{job="geoserver-access", service!~"{IGNORED_SERVICES}"}}'
    rng = f"[{window}s]"
    groups = defaultdict(dict)
    key = lambda m: (m.get("service", ""), m.get("layer", ""), m.get("cache", ""))
    for m, v in loki(f"sum by (service, layer, cache) (count_over_time({base} {rng}))", end):
        groups[key(m)]["requests"] = round(v)
    for m, v in loki(f'sum by (service, layer, cache) (count_over_time({base} | json | statusCode !~ "2.." {rng}))', end):
        groups[key(m)]["errors"] = round(v)
    for q in ("0.5", "0.95", "0.99"):
        for m, v in loki(f"quantile_over_time({q}, {base} | json | unwrap elapsedTime {rng}) by (service, layer, cache)", end):
            groups[key(m)][f"p{int(float(q) * 100)}_ms"] = round(v / 1000, 2)
    for m, v in loki(f"max_over_time({base} | json | unwrap elapsedTime {rng}) by (service, layer, cache)", end):
        groups[key(m)]["max_ms"] = round(v / 1000, 1)
    for m, v in loki(f"sum by (service, layer, cache) (sum_over_time({base} | json | unwrap elapsedTime {rng}))", end):
        groups[key(m)]["total_s"] = round(v / 1e6, 1)
    rows = [{"service": s, "layer": l, "cache": c, **g} for (s, l, c), g in sorted(groups.items()) if g.get("requests")]
    # Cache hit ratio per service, over cacheable requests.
    hits = defaultdict(lambda: [0, 0])
    for r in rows:
        if r["cache"] in ("hit", "miss"):
            hits[r["service"]][0 if r["cache"] == "hit" else 1] += r["requests"]
    cache = {s: round(h / (h + m), 4) for s, (h, m) in hits.items() if h + m}
    return {"by_service_layer_cache": rows, "cache_hit_ratio": cache}


def collect_jvm(end, window):
    rng = f"[{window}s:5s]"
    j = 'job="geoserver-jvm"'
    return {
        "cpu_cores_mean": prom_one(f"avg_over_time(rate(process_cpu_seconds_total{{{j}}}[30s]){rng})", end),
        "cpu_cores_max": prom_one(f"max_over_time(rate(process_cpu_seconds_total{{{j}}}[30s]){rng})", end),
        "heap_used_max_bytes": prom_one(f'max_over_time(sum(jvm_memory_used_bytes{{{j},area="heap"}}){rng})', end),
        "heap_max_bytes": prom_one(f'max(jvm_memory_max_bytes{{{j},area="heap"}})', end),
        "gc_time_share": prom_one(f"sum(increase(jvm_gc_collection_seconds_sum{{{j}}}[{window}s])) / {window}", end),
        "tomcat_busy_threads_max": prom_one(f"max_over_time(sum(tomcat_threadpool_currentthreadsbusy{{{j}}}){rng})", end),
        "tomcat_max_threads": prom_one(f"max(tomcat_threadpool_maxthreads{{{j}}})", end),
    }


def collect_database(end, window):
    rng = f"[{window}s]"
    db = 'datname="gis"'
    inc = lambda m: prom_one(f"sum(increase({m}{{{db}}}{rng}))", end)
    returned, fetched = inc("pg_stat_database_tup_returned"), inc("pg_stat_database_tup_fetched")
    hit, read = inc("pg_stat_database_blks_hit"), inc("pg_stat_database_blks_read")
    out = {
        "rows_scanned": returned,
        "rows_returned": fetched,
        "scanned_per_returned": round(returned / fetched, 2) if returned and fetched else None,
        "buffer_hit_ratio": round(hit / (hit + read), 4) if hit is not None and read is not None and hit + read else None,
        "blocks_read": read,
        "temp_bytes": inc("pg_stat_database_temp_bytes"),
        "active_connections_max": prom_one(f'max_over_time(sum(pg_stat_activity_count{{{db},state="active"}})[{window}s:5s])', end),
        "connections_max": prom_one(f"max_over_time(sum(pg_stat_activity_count{{{db}}})[{window}s:5s])", end),
    }
    # Statements run by GeoServer during the window. postgres_exporter reports
    # the 50 statements with the highest total time since the last reset.
    sel = f'{db}, user="geoserver"'
    times = prom(f"topk(10, sum by (queryid) (increase(pg_stat_statements_seconds_total{{{sel}}}{rng})) > 0)", end)
    calls = {m["queryid"]: v for m, v in prom(f"sum by (queryid) (increase(pg_stat_statements_calls_total{{{sel}}}{rng}))", end)}
    rows_ = {m["queryid"]: v for m, v in prom(f"sum by (queryid) (increase(pg_stat_statements_rows_total{{{sel}}}{rng}))", end)}
    text = {m["queryid"]: m.get("query", "") for m, _ in prom("max by (queryid, query) (pg_stat_statements_query_id)", end)}
    statements = []
    for m, t in sorted(times, key=lambda x: -x[1]):
        qid = m["queryid"]
        c = calls.get(qid) or 0
        statements.append({
            "queryid": qid, "total_s": round(t, 2), "calls": round(c),
            "mean_ms": round(t / c * 1000, 2) if c else None,
            "rows_per_call": round(rows_.get(qid, 0) / c, 1) if c else None,
            "query": text.get(qid, ""),
        })
    out["top_statements"] = statements
    return out


def collect_slow_plans(start, end, limit=5):
    """auto_explain entries (statements over 500 ms) logged by PostgreSQL."""
    plans = []
    for line in loki_lines('{service="postgis"} |= "duration:" |= "plan:"', start, end, limit=500):
        m = re.search(r"duration: ([\d.]+) ms", line)
        if m:
            plans.append((float(m.group(1)), line))
    plans.sort(key=lambda p: -p[0])

    def tidy(text):
        # Drop bind parameters and shorten geometry literals: long hex strings
        # that make plans hard to read.
        lines = [l for l in text.splitlines() if "Query Parameters:" not in l]
        return re.sub(r"'(?:\\x)?[0-9A-Fa-f]{40,}'", "'<geometry>'", "\n".join(lines[:25]))

    return {
        "count": len(plans),
        "slowest": [{"duration_ms": d, "plan": tidy(text)} for d, text in plans[:limit]],
    }


def collect_warnings(end, window):
    """GeoServer log lines at WARN and above, grouped by message with numbers masked."""
    q = (
        'sum by (level, logger, msg) (count_over_time({service="geoserver"} '
        '|~ "^\\\\d{2} \\\\w{3} [\\\\d:]{8} (WARN|ERROR|SEVERE) " '
        '| regexp "^\\\\S+ \\\\S+ \\\\S+ (?P<level>\\\\w+)\\\\s+\\\\[(?P<logger>[^\\\\]]+)\\\\] - (?P<msg>.*)" '
        '| label_format msg=`{{ regexReplaceAll "[0-9]+" .msg "N" | trunc 200 }}` '
        f"[{window}s]))"
    )
    rows = [{"count": round(v), "level": m.get("level", ""), "logger": m.get("logger", ""), "message": m.get("msg", "")} for m, v in loki(q, end)]
    return sorted(rows, key=lambda r: -r["count"])[:10]


def collect_resources(path, start, end):
    """Container CPU (% of one core) and memory from docker stats samples."""
    units = {"B": 1, "KiB": 1024, "MiB": 1024**2, "GiB": 1024**3, "kB": 1000, "MB": 1000**2, "GB": 1000**3}
    cpu, mem = defaultdict(list), defaultdict(list)
    if not os.path.exists(path):
        return {}
    for line in open(path, encoding="utf-8"):
        parts = line.rstrip("\n").split("\t")
        if len(parts) != 4 or not (start <= int(parts[0]) <= end):
            continue
        name = parts[1].removeprefix("jgis-").removesuffix("-1")
        name = "k6" if name.startswith("k6-run") else "report" if name.startswith("report-run") else name
        try:
            cpu[name].append(float(parts[2].rstrip("%")))
            used = parts[3].split("/")[0].strip()
            num, unit = re.match(r"([\d.]+)\s*(\w+)", used).groups()
            mem[name].append(float(num) * units.get(unit, 1))
        except (ValueError, AttributeError):
            continue
    return {
        name: {"cpu_cores_mean": round(statistics.mean(v) / 100, 2), "cpu_cores_max": round(max(v) / 100, 2),
               "mem_max_bytes": round(max(mem[name])) if mem[name] else None}
        for name, v in sorted(cpu.items()) if v
    }


# JFR: components, matched on the leaf-most frame that belongs to one.
COMPONENTS = [
    ("PostgreSQL JDBC", ("org.postgresql.",)),
    ("Vector tile encoding", ("org.geoserver.wms.vector.", "org.geoserver.wms.mapbox.", "no.ecc.vectortile.", "com.wdtinc.")),
    ("Image encoding (PNG/JPEG)", ("it.geosolutions.imageio.", "javax.imageio.", "com.sun.imageio.", "org.geoserver.wms.map.PNG", "ar.com.hjg.pngj.")),
    ("Java2D rasterizing (Marlin)", ("sun.java2d.", "java.awt.")),
    ("Label rendering", ("org.geotools.renderer.label.",)),
    ("GeoTools rendering", ("org.geotools.renderer.",)),
    ("Reprojection and geometry transforms", ("org.geotools.referencing.", "org.geotools.geometry.", "org.geotools.renderer.crs.")),
    ("Style and filter evaluation", ("org.geotools.styling.", "org.geotools.filter.", "org.geotools.api.filter.")),
    ("GeoTools JDBC and feature reading", ("org.geotools.jdbc.", "org.geotools.data.", "org.geotools.feature.")),
    ("JTS geometry", ("org.locationtech.jts.",)),
    ("GeoWebCache", ("org.geowebcache.",)),
    ("GeoServer", ("org.geoserver.",)),
    ("Logging", ("org.apache.logging.", "java.util.logging.", "org.geotools.util.logging.")),
    ("Tomcat and networking", ("org.apache.catalina.", "org.apache.coyote.", "org.apache.tomcat.", "sun.nio.", "java.net.")),
    ("JDK", ("java.", "jdk.", "sun.")),
]
INTERESTING = ("org.geoserver.", "org.geotools.", "org.geowebcache.", "org.locationtech.jts.", "org.postgresql.", "sun.java2d.marlin.", "it.geosolutions.")


GENERIC = ("JDK", "Tomcat and networking")


def component(frames):
    """Component of the leaf-most frame that belongs to one, skipping JDK and
    Tomcat frames (an ArrayList.add called from JTS counts as JTS)."""
    # Logging anywhere in the stack wins: the time is spent because of it.
    if any(f.startswith(("org.apache.logging.", "java.util.logging.")) for f in frames):
        return "Logging"
    for generic_ok in (False, True):
        for f in frames:
            for name, prefixes in COMPONENTS:
                if (generic_ok or name not in GENERIC) and f.startswith(prefixes):
                    return name
    return "Other"


def collect_profile(rdir):
    samples_path = os.path.join(rdir, "jfr-samples.txt")
    if not os.path.exists(samples_path):
        return None
    events, current, in_stack = [], None, False
    for line in open(samples_path, encoding="utf-8", errors="replace"):
        s = line.strip()
        if s.startswith("jdk.ExecutionSample") or s.startswith("jdk.NativeMethodSample"):
            current = {"type": "native" if "Native" in s else "cpu", "thread": "", "frames": []}
        elif current is None:
            continue
        elif s.startswith("sampledThread ="):
            current["thread"] = s.split('"')[1] if '"' in s else s
        elif s.startswith("stackTrace = ["):
            in_stack = True
        elif in_stack and s == "]":
            in_stack = False
        elif in_stack and s not in ("...",):
            frame = re.sub(r"\(.*$", "", s)
            current["frames"].append(frame)
        elif s == "}" and current:
            events.append(current)
            current = None
    # Tomcat's request worker threads; the acceptor and poller threads are idle waits.
    request = [e for e in events if re.match(r"http-nio-\d+-exec-", e["thread"]) and e["frames"]]
    cpu = [e for e in request if e["type"] == "cpu"]
    native = [e for e in request if e["type"] == "native"]
    if not cpu:
        return {"cpu_samples": 0}
    comp = Counter(component(e["frames"]) for e in cpu)
    self_time = Counter(e["frames"][0] for e in cpu)
    inclusive = Counter()
    for e in cpu:
        for f in set(e["frames"]):
            if f.startswith(INTERESTING):
                inclusive[f] += 1
    native_top = Counter(next((f for f in e["frames"] if f.startswith(INTERESTING)), e["frames"][0]) for e in native)
    n = len(cpu)
    hot_methods = ""
    hot_path = os.path.join(rdir, "jfr-hot-methods.txt")
    if os.path.exists(hot_path):
        hot_methods = "\n".join(open(hot_path, encoding="utf-8").read().strip().splitlines()[:25])
    return {
        "cpu_samples": n,
        "native_samples": len(native),
        "components": [{"component": c, "share": round(k / n, 4)} for c, k in comp.most_common()],
        "self": [{"method": m, "share": round(k / n, 4)} for m, k in self_time.most_common(15)],
        # Frames on nearly every stack (request dispatch) say little; leave them out.
        "inclusive": [{"method": m, "share": round(k / n, 4)} for m, k in inclusive.most_common(60) if k / n < 0.85][:25],
        "native_waits": [{"frame": f, "samples": k} for f, k in native_top.most_common(8)],
        "jfr_hot_methods": hot_methods,
    }


# ---------------------------------------------------------------------------
# Findings: rule-of-thumb flags that point at where to look
# ---------------------------------------------------------------------------


def findings(r):
    out = []
    ctx = r["context"]
    cores = float(ctx.get("DOCKER_NCPU") or 0)
    client = r["client"]["overall"]
    if client.get("failed"):
        out.append(f"{client['failed']} of {client['requests']} requests failed.")
    for svc, ratio in r["server"]["cache_hit_ratio"].items():
        if ratio >= 0.9:
            out.append(f"{svc}: {pct(ratio)} tile cache hits. Latency for this service mostly measures GeoWebCache, not rendering "
                       "(use COLD_CACHE=true or look at the cache=miss rows).")
    misses = [x for x in r["server"]["by_service_layer_cache"] if x["cache"] == "miss" and x.get("requests", 0) >= 20]
    if misses:
        worst = max(misses, key=lambda x: x.get("p95_ms") or 0)
        out.append(f"Slowest uncached tiles: {worst['layer']} ({worst['service']}), P95 {fmt_ms(worst.get('p95_ms'))} ms over {worst['requests']} misses.")
    for x in r["server"]["by_service_layer_cache"]:
        if x["cache"] == "hit" and x.get("requests", 0) >= 20 and (x.get("p95_ms") or 0) > 50 and (x.get("p95_ms") or 0) > 10 * (x.get("p50_ms") or 1):
            out.append(f"Cache hits for {x['layer']} ({x['service']}) have P50 {fmt_ms(x.get('p50_ms'))} ms but P95 {fmt_ms(x.get('p95_ms'))} ms "
                       f"and max {fmt_ms(x.get('max_ms'))} ms: most likely requests waiting for another request to render the same "
                       "GeoWebCache metatile, so they cost what the render costs.")
    heavy = sorted(r["server"]["by_service_layer_cache"], key=lambda x: -(x.get("total_s") or 0))[:1]
    if heavy and heavy[0].get("total_s"):
        total = sum(x.get("total_s") or 0 for x in r["server"]["by_service_layer_cache"])
        h = heavy[0]
        out.append(f"Most server time: {h['layer'] or '-'} / {h['service']} / cache={h['cache']}: {h['total_s']} s, "
                   f"{pct(h['total_s'] / total) if total else '-'} of all request time.")
    jvm = r["jvm"]
    if cores and jvm.get("cpu_cores_max") and jvm["cpu_cores_max"] > 0.8 * cores:
        out.append(f"GeoServer CPU peaked at {jvm['cpu_cores_max']:.1f} of {cores:.0f} cores: CPU-bound.")
    if jvm.get("tomcat_max_threads") and jvm.get("tomcat_busy_threads_max") and jvm["tomcat_busy_threads_max"] >= 0.8 * jvm["tomcat_max_threads"]:
        out.append("Tomcat busy threads reached 80% of the maximum: requests may queue.")
    if jvm.get("gc_time_share") and jvm["gc_time_share"] > 0.05:
        out.append(f"GC took {pct(jvm['gc_time_share'])} of wall time: heap pressure.")
    if jvm.get("heap_max_bytes") and jvm.get("heap_used_max_bytes") and jvm["heap_used_max_bytes"] > 0.85 * jvm["heap_max_bytes"]:
        out.append("Heap use peaked above 85% of the maximum.")
    db = r["database"]
    if db.get("scanned_per_returned") and db["scanned_per_returned"] > 3:
        out.append(f"PostgreSQL scanned {db['scanned_per_returned']}x more rows than it returned: filters applied after the index, "
                   "or sequential scans. See top statements and slow plans.")
    if db.get("buffer_hit_ratio") is not None and db["buffer_hit_ratio"] < 0.95:
        out.append(f"PostgreSQL buffer cache hit ratio {pct(db['buffer_hit_ratio'])}: data read from disk or OS cache.")
    if db.get("temp_bytes"):
        out.append(f"PostgreSQL wrote {db['temp_bytes'] / 1e6:.0f} MB of temp files: sorts or hashes exceeded work_mem.")
    if r["slow_plans"]["count"]:
        out.append(f"{r['slow_plans']['count']} statements took over 500 ms (plans below).")
    total_requests = sum(x.get("requests", 0) for x in r["server"]["by_service_layer_cache"])
    for w in r["warnings"][:3]:
        if w["count"] >= 100:
            per = f", {w['count'] / total_requests:.1f} per request" if total_requests else ""
            out.append(f"GeoServer logged '{w['message'][:90]}' {w['count']:,} times{per}.")
    prof = r.get("profile") or {}
    if prof.get("components"):
        top = prof["components"][0]
        out.append(f"JFR: largest share of GeoServer request CPU is {top['component']} ({pct(top['share'])}).")
    for name, res in r.get("resources", {}).items():
        if cores and res["cpu_cores_max"] > 0.8 * cores:
            out.append(f"Container {name} peaked at {res['cpu_cores_max']} of {cores:.0f} cores.")
    if (res := r.get("resources", {}).get("k6")) is not None and cores and res["cpu_cores_max"] > 0.25 * cores:
        out.append("k6 used over a quarter of the machine's CPU: the load generator competes with the stack.")
    return out


# ---------------------------------------------------------------------------
# Rendering
# ---------------------------------------------------------------------------


def render_context(r):
    ctx, st = r["context"], r["settings"]
    changed = {k: v for k, v in st.items() if f"SETTING_{k}" in ctx}
    lines = [
        f"- Test: `{ctx.get('TESTID')}`, scenario `{ctx.get('SCENARIO')}`",
        f"- Code: commit `{ctx.get('GIT_COMMIT')}` on `{ctx.get('GIT_BRANCH')}`"
        + (f", **{ctx.get('GIT_DIRTY_FILES')} uncommitted changes**" if ctx.get("GIT_DIRTY_FILES", "0") != "0" else ""),
        f"- Machine: {ctx.get('DOCKER_NCPU')} CPUs and {int(ctx.get('DOCKER_MEM_BYTES', 0)) / 2**30:.1f} GiB for Docker "
        f"({ctx.get('DOCKER_OS')}, Docker {ctx.get('DOCKER_VERSION')}); host {ctx.get('HOST_CPU', '?')}",
        f"- Load: {st['VUS']} users for {st['DURATION']}" + (f" after {st['WARMUP']} warm-up" if st.get("WARMUP") else "")
        + f", seed {st['SEED']}" + (", cold tile cache" if st.get("COLD_CACHE") == "true" else ""),
        f"- Settings changed from defaults: {', '.join(f'{k}={v}' for k, v in changed.items()) or 'none'}",
    ]
    return "\n".join(lines)


def render_run(r):
    c = r["client"]["overall"]
    out = [f"# Load test run {r['run']} of `{r['context'].get('TESTID')}`", "", render_context(r),
           f"- Measured window: {r['window_s']} s", ""]
    out += ["## Findings", ""] + [f"- {f}" for f in r["findings"] or ["Nothing stood out."]] + [""]
    out += ["## Client (k6)", "",
            f"{fmt_num(c['requests'])} requests, {c['rps']} req/s, {c['failed']} failed, up to {fmt_num(c.get('vus'))} users. "
            f"P50 {fmt_ms(c['p50_ms'])} ms, P95 {fmt_ms(c['p95_ms'])} ms, P99 {fmt_ms(c['p99_ms'])} ms.", "",
            md_table(["service", "layer", "requests", "failed", "P50 ms", "P95 ms", "P99 ms"],
                     [[x["service"], x["layer"], fmt_num(x["requests"]), x["failed"], fmt_ms(x["p50_ms"]), fmt_ms(x["p95_ms"]), fmt_ms(x["p99_ms"])]
                      for x in r["client"]["by_service_layer"]]), ""]
    s = r["server"]
    out += ["## GeoServer (access log)", "",
            "Cache hit ratio: " + (", ".join(f"{k} {pct(v)}" for k, v in s["cache_hit_ratio"].items()) or "no cached requests") + ".", "",
            md_table(["service", "layer", "cache", "requests", "errors", "P50 ms", "P95 ms", "P99 ms", "max ms", "total s"],
                     [[x["service"], x["layer"], x["cache"], fmt_num(x["requests"]), x.get("errors", 0), fmt_ms(x.get("p50_ms")),
                       fmt_ms(x.get("p95_ms")), fmt_ms(x.get("p99_ms")), fmt_ms(x.get("max_ms")), x.get("total_s", "-")]
                      for x in sorted(s["by_service_layer_cache"], key=lambda x: -(x.get("total_s") or 0))]), ""]
    j = r["jvm"]
    gib = lambda b: "-" if b is None else f"{b / 2**30:.2f} GiB"
    out += ["## Resources", "",
            f"GeoServer JVM: CPU mean {fmt_num(j['cpu_cores_mean'], 2)} / max {fmt_num(j['cpu_cores_max'], 2)} cores, "
            f"heap max {gib(j['heap_used_max_bytes'])} of {gib(j['heap_max_bytes'])}, GC {pct(j['gc_time_share'])} of wall time, "
            f"Tomcat busy threads max {fmt_num(j['tomcat_busy_threads_max'])} of {fmt_num(j['tomcat_max_threads'])}.", ""]
    if r.get("resources"):
        out += [md_table(["container", "CPU mean (cores)", "CPU max (cores)", "memory max"],
                         [[k, v["cpu_cores_mean"], v["cpu_cores_max"], gib(v["mem_max_bytes"])] for k, v in r["resources"].items()]), ""]
    d = r["database"]
    out += ["## PostgreSQL", "",
            f"Rows scanned {fmt_num(d['rows_scanned'])}, returned {fmt_num(d['rows_returned'])} (ratio {d['scanned_per_returned']}). "
            f"Buffer hit ratio {pct(d['buffer_hit_ratio'])}, blocks read {fmt_num(d['blocks_read'])}, temp {fmt_num(d['temp_bytes'])} bytes. "
            f"Connections max {fmt_num(d['connections_max'])} ({fmt_num(d['active_connections_max'])} active).", "",
            "Top statements by total time (GeoServer role):", "",
            md_table(["total s", "calls", "mean ms", "rows/call", "query"],
                     [[x["total_s"], fmt_num(x["calls"]), fmt_ms(x["mean_ms"]), x["rows_per_call"], "`" + x["query"][:160].replace("|", "\\|") + "`"]
                      for x in d["top_statements"]]), ""]
    if r["slow_plans"]["slowest"]:
        out += [f"Slowest statements over 500 ms ({r['slow_plans']['count']} in total):", ""]
        for p in r["slow_plans"]["slowest"][:3]:
            out += ["```", p["plan"], "```", ""]
    out += ["## GeoServer warnings", ""]
    out += [md_table(["count", "level", "logger", "message"], [[fmt_num(w["count"]), w["level"], w["logger"], w["message"][:140]] for w in r["warnings"]])
            if r["warnings"] else "None.", ""]
    p = r.get("profile")
    if p and p.get("cpu_samples"):
        out += ["## CPU profile (JFR, GeoServer request threads)", "",
                f"{p['cpu_samples']} CPU samples, {p['native_samples']} native (blocked) samples.", "",
                md_table(["component", "share of CPU"], [[x["component"], pct(x["share"])] for x in p["components"]]), "",
                "Inclusive (method is on the stack):", "",
                md_table(["share", "method"], [[pct(x["share"]), f"`{x['method']}`"] for x in p["inclusive"][:15]]), "",
                "Self (method is at the top of the stack):", "",
                md_table(["share", "method"], [[pct(x["share"]), f"`{x['method']}`"] for x in p["self"][:10]]), ""]
        if p["native_waits"]:
            out += ["Blocked in native code, by nearest GeoServer/GeoTools/JDBC frame:", "",
                    md_table(["samples", "frame"], [[x["samples"], f"`{x['frame']}`"] for x in p["native_waits"]]), ""]
    return "\n".join(out)


# ---------------------------------------------------------------------------
# Commands
# ---------------------------------------------------------------------------


def cmd_run(rdir):
    test_dir = os.path.dirname(os.path.dirname(rdir.rstrip("/")))
    ctx = read_env(os.path.join(test_dir, "context.env"))
    run = read_env(os.path.join(rdir, "run.env"))
    start, mstart, end = int(run["START"]), int(run["MEASURE_START"]), int(run["END"])
    window = max(end - mstart, 1)
    r = {
        "run": int(run["RUN"]), "context": ctx, "settings": settings(ctx),
        "start": start, "measure_start": mstart, "end": end, "window_s": window,
        "client": collect_client(ctx["TESTID"], run["RUN"], end, end - start + 5),
        "server": collect_server(end, window),
        "jvm": collect_jvm(end, window),
        "database": collect_database(end, window),
        "slow_plans": collect_slow_plans(mstart, end),
        "warnings": collect_warnings(end, window),
        "resources": collect_resources(os.path.join(rdir, "resources.tsv"), mstart, end),
        "profile": collect_profile(rdir),
    }
    r["client"]["overall"]["rps"] = round(r["client"]["overall"]["requests"] / window, 1)
    r["findings"] = findings(r)
    json.dump(r, open(os.path.join(rdir, "report.json"), "w", encoding="utf-8"), indent=2)
    open(os.path.join(rdir, "report.md"), "w", encoding="utf-8").write(render_run(r) + "\n")
    print(f"Wrote {rdir}/report.md")


# Metrics compared across runs and tests: key -> (value, better when lower,
# number of requests behind the value or None).
def key_metrics(r):
    m = {}
    c = r["client"]["overall"]
    m["client rps"] = (c["rps"], False, None)
    for q in ("p50", "p95", "p99"):
        m[f"client {q} ms"] = (c[f"{q}_ms"], True, c["requests"])
    for x in r["client"]["by_service_layer"]:
        m[f"client p95 ms: {x['service']} {x['layer']}"] = (x["p95_ms"], True, x["requests"])
    for x in r["server"]["by_service_layer_cache"]:
        if x.get("requests", 0) >= 20:
            m[f"server p95 ms: {x['service']} {x['layer']} {x['cache']}"] = (x.get("p95_ms"), True, x["requests"])
    for svc, v in r["server"]["cache_hit_ratio"].items():
        m[f"cache hit ratio: {svc}"] = (v, False, None)
    m["geoserver cpu cores mean"] = (r["jvm"]["cpu_cores_mean"], True, None)
    m["gc time share"] = (r["jvm"]["gc_time_share"], True, None)
    m["pg rows scanned per returned"] = (r["database"]["scanned_per_returned"], True, None)
    m["statements over 500 ms"] = (r["slow_plans"]["count"], True, None)
    m["geoserver warnings"] = (sum(w["count"] for w in r["warnings"]), True, None)
    return m


def cmd_aggregate(test_dir):
    runs_dir = os.path.join(test_dir, "runs")
    runs = [json.load(open(os.path.join(runs_dir, n, "report.json"), encoding="utf-8"))
            for n in sorted(os.listdir(runs_dir), key=int) if os.path.exists(os.path.join(runs_dir, n, "report.json"))]
    if not runs:
        sys.exit("No run reports found")
    per_run = [key_metrics(r) for r in runs]
    metrics = {}
    for key in per_run[0]:
        values = [pr[key][0] for pr in per_run if key in pr and pr[key][0] is not None]
        if not values:
            continue
        med = statistics.median(values)
        samples = [pr[key][2] for pr in per_run if key in pr and pr[key][2] is not None]
        metrics[key] = {"median": med, "min": min(values), "max": max(values), "lower_is_better": per_run[0][key][1],
                        "spread": round((max(values) - min(values)) / med, 4) if med else 0.0, "values": values,
                        "min_samples": min(samples) if samples else None}
    agg = {"context": runs[0]["context"], "settings": runs[0]["settings"], "runs": len(runs), "metrics": metrics,
           "findings_last_run": runs[-1]["findings"]}
    json.dump(agg, open(os.path.join(test_dir, "report.json"), "w", encoding="utf-8"), indent=2)

    out = [f"# Load test `{agg['context'].get('TESTID')}`", "", render_context(runs[0]), f"- Runs: {len(runs)}", ""]
    out += ["## Findings (last run)", ""] + [f"- {f}" for f in agg["findings_last_run"] or ["Nothing stood out."]] + [""]
    if len(runs) > 1:
        out += ["## Key metrics over all runs", "", "Spread is (max - min) / median; use it to judge whether a later change is noise.", "",
                md_table(["metric", "median", "min", "max", "spread"],
                         [[k, fmt_num(v["median"], 2), fmt_num(v["min"], 2), fmt_num(v["max"], 2), pct(v["spread"])] for k, v in metrics.items()]), ""]
    out += [f"## Run details", ""] + [f"- [Run {r['run']}](runs/{r['run']}/report.md)" for r in runs] + [""]
    if len(runs) == 1:
        out += ["---", "", render_run(runs[0]).split("\n", 1)[1]]
    open(os.path.join(test_dir, "report.md"), "w", encoding="utf-8").write("\n".join(out) + "\n")
    print(f"Wrote {test_dir}/report.md")


def cmd_compare(base_dir, test_dir):
    base = json.load(open(os.path.join(base_dir, "report.json"), encoding="utf-8"))
    test = json.load(open(os.path.join(test_dir, "report.json"), encoding="utf-8"))
    rows, better, worse = [], 0, 0
    for key, t in test["metrics"].items():
        b = base["metrics"].get(key)
        if not b or b["median"] in (None, 0) or t["median"] is None:
            continue
        change = (t["median"] - b["median"]) / abs(b["median"])
        noise = max(NOISE, b["spread"], t["spread"])
        few = [x for x in (b.get("min_samples"), t.get("min_samples")) if x is not None and x < MIN_SAMPLES]
        if abs(change) <= noise:
            verdict = "same"
        elif few:
            verdict = f"unclear (n={min(few)})"
        elif (change < 0) == t["lower_is_better"]:
            verdict, better = "better", better + 1
        else:
            verdict, worse = "worse", worse + 1
        rows.append((abs(change) if verdict != "same" else -1, [key, fmt_num(b["median"], 2), fmt_num(t["median"], 2), f"{change * 100:+.1f}%", verdict]))
    rows.sort(key=lambda x: -x[0])
    bs, ts = dict(base["settings"]), dict(test["settings"])
    bs["PROFILE"], ts["PROFILE"] = base["context"].get("PROFILE") or "false", test["context"].get("PROFILE") or "false"
    diff_settings = [f"{k}: {bs.get(k)} -> {ts.get(k)}" for k in sorted(set(bs) | set(ts)) if bs.get(k) != ts.get(k)]
    bc, tc = base["context"], test["context"]
    out = [f"# `{tc.get('TESTID')}` compared with `{bc.get('TESTID')}`", "",
           f"- Base: commit `{bc.get('GIT_COMMIT')}`, {base['runs']} run(s). Test: commit `{tc.get('GIT_COMMIT')}`"
           + (f" with {tc.get('GIT_DIRTY_FILES')} uncommitted changes" if tc.get("GIT_DIRTY_FILES", "0") != "0" else "") + f", {test['runs']} run(s).",
           f"- Scenario: {bc.get('SCENARIO')} -> {tc.get('SCENARIO')}" if bc.get("SCENARIO") != tc.get("SCENARIO") else f"- Scenario: {tc.get('SCENARIO')}",
           f"- Settings that differ: {'; '.join(diff_settings) or 'none'}",
           f"- {better} better, {worse} worse, the rest within noise or unclear. Noise is {NOISE * 100:.0f}% or the run-to-run "
           f"spread, whichever is larger; changes in percentiles based on fewer than {MIN_SAMPLES} requests per run are unclear.", "",
           md_table(["metric", "base", "test", "change", "verdict"], [r for _, r in rows]), ""]
    warnings = []
    if bc.get("DOCKER_NCPU") != tc.get("DOCKER_NCPU") or bc.get("DOCKER_MEM_BYTES") != tc.get("DOCKER_MEM_BYTES"):
        warnings.append("The two tests ran with different CPU or memory for Docker.")
    if bs["PROFILE"] != ts["PROFILE"]:
        warnings.append("Only one of the tests ran with PROFILE=true. JFR profiling costs CPU, so latency and throughput are not comparable.")
    if min(base["runs"], test["runs"]) < 3:
        warnings.append("Fewer than 3 runs on one side: the noise estimate is weak. Use REPEAT=3 or more for decisions.")
    for w in reversed(warnings):
        out.insert(2, f"**Warning: {w}**\n")
    text = "\n".join(out) + "\n"
    name = f"compare-{os.path.basename(base_dir.rstrip('/'))}.md"
    open(os.path.join(test_dir, name), "w", encoding="utf-8").write(text)
    print(text)


if __name__ == "__main__":
    if len(sys.argv) >= 3 and sys.argv[1] == "run":
        cmd_run(sys.argv[2])
    elif len(sys.argv) >= 3 and sys.argv[1] == "aggregate":
        cmd_aggregate(sys.argv[2])
    elif len(sys.argv) >= 4 and sys.argv[1] == "compare":
        cmd_compare(sys.argv[2], sys.argv[3])
    else:
        sys.exit(__doc__)

#!/usr/bin/env bash
# Runs a load test and writes a report. Called by `make loadtest`; settings come
# from environment variables (see loadtest/README.md).
#
# Output: loadtest/results/<id>/
#   report.md, report.json     results over all repeats
#   compare-<base>.md          with BASE=<id>
#   runs/<n>/                  per repeat: k6 summary, resource samples,
#                              context, report, JFR profile (with PROFILE=true)
set -euo pipefail

cd "$(dirname "$0")/.."

SCENARIO="${SCENARIO:-tiles}"
REPEAT="${REPEAT:-1}"
COOLDOWN="${COOLDOWN:-15}"
ENV_FILE="${ENV_FILE:-environments/.env}"
COMPOSE=(docker compose --env-file "$ENV_FILE" -f docker-compose.yml -f loadtest/compose.yaml --profile loadtest)

[[ -f "loadtest/scenarios/$SCENARIO.js" ]] || { echo "Unknown SCENARIO '$SCENARIO', see loadtest/scenarios/" >&2; exit 1; }
[[ "$REPEAT" =~ ^[1-9][0-9]*$ ]] || { echo "REPEAT must be a positive integer" >&2; exit 1; }

id="${TESTID:-$(date -u +%Y%m%dT%H%M%SZ)-$SCENARIO}"
dir="loadtest/results/$id"
mkdir -p "$dir"

# "90s", "2m", "1h" -> seconds.
to_seconds() {
  local v="${1:-0}"
  case "$v" in
    "" ) echo 0 ;;
    *h) echo $(( ${v%h} * 3600 )) ;;
    *m) echo $(( ${v%m} * 60 )) ;;
    *s) echo "${v%s}" ;;
    *) echo "$v" ;;
  esac
}
warmup_s="$(to_seconds "${WARMUP:-}")"

# --- Run context, shared by all repeats ------------------------------------
# One KEY=value per line; read by report.py.
{
  echo "TESTID=$id"
  echo "SCENARIO=$SCENARIO"
  echo "REPEAT=$REPEAT"
  echo "PROFILE=${PROFILE:-}"
  # Settings given on the command line; report.py fills in the rest from defaults.json.
  for v in VUS DURATION WARMUP SEED COLD_CACHE TILE_FORMAT TILE_LAYERS WMS_LAYERS FEATURE_LAYERS \
           ZOOMS AREAS VIEW_COLS VIEW_ROWS THINK_MIN THINK_MAX BASE_URL WORKSPACE; do
    [[ -n "${!v:-}" ]] && echo "SETTING_$v=${!v}"
  done
  echo "GIT_COMMIT=$(git rev-parse --short HEAD 2>/dev/null || echo unknown)"
  echo "GIT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo unknown)"
  echo "GIT_DIRTY_FILES=$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')"
  echo "DOCKER_$(docker info --format 'NCPU={{.NCPU}}')"
  echo "DOCKER_$(docker info --format 'MEM_BYTES={{.MemTotal}}')"
  echo "DOCKER_$(docker info --format 'OS={{.OperatingSystem}}')"
  echo "DOCKER_$(docker info --format 'VERSION={{.ServerVersion}}')"
  echo "HOST_OS=$(uname -sr)"
  if [[ -r /proc/cpuinfo ]]; then
    echo "HOST_CPU=$(grep -m1 'model name' /proc/cpuinfo | cut -d: -f2- | sed 's/^ *//')"
  elif command -v sysctl >/dev/null; then
    echo "HOST_CPU=$(sysctl -n machdep.cpu.brand_string 2>/dev/null || true)"
  fi
  echo "IMAGES=$("${COMPOSE[@]}" config --images 2>/dev/null | sort -u | paste -sd, -)"
} > "$dir/context.env"

geoserver_exec() { "${COMPOSE[@]}" exec -T -u tomcat geoserver "$@"; }

# Samples CPU and memory of the stack's containers every few seconds.
sample_resources() {
  local out="$1"
  while true; do
    docker stats --no-stream --format '{{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}' 2>/dev/null \
      | grep '^jgis-' | sed "s/^/$(date +%s)\t/" >> "$out" || true
    sleep 3
  done
}

for (( n = 1; n <= REPEAT; n++ )); do
  rdir="$dir/runs/$n"
  mkdir -p "$rdir"
  echo "=== $id, run $n of $REPEAT"

  jfr_file=""
  if [[ "${PROFILE:-}" == "true" ]]; then
    # Records CPU samples from the end of the warm-up to the end of the run.
    jfr_file="/usr/local/tomcat/logs/jfr-$id-$n.jfr"
    geoserver_exec jcmd 1 JFR.start name=loadtest settings=profile \
      delay="${warmup_s}s" filename="$jfr_file" >/dev/null
  fi

  sample_resources "$rdir/resources.tsv" &
  sampler=$!
  start=$(date +%s)

  set +e
  "${COMPOSE[@]}" run --rm k6 run --quiet \
    --out experimental-prometheus-rw --tag testid="$id" --tag run="$n" \
    --summary-export "results/$id/runs/$n/k6-summary.json" "scenarios/$SCENARIO.js"
  status=$?
  set -e

  end=$(date +%s)
  kill "$sampler" 2>/dev/null; wait "$sampler" 2>/dev/null || true

  {
    echo "RUN=$n"
    echo "START=$start"
    echo "MEASURE_START=$(( start + warmup_s ))"
    echo "END=$end"
    echo "K6_EXIT=$status"
  } > "$rdir/run.env"

  if [[ -n "$jfr_file" ]]; then
    geoserver_exec jcmd 1 JFR.stop name=loadtest >/dev/null || true
    geoserver_exec jfr view --width 200 hot-methods "$jfr_file" > "$rdir/jfr-hot-methods.txt" 2>&1 || true
    geoserver_exec jfr print --events jdk.ExecutionSample,jdk.NativeMethodSample --stack-depth 40 "$jfr_file" > "$rdir/jfr-samples.txt" 2>&1 || true
    "${COMPOSE[@]}" cp "geoserver:$jfr_file" "$rdir/profile.jfr" >/dev/null 2>&1 || true
    geoserver_exec rm -f "$jfr_file" || true
  fi

  # Metrics reach Prometheus and Loki with a short delay.
  sleep 20
  "${COMPOSE[@]}" run --rm report run "results/$id/runs/$n"
  rm -f "$rdir/jfr-samples.txt"

  if (( n < REPEAT )); then sleep "$COOLDOWN"; fi
done

"${COMPOSE[@]}" run --rm report aggregate "results/$id"
if [[ -n "${BASE:-}" ]]; then
  "${COMPOSE[@]}" run --rm report compare "results/$BASE" "results/$id"
fi

set -a; . "./$ENV_FILE"; set +a
first_start=$(grep '^START=' "$dir/runs/1/run.env" | cut -d= -f2)
last_end=$(grep '^END=' "$dir/runs/$REPEAT/run.env" | cut -d= -f2)
echo
echo "Report:  $dir/report.md"
[[ -n "${BASE:-}" ]] && echo "Compare: $dir/compare-$BASE.md"
echo "Grafana: http://127.0.0.1:${GRAFANA_PORT:-8087}/d/jgis-loadtest?var-testid=$id&from=$(( first_start - 30 ))000&to=$(( last_end + 30 ))000"

# The Docker host was short of memory

`host-memory-pressure` · Measurement

## Signal

Linux PSI memory counters on the Docker host: tasks stalled waiting for memory more than 5% of the run (some) or 1% (full).

## Why it matters

When the kernel reclaims memory under pressure, every process slows down, including GeoServer, PostgreSQL and k6. Latency then reflects the machine, not the stack, and runs are not comparable.

## Likely causes

- Other applications or containers on the machine use the memory the stack needs.
- Container memory limits add up to more than the Docker VM has (Docker Desktop and WSL have a fixed VM size).
- Page cache for a large dataset competes with the JVM heap and PostgreSQL buffers.

## Remedies

- Stop other workloads on the machine while testing.
- Lower the stack's limits in `environments/.env` (`*_MEM_LIMIT`, `GEOSERVER_JAVA_OPTS`, `PG_SHARED_BUFFERS`) so the total fits with room to spare.
- Give the Docker VM more memory (Docker Desktop settings, or `memory=` in `.wslconfig`).

## Verify

Run a baseline and a test with the same settings (`REPEAT=3`, same `PROFILE`), then `BASE=<baseline>`. Rerun with the same settings: the finding should be gone and `host memory pressure (some)` near 0. Discard results from runs with this finding.

## Evidence

Not yet verified on the test bed.

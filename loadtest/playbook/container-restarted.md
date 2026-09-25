# A container restarted or was OOM-killed during the run

`container-restarted` · Measurement

## Signal

Restart count or OOM-kill flag of a stack container changed between the start and end of the run.

## Why it matters

A restarted GeoServer or PostgreSQL loses its caches and fails requests while starting. The run does not describe normal operation.

## Likely causes

- The container's memory limit is too low for its configured heap or caches.
- The load is higher than the service can hold in memory (many concurrent large renders).

## Remedies

- Raise the container's `*_MEM_LIMIT` in `environments/.env`, or lower the heap/cache settings so they fit with headroom (for GeoServer, leave about 1 GB of the limit outside the heap).
- Lower `VUS`.

## Verify

Run a baseline and a test with the same settings (`REPEAT=3`, same `PROFILE`), then `BASE=<baseline>`. Rerun: no restarts, and `container-near-memory-limit` should not appear either.

## Evidence

Not yet verified on the test bed.

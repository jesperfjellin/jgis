# Playbook

One entry per finding id in load test reports. Each entry says what the signal
means, likely causes, remedies to try, and how to verify a remedy with a
comparison (`make loadtest ... BASE=<baseline>`). The Evidence section records
measured results of remedies on the test bed (the OSM stack in this repository).

Only keep a remedy when the comparison shows `better` for the metrics named
under Verify, and no `worse` for others.

## Measurement

- [`host-memory-pressure`](host-memory-pressure.md): The Docker host was short of memory
- [`host-cpu-saturated`](host-cpu-saturated.md): The Docker host's CPU was saturated
- [`host-io-bound`](host-io-bound.md): The Docker host was IO-bound
- [`container-restarted`](container-restarted.md): A container restarted or was OOM-killed during the run
- [`container-near-memory-limit`](container-near-memory-limit.md): A container came close to its memory limit
- [`loadgen-cpu`](loadgen-cpu.md): The load generator used a lot of CPU
- [`requests-failed`](requests-failed.md): Requests failed

## Caching

- [`tile-cache-dominates`](tile-cache-dominates.md): Most tile requests were cache hits
- [`metatile-wait`](metatile-wait.md): Cache hits wait for renders

## Rendering

- [`server-time-concentrated`](server-time-concentrated.md): One layer and service took most of GeoServer's time
- [`slow-render`](slow-render.md): Rendered requests for a layer are slow
- [`mvt-simplification-cpu`](mvt-simplification-cpu.md): Vector tile geometry simplification dominates CPU
- [`label-rendering-cpu`](label-rendering-cpu.md): Label placement dominates CPU
- [`reprojection-cpu`](reprojection-cpu.md): Reprojection dominates CPU
- [`image-encoding-cpu`](image-encoding-cpu.md): Image encoding dominates CPU
- [`profile-top-component`](profile-top-component.md): Largest CPU component (for information)

## GeoServer

- [`geoserver-cpu-bound`](geoserver-cpu-bound.md): GeoServer used nearly all CPUs
- [`tomcat-threads-saturated`](tomcat-threads-saturated.md): Tomcat request threads were nearly all busy
- [`jvm-gc-pressure`](jvm-gc-pressure.md): Garbage collection took over 5% of the time
- [`jvm-heap-near-max`](jvm-heap-near-max.md): Heap use came close to the maximum
- [`geoserver-log-flood`](geoserver-log-flood.md): GeoServer logged the same message very often

## PostgreSQL

- [`db-wait`](db-wait.md): Request threads spent much time waiting for PostgreSQL
- [`pg-rows-scanned-ratio`](pg-rows-scanned-ratio.md): PostgreSQL scanned many more rows than it returned
- [`pg-buffer-cache-misses`](pg-buffer-cache-misses.md): PostgreSQL read many blocks from outside its cache
- [`pg-temp-files`](pg-temp-files.md): PostgreSQL wrote temporary files
- [`pg-slow-statements`](pg-slow-statements.md): Statements took over 500 ms

## Adding a finding

1. Add a rule in `findings()` in `loadtest/report/report.py` (or a profile
   signature in `PROFILE_SIGNATURES`) with a new id.
2. Add `<id>.md` here with the same sections, and list it above.

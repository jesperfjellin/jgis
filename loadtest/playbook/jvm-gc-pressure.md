# Garbage collection took over 5% of the time

`jvm-gc-pressure` · GeoServer

## Signal

Time in GC over 5% of wall time (JMX).

## Why it matters

GC time is CPU not spent on requests, and long pauses stall all requests.

## Likely causes

- Heap too small for the working set (caches, concurrent renders).
- High allocation rate from large feature collections or images.

## Remedies

- Raise the heap (`GEOSERVER_JAVA_OPTS`, together with `GEOSERVER_MEM_LIMIT`).
- Reduce per-request allocation: fewer features per request (scale filters, generalization).

## Verify

Run a baseline and a test with the same settings (`REPEAT=3`, same `PROFILE`), then `BASE=<baseline>`. `gc time share` should fall.

## Evidence

Not yet verified on the test bed.

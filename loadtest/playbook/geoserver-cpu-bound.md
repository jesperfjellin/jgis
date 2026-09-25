# GeoServer used nearly all CPUs

`geoserver-cpu-bound` · GeoServer

## Signal

GeoServer's JVM CPU peaked above 80% of the Docker host's CPUs.

## Why it matters

At this point more concurrency only adds queueing. Throughput is limited by CPU per request.

## Likely causes

- Expensive rendering or encoding (see the profile findings).
- Many cache misses.

## Remedies

- Find the CPU consumer with `PROFILE=true` and follow that finding.
- Improve caching (hit ratio, seeding) to avoid renders.

## Verify

Run a baseline and a test with the same settings (`REPEAT=3`, same `PROFILE`), then `BASE=<baseline>`. Mean GeoServer CPU per request (`geoserver cpu cores mean` at the same throughput) should fall.

## Evidence

Not yet verified on the test bed.

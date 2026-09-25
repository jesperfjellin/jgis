# Heap use came close to the maximum

`jvm-heap-near-max` · GeoServer

## Signal

Peak heap use over 85% of `-Xmx`.

## Why it matters

Near the maximum, the JVM collects garbage more often and risks OutOfMemoryError.

## Likely causes

- Heap sized too small for the load.
- Large in-memory structures (big WFS/Features responses, big images).

## Remedies

- Raise `-Xmx` (and the container limit).
- Limit response sizes (feature limits, `maxFeatures`, WMS size limits).

## Verify

Run a baseline and a test with the same settings (`REPEAT=3`, same `PROFILE`), then `BASE=<baseline>`. Peak heap under 85% at the same load; no `jvm-gc-pressure`.

## Evidence

Not yet verified on the test bed.

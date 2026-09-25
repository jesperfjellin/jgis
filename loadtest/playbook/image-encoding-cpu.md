# Image encoding dominates CPU

`image-encoding-cpu` · Rendering

## Signal

PNG/JPEG encoder frames in at least 20% of request CPU samples.

## Why it matters

Encoding large or complex images is CPU-heavy, especially PNG with high compression.

## Likely causes

- Large images (big WMS requests, 512 px tiles).
- Expensive PNG settings.

## Remedies

- Use tiled, cached requests where possible.
- Adjust PNG compression or use 8-bit PNG where quality allows (GeoServer WMS settings).

## Verify

Run a baseline and a test with the same settings (`REPEAT=3`, same `PROFILE`), then `BASE=<baseline>`. Encoding share and WMS P95 should fall.

## Evidence

Not yet verified on the test bed.

# Reprojection dominates CPU

`reprojection-cpu` · Rendering

## Signal

Reprojection or projection-handler frames in at least 15% of request CPU samples.

## Why it matters

Data stored in one CRS and requested in another is transformed on every render.

## Likely causes

- Data stored in a different CRS than clients request (for example EPSG:4326 stored, EPSG:3857 requested).
- Continuous map wrapping on world-scale layers.

## Remedies

- Store (or add a copy of) the geometry in the CRS clients use most.
- Declare the native CRS correctly so GeoServer does not reproject needlessly.

## Verify

Run a baseline and a test with the same settings (`REPEAT=3`, same `PROFILE`), then `BASE=<baseline>`. Reprojection share should fall.

## Evidence

Not yet verified on the test bed.

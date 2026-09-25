# Rendered requests for a layer are slow

`slow-render` · Rendering

## Signal

A layer's requests that are rendered (cache miss, or uncached services such as WMS) have P95 over 500 ms.

## Why it matters

Every cache miss and every uncached request pays this cost, and slow renders hold threads and database connections.

## Likely causes

- Too many features or vertices per tile at that zoom.
- Expensive styles (labels, many rules, complex symbolizers).
- Slow SQL (see PostgreSQL findings).
- CPU-heavy steps shown in the profile.

## Remedies

- Run with `PROFILE=true` to see whether time goes to SQL, geometry processing, rendering or encoding, and follow that finding.
- Filter features by scale in the style so fewer are read and drawn at low zooms.
- Use generalized geometries for low zooms.

## Verify

Run a baseline and a test with the same settings (`REPEAT=3`, same `PROFILE`), then `BASE=<baseline>`. The layer's `cache=miss` (or uncached) P95 should fall.

## Evidence

Not yet verified on the test bed.

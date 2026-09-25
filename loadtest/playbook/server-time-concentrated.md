# One layer and service took most of GeoServer's time

`server-time-concentrated` · Rendering

## Signal

One service/layer/cache combination accounted for more than 30% of total request time in the access log.

## Why it matters

This is where optimisation pays off first. Improving a layer that takes 5% of the time cannot gain more than 5%.

## Likely causes

- A layer with large or complex geometries (land cover, boundaries, coastlines).
- A layer requested at zooms where it has too much detail.
- Cache hits waiting on renders of that layer (`metatile-wait`).

## Remedies

- Look at that layer's `slow-render` and profile findings and its SQL in the top statements.
- Limit the zooms where it is drawn (style scale rules) or its detail (`mvt-simplification-cpu`, generalized tables).

## Verify

Run a baseline and a test with the same settings (`REPEAT=3`, same `PROFILE`), then `BASE=<baseline>`. Its share of total time and its P95 should fall; total time per request should fall.

## Evidence

Not yet verified on the test bed.

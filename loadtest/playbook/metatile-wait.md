# Cache hits wait for renders

`metatile-wait` · Caching

## Signal

Cache hits for a layer have P95 over 50 ms and over 10 times their P50.

## Why it matters

GeoWebCache renders tiles in metatiles (4 x 4 by default) and makes concurrent requests for tiles of the same metatile wait for that render. Those requests are logged as hits but cost as much as the render.

## Likely causes

- Expensive renders for that layer (`slow-render`).
- Large metatiles for vector tiles, where metatiling saves little: every request in the block waits for the whole block.

## Remedies

- Make the render cheaper (see `slow-render`, `mvt-simplification-cpu`).
- Try smaller metatiles for that layer's tile cache (for example 2 x 2 or 1 x 1 for vector tiles) and compare.
- Seed the cache for the zooms users see most.

## Verify

Run a baseline and a test with the same settings (`REPEAT=3`, same `PROFILE`), then `BASE=<baseline>`. Cache-hit P95 for the layer should approach its P50.

## Evidence

Not yet verified on the test bed.

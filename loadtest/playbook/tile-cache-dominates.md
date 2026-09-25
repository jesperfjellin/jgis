# Most tile requests were cache hits

`tile-cache-dominates` · Caching

## Signal

A tile service had a GeoWebCache hit ratio of 90% or more.

## Why it matters

Cache hits cost milliseconds. A test dominated by hits measures GeoWebCache and the disk, not rendering, so changes to data, SQL or styles barely show.

## Likely causes

- The same areas and zooms were requested before (earlier runs, warm-up, users revisiting places).
- Few distinct tiles in the scenario (small `AREAS`, few zoom levels).

## Remedies

- To measure rendering: `COLD_CACHE=true`, look at the `cache=miss` rows, or use the `wms` scenario (never cached).
- To measure a realistic mix: keep the cache, but make sure the cache hit ratio is the same in the tests you compare.

## Verify

Run a baseline and a test with the same settings (`REPEAT=3`, same `PROFILE`), then `BASE=<baseline>`. Compare `cache=miss` rows between tests, or compare tests with the same cache hit ratio.

## Evidence

Not yet verified on the test bed.

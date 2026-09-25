# PostgreSQL scanned many more rows than it returned

`pg-rows-scanned-ratio` · PostgreSQL

## Signal

`tup_returned / tup_fetched` for the database over 3 during the run.

## Why it matters

Rows read and then thrown away cost IO and CPU. For spatial queries this usually means the spatial index finds rows that a later filter (for example a scale-dependent attribute filter from the style) discards.

## Likely causes

- Style filters (`area > x`, `rank >= y`) evaluated after a spatial index scan (`Filter:` lines under `Index Scan` in the plans).
- Sequential scans on tables without a suitable index.

## Remedies

- Partial spatial indexes matching the style's filters, for example `CREATE INDEX ... USING gist (geom) WHERE area > 1e6`.
- Separate generalized tables or materialized views per zoom range that only contain the features shown there.
- Composite indexes (with `btree_gist`) when a scalar filter is very selective.

## Verify

Run a baseline and a test with the same settings (`REPEAT=3`, same `PROFILE`), then `BASE=<baseline>`. `pg rows scanned per returned` should fall, and the affected statements' mean time with it.

## Evidence

Not yet verified on the test bed.

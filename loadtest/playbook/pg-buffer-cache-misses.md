# PostgreSQL read many blocks from outside its cache

`pg-buffer-cache-misses` · PostgreSQL

## Signal

Buffer cache hit ratio below 95% during the run.

## Why it matters

Blocks not in `shared_buffers` come from the OS page cache (fast) or disk (slow). A low ratio on a warm system means the working set does not fit.

## Likely causes

- `shared_buffers` small for the working set.
- Queries touching more pages than needed (see `pg-rows-scanned-ratio`).
- Table not clustered by geometry, so nearby features are spread over many pages.

## Remedies

- Raise `PG_SHARED_BUFFERS` (and `POSTGIS_MEM_LIMIT`).
- `CLUSTER` tables on their spatial index.
- Reduce rows read per request.

## Verify

Run a baseline and a test with the same settings (`REPEAT=3`, same `PROFILE`), then `BASE=<baseline>`. Buffer hit ratio up, `blocks_read` down.

## Evidence

Not yet verified on the test bed.

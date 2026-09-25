# PostgreSQL wrote temporary files

`pg-temp-files` · PostgreSQL

## Signal

Temp bytes during the run over 0.

## Why it matters

Sorts and hashes that do not fit in `work_mem` spill to disk, which is slow.

## Likely causes

- Large sorts (ORDER BY on big result sets, for example paging).
- `work_mem` small for the queries.

## Remedies

- Raise `work_mem` for GeoServer's role (`ALTER ROLE ... SET work_mem`).
- Avoid sorting large results (limits, indexes that match the ORDER BY).

## Verify

Run a baseline and a test with the same settings (`REPEAT=3`, same `PROFILE`), then `BASE=<baseline>`. Temp bytes back to 0.

## Evidence

Not yet verified on the test bed.

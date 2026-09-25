# Statements took over 500 ms

`pg-slow-statements` · PostgreSQL

## Signal

`auto_explain` logged statements slower than 500 ms during the run.

## Why it matters

The plans show exactly which query and access path was slow.

## Likely causes

- See the plan: sequential scans, filters after index scans, large bitmap heap scans, many rows returned.

## Remedies

- Follow the plan: add or adjust indexes, reduce rows per request (scale filters, generalized tables).

## Verify

Run a baseline and a test with the same settings (`REPEAT=3`, same `PROFILE`), then `BASE=<baseline>`. The count of statements over 500 ms should fall, and the top statements' mean time with it.

## Evidence

Not yet verified on the test bed.

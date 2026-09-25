# Request threads spent much time waiting for PostgreSQL

`db-wait` · PostgreSQL

## Signal

Over 30% of request-thread profile samples were blocked in PostgreSQL JDBC socket reads.

## Why it matters

Threads waiting on the database hold connections and Tomcat threads while doing nothing.

## Likely causes

- Slow queries (see `pg-slow-statements`, `pg-rows-scanned-ratio`).
- Large result sets transferred per request.
- Too few connections in the datastore pool for the concurrency.

## Remedies

- Speed up the top statements (indexes, generalized tables, scale filters).
- Size the datastore connection pool for the expected concurrency.

## Verify

Run a baseline and a test with the same settings (`REPEAT=3`, same `PROFILE`), then `BASE=<baseline>`. Native wait samples on JDBC frames should fall.

## Evidence

Not yet verified on the test bed.

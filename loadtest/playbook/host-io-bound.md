# The Docker host was IO-bound

`host-io-bound` · Measurement

## Signal

PSI IO counter: all non-idle tasks stalled on IO more than 10% of the run.

## Why it matters

Reads from disk are orders of magnitude slower than from memory. On an IO-bound host, latency depends on what happens to be cached.

## Likely causes

- The working set (table and index pages touched by the test) does not fit in PostgreSQL's buffers plus the OS page cache.
- GeoWebCache writes many new tiles to disk (cold cache runs).
- Slow or shared disks (network storage, antivirus scanning on Windows hosts).

## Remedies

- Give PostgreSQL and the OS more memory for caching (see `pg-buffer-cache-misses`).
- Reduce the data read per request (`pg-rows-scanned-ratio`, generalized tables).
- Use a warm-up (`WARMUP`) so steady-state caching is measured.

## Verify

Run a baseline and a test with the same settings (`REPEAT=3`, same `PROFILE`), then `BASE=<baseline>`. IO pressure and `blocks_read` in the PostgreSQL section should drop.

## Evidence

Not yet verified on the test bed.

# A container came close to its memory limit

`container-near-memory-limit` · Measurement

## Signal

Peak memory of a container over 90% of its limit (docker stats samples).

## Why it matters

The next step is an OOM kill. For the JVM, memory near the limit also means little room for off-heap buffers and thread stacks.

## Likely causes

- Heap (`-Xmx`) or PostgreSQL buffers are sized too close to the container limit.
- Memory grows with concurrency (renders, connections).

## Remedies

- Raise the limit, or lower the heap/buffers inside it.
- For PostgreSQL, page cache inside the container counts towards the limit but is reclaimable; check whether the peak is cache or process memory before raising it.

## Verify

Run a baseline and a test with the same settings (`REPEAT=3`, same `PROFILE`), then `BASE=<baseline>`. Peak memory under 90% of the limit at the same load.

## Evidence

Not yet verified on the test bed.

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
- Check whether the peak is process memory or page cache before raising the limit. The reported number includes the container's active page cache (for example GeoWebCache writing tiles, or PostgreSQL reading tables), which the kernel reclaims before it kills a process. `docker exec <container> cat /sys/fs/cgroup/memory.stat` shows `anon` (process memory) and `file` (page cache).
- With `PROFILE=true`, JFR's recording buffers add memory to the JVM. A container that is near its limit only in profiled runs is usually fine in normal operation.

## Verify

Run a baseline and a test with the same settings (`REPEAT=3`, same `PROFILE`), then `BASE=<baseline>`. Peak memory under 90% of the limit at the same load.

## Evidence

Not yet verified on the test bed.

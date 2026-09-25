# The Docker host's CPU was saturated

`host-cpu-saturated` · Measurement

## Signal

PSI CPU counter: tasks waited for a CPU more than 50% of the run.

## Why it matters

GeoServer, PostgreSQL and k6 share the machine's CPUs. When they are all busy, latency grows because of CPU queueing, and the load generator itself slows down.

## Likely causes

- The load (`VUS`) is higher than the machine can serve.
- Other processes use CPU during the test.
- An expensive render path (see the CPU profile findings) uses all cores.

## Remedies

- Lower `VUS` to find the load the machine sustains, or run k6 on another machine.
- Reduce render cost (profile findings, `slow-render`), which frees CPU.

## Verify

Run a baseline and a test with the same settings (`REPEAT=3`, same `PROFILE`), then `BASE=<baseline>`. Throughput should stay flat or rise and client P95 fall at the same `VUS`.

## Evidence

Not yet verified on the test bed.

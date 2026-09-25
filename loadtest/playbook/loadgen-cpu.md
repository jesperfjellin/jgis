# The load generator used a lot of CPU

`loadgen-cpu` · Measurement

## Signal

k6 container over a quarter of the machine's CPUs.

## Why it matters

k6 competes with the stack for CPU, which lowers both the load it can generate and the stack's throughput.

## Likely causes

- High `VUS` with short think times.
- Large responses that k6 has to receive.

## Remedies

- Lower `VUS` or raise `THINK_MIN`/`THINK_MAX`.
- Run k6 on a separate machine against the stack's host ports.

## Verify

Run a baseline and a test with the same settings (`REPEAT=3`, same `PROFILE`), then `BASE=<baseline>`. k6 CPU lower; stack metrics unchanged or better.

## Evidence

Not yet verified on the test bed.

# Tomcat request threads were nearly all busy

`tomcat-threads-saturated` · GeoServer

## Signal

Busy Tomcat threads reached 80% of `maxThreads`.

## Why it matters

Once all threads are busy, new requests queue in the connector, and latency grows with the queue.

## Likely causes

- Requests are slow (renders, database waits), so each holds a thread for long.
- The load is higher than GeoServer can serve.

## Remedies

- Make requests faster first; more threads usually only move the queue to the CPU or the database.
- Consider GeoServer's control-flow extension to limit concurrent expensive requests (such as WMS GetMap) so cheap requests are not blocked behind them.

## Verify

Run a baseline and a test with the same settings (`REPEAT=3`, same `PROFILE`), then `BASE=<baseline>`. Busy threads peak lower at the same load, and P99 falls.

## Evidence

Not yet verified on the test bed.

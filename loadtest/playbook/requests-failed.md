# Requests failed

`requests-failed` · Measurement

## Signal

k6 counted responses other than 2xx (or network errors).

## Why it matters

Failed requests are often fast (errors return quickly), which makes latency look better than it is.

## Likely causes

- Requests outside a layer's zoom range or bounds (404).
- Timeouts or errors under load (5xx), for example exhausted database connections.
- Wrong layer names or settings.

## Remedies

- Check the status codes in the Grafana Load test dashboard and the access log (`{job="geoserver-access", status_class!="2xx"}` in Loki).
- Fix the cause before comparing latency.

## Verify

Run a baseline and a test with the same settings (`REPEAT=3`, same `PROFILE`), then `BASE=<baseline>`. Zero failed requests.

## Evidence

Not yet verified on the test bed.

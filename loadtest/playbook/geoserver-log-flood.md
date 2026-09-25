# GeoServer logged the same message very often

`geoserver-log-flood` · GeoServer

## Signal

One log message (numbers masked) appeared at least 100 times and at least once per 10 requests.

## Why it matters

Logging on the request path costs CPU and IO for every occurrence and hides real problems. It usually also points at a data or configuration issue.

## Likely causes

- A data issue the code warns about per feature. For example, `Cannot obtain numeric id from featureId` in vector tile encoding means feature ids are not non-negative integers (MVT feature ids are unsigned).
- A verbose logging profile.

## Remedies

- Fix the cause the message names. For feature ids: publish a non-negative integer primary key (for example map negative ids to positive ones in a view or column).
- Otherwise raise the log level for that logger (GeoServer logging profile).

## Verify

Run a baseline and a test with the same settings (`REPEAT=3`, same `PROFILE`), then `BASE=<baseline>`. The message count should drop to zero or near zero; check whether latency or CPU improved as well.

## Evidence

Not yet verified on the test bed.

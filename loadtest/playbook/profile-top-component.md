# Largest CPU component (for information)

`profile-top-component` · Rendering

## Signal

Always shown with `PROFILE=true`: the component with the largest share of request-thread CPU samples.

## Why it matters

Tells where to look first, even when no specific signature matched.

## Likely causes

- Depends on the component: JTS geometry, GeoTools rendering, vector tile encoding, JDBC, image encoding, GeoWebCache, logging.

## Remedies

- Check the report's inclusive and self method tables for the specific operation, and whether a more specific finding applies.

## Verify

Run a baseline and a test with the same settings (`REPEAT=3`, same `PROFILE`), then `BASE=<baseline>`. The component's share should fall when its cost is reduced.

## Evidence

Not yet verified on the test bed.

# Vector tile geometry simplification dominates CPU

`mvt-simplification-cpu` · Rendering

## Signal

In the JFR profile, `PipelineBuilder$Simplify` in GeoServer's vector tile pipeline is on the stack in at least 25% of request CPU samples.

## Why it matters

GeoServer simplifies every geometry while building a vector tile, with a topology-preserving algorithm whose cost grows quickly with the number of vertices. Detailed polygons (land cover, water, boundaries) at low and middle zooms make this the main cost of a tile.

## Likely causes

- Source geometries with far more vertices than a tile can show at that zoom.
- Large polygons included at zooms where they cover many tiles.

## Remedies

- Serve pre-generalized geometries: extra tables or materialized views with `ST_SimplifyPreserveTopology` (or `ST_Simplify`) per zoom range, selected with style scale rules or GeoTools' pre-generalized datastore. Moves the cost from every tile render to one-off preprocessing.
- Exclude small features at low zooms with style filters (for example on an area column), so fewer geometries reach the simplifier.
- Raise the layer's minimum zoom if the data is not useful at low zooms.

## Verify

Run a baseline and a test with the same settings (`REPEAT=3`, same `PROFILE`), then `BASE=<baseline>`. In a profiled comparison, the Simplify share and the layer's `cache=miss` P95 should both fall.

## Evidence

Not yet verified on the test bed.

# Label placement dominates CPU

`label-rendering-cpu` · Rendering

## Signal

`org.geotools.renderer.label` frames in at least 20% of request CPU samples.

## Why it matters

Label placement checks conflicts between labels and is expensive with many candidates.

## Likely causes

- Labels on dense layers at low zooms.
- Many text symbolizers or complex label options.

## Remedies

- Show labels only at zooms where they are readable (scale rules).
- Label fewer features (filters on importance or population).

## Verify

Run a baseline and a test with the same settings (`REPEAT=3`, same `PROFILE`), then `BASE=<baseline>`. Label share of CPU and the layer's render P95 should fall.

## Evidence

Not yet verified on the test bed.

# Design

## Philosophy

Measurements should be monitored as systems. AssaySentinel stores relationships
— instrument, lot, calibration, batch, controls, units, uncertainty, provenance —
as first-class data.

## Safety

The library answers questions about the **measurement process**. It does not
diagnose disease or recommend treatment. User-facing text repeats that boundary.

## Architecture

```
Raw measurements
      ↓
Unit check (no silent conversion)
      ↓
Missing / NaN policy (omit, never zero-fill)
      ↓
Outlier annotation (deletion is explicit)
      ↓
Baseline / detector
      ↓
Statistical result + statement kind
      ↓
Quality report + provenance
```

Hot paths operate on `Vector{Float64}` extracted from the typed model.
Multiple dispatch selects methods; package extensions keep Makie, Unitful, and
Measurements off the default install.

## Detector interface

```julia
abstract type AbstractDetector end
fit!(detector, baseline)
update!(detector, measurement)
result(detector)
```

Researchers can implement a new detector and run it through `evaluate_detector`
and `simulate_assay`. AssaySentinel is a research platform, not only a fixed
algorithm collection.

## GPU

Computational kernels take arrays. CUDA.jl / AMDGPU.jl are not hard
dependencies. CPU paths are complete.

## False alarms

Streaming alerts require persistence and honor cooldowns. Panel analysis can
apply Benjamini–Hochberg via `bh_adjust` when comparing many analytes.

## Score

`SentinelScore` is a documented weighted penalty on `[0, 100]`. Components are
never hidden. It is analytical stability, not patient risk.

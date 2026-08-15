# Changelog

All notable changes to this project are documented in this file.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project uses [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Reference intervals: `:boxcox`, `:horn`, `:lms`; LMS `reference_curve`
- Passing–Bablok slope and intercept 95% confidence intervals
- `calibration_diagnostics` (runs test, relative error, lack-of-fit)
- Batch correction `:quantile` and `:ruv`; multi-feature ComBat
- Lot/instrument SVG charts in reconstruction HTML; Makie `lot_chart` / `instrument_chart`
- `:auto` change-point selection uses CUSUM crossing count

### Fixed

- PELT no longer prunes new candidates with `min_size` (Killick et al. inequality only)
- Bayesian change-points are Fearnhead (2006) product-partition, not a one-cut shortcut
- `:combat` uses parametric empirical-Bayes shrinkage (Johnson, Li & Rabinovic 2007)
- `:spline` calibration is a natural cubic spline, not linear interpolation

### Added

- `detect_changes(...; method=:turing)` via the Turing.jl extension
- `online_series` and OnlineStats `fit!` / `update!` via the OnlineStats.jl extension
- Live Documenter server (`julia --project=docs docs/live.jl`)
- PNG icons (`icon-256.png`, `icon-512.png`) and `social-preview.png`

## [0.1.0] - 2026-08-14

### Added

- Core measurement, assay, stream, panel, and hierarchical study types
- Unit mismatch protection and explicit `convert_unit`
- Change-point methods: CUSUM, likelihood/SIC, PELT, robust median, rolling Welch, Bayesian, energy scan, and explainable `:auto`
- Drift detection with structured `DriftResult` (linear, sudden, variance, cyclic, distributional, multivariate)
- Composable QC rule engine, Westgard-style rules, `@qcrule`, Levey–Jennings data
- Calibration curves and `compare_calibrations`
- Batch-effect detection separate from optional correction
- Method, instrument, lot, and site comparison
- Reference intervals, Harris–Boyd partitioning evidence, continuous reference curves
- Streaming `Sentinel` with incremental CUSUM/EWMA, persistence, cooldown, and `onalert`
- Provenance records, `explain`, Markdown/HTML/JSON/`.assay` reports
- Simulation, showcase dataset, and `evaluate_detector`
- Optional Makie, Unitful, and Measurements extensions
- CLI (`analyze`, `drift`, `batch`, `reference`, `compare`, `report`, `simulate`, `doctor`, `version`)
- Documentation, CI, and brand assets

[Unreleased]: https://github.com/theworker02/AssaySentinel.jl/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/theworker02/AssaySentinel.jl/releases/tag/v0.1.0

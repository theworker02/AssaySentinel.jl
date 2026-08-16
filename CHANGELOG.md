# Changelog

All notable changes to this project are documented in this file.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project uses [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.5.0] - 2026-08-16

### Added

- First-class `PanelReport`: `analyze(panel)` returns a reconstruction with per-analyte stories, a Sentinel Score chart, HTML/JSON/`.assay` reports, `explain`, and `reconstruct(panel)`
- CLI `panel` for multi-analyte CSV files
- Turing extension: `sampler=:nuts` (continuous-cut models), `ncuts` piecewise means with `model=:multiple`
- Optional Makie `forest_chart` overlay for hierarchical site results (`svg_forest_chart` remains in core)

### Fixed

- Empty CSV files no longer crash the CLI
- Empty, n=1, and all-NaN streams produce closed reports instead of throwing
- `:bayesian` docs now match the Fearnhead product-partition implementation (multiple changes)

## [1.4.0] - 2026-08-15

### Added

- Study reconstruction: `analyze(study, streams)` attaches a dated story, between/within uncertainty budget, forest plot, and provenance graph
- `svg_forest_chart` and HTML/JSON/`.assay` study reports (`report` / `save`)
- Higgins I² and a 95% prediction interval for a new site mean on `HierarchicalSiteResult`
- Per-site standard errors on `SiteEffect`
- `StudySentinel` concordance cooldown and `result(study)` snapshot
- CLI `study` command for multi-site CSV files
- `reconstruct(study, streams)` / `reconstruct(StudyReport)`

### Fixed

- Study-level concordance alerts no longer fire on every subsequent observation
- HTML reports close `</body>` and wrap Markdown lists in `<ul>`
- `hierarchical_sites` table ingest no longer uses wall-clock timestamps for missing times
- Sequential `analyze(panel)` uses independent RNGs per analyte (same as the threaded path)
- Timestamp length is checked in `hierarchical_sites`
- Site-mean heterogeneity with no within-site scatter is no longer labeled as global drift

## [1.3.0] - 2026-08-15

### Added

- Hierarchical multi-site monitoring: `hierarchical_sites`, `StudySentinel`, `StudyReport`
- Reference intervals: `:boxcox`, `:horn`, `:lms`; LMS `reference_curve`
- Passing–Bablok slope and intercept 95% confidence intervals
- `calibration_diagnostics` (runs test, relative error, lack-of-fit)
- Batch correction `:quantile` and `:ruv`; multi-feature ComBat
- Lot/instrument SVG charts in reconstruction HTML; Makie `lot_chart` / `instrument_chart`
- `:auto` change-point selection uses CUSUM crossing count
- `detect_changes(...; method=:turing)` via the Turing.jl extension
- `online_series` and OnlineStats `fit!` / `update!` via the OnlineStats.jl extension
- Live Documenter server (`julia --project=docs docs/live.jl`)
- PNG icons (`icon-256.png`, `icon-512.png`) and `social-preview.png`

### Fixed

- PELT no longer prunes new candidates with `min_size` (Killick et al. inequality only)
- Bayesian change-points are Fearnhead (2006) product-partition, not a one-cut shortcut
- `:combat` uses parametric empirical-Bayes shrinkage (Johnson, Li & Rabinovic 2007)
- `:spline` calibration is a natural cubic spline, not linear interpolation

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

[Unreleased]: https://github.com/theworker02/AssaySentinel.jl/compare/v1.5.0...HEAD
[1.5.0]: https://github.com/theworker02/AssaySentinel.jl/compare/ac0d5aa...HEAD
[1.4.0]: https://github.com/theworker02/AssaySentinel.jl/compare/v1.3.0...ac0d5aa
[1.3.0]: https://github.com/theworker02/AssaySentinel.jl/releases/tag/v1.3.0
[0.1.0]: https://github.com/theworker02/AssaySentinel.jl/releases/tag/v0.1.0

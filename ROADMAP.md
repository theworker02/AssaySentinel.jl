# Roadmap

AssaySentinel versions before 1.0 may change APIs. 1.0 waits until public
APIs, statistical behavior, report schemas, and the provenance format are
genuinely stable.

## v0.1

- Core data model and Tables support
- QC rules and Levey–Jennings data
- CUSUM / likelihood / PELT / robust / Fearnhead Bayesian / energy change detection
- Empirical-Bayes ComBat; natural cubic spline calibration
- Reconstruction reports with embedded SVG charts and provenance graphs
- Turing.jl and OnlineStats.jl extensions; live Documenter (`docs/live.jl`)
- Drift results and multivariate monitors
- Simulation, provenance, documentation

## v0.2 — current

- Quantile and RUV-lite batch correction; multi-feature ComBat
- Calibration diagnostics (runs test, lack-of-fit, 4PL names)
- Lot and instrument comparison charts (core SVG + Makie)
- Box–Cox, Horn, and LMS reference intervals / curves
- Passing–Bablok slope and intercept confidence intervals
- `:auto` uses CUSUM crossing count to prefer PELT for multiple changes

## v0.3

- Automatic detector selection refinements
- Multi-feature ComBat (shrinkage across analytes)
- Stronger Turing models (multiple cuts, hierarchical sites)

## v0.4

- Turing.jl Bayesian extension (change-point probability, hierarchical sites)
- Multi-site hierarchical monitoring
- Advanced continuous reference curves (LMS-style)

## v1.0

Only after:

- Public API freeze
- Statistical behavior freeze for default detectors
- Stable report and provenance schemas
- Independent validation notes

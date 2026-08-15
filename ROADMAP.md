# Roadmap

AssaySentinel 1.3.0 is the current published line. Later 1.x releases stay
backward compatible with the public API frozen since 1.0.

## v1.3.0 — current

- Hierarchical multi-site monitoring (`hierarchical_sites`, `StudySentinel`, `StudyReport`)
- Empirical-Bayes site shrinkage and study-level concordance alerts
- Reference intervals: Box–Cox, Horn, LMS curves
- Passing–Bablok confidence intervals; calibration diagnostics
- Quantile / RUV-lite / multi-feature ComBat batch correction
- Lot and instrument comparison charts (core SVG + Makie)
- Turing.jl and OnlineStats.jl extensions; live Documenter (`docs/live.jl`)

## Later

- Stronger Turing models (multiple cuts, hierarchical site intercepts beyond the extension stub)
- Independent validation notes beyond `VALIDATION.md`
- General registry installation (`Pkg.add("AssaySentinel")`) after JuliaRegistrator

## Compatibility freeze

Only after, and only as a major bump if needed:

- Public API freeze remains (`API_STABLE_SINCE = v"1.0.0"`)
- Statistical behavior freeze for default detectors
- Stable report and provenance schemas
- Independent validation notes

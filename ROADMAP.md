# Roadmap

AssaySentinel 1.4.0 is the current development line. Later 1.x releases stay
backward compatible with the public API frozen since 1.0.

## v1.4.0 — current

- Study reconstruction matching the single-stream path (forest plot, HTML/JSON/`.assay`)
- Higgins I² and 95% prediction intervals on `hierarchical_sites`
- StudySentinel concordance cooldown
- CLI `study`

## Later

- Stronger Turing models (multiple cuts; site intercepts already in the extension)
- Independent validation notes beyond `VALIDATION.md`
- General registry installation (`Pkg.add("AssaySentinel")`) after JuliaRegistrator
- Optional Makie forest / multi-site overlay charts

## Compatibility freeze

Only after, and only as a major bump if needed:

- Public API freeze remains (`API_STABLE_SINCE = v"1.0.0"`)
- Statistical behavior freeze for default detectors
- Stable report and provenance schemas
- Independent validation notes

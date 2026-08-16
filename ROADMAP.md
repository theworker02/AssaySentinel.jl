# Roadmap

AssaySentinel 1.5.0 is the current development line. Later 1.x releases stay
backward compatible with the public API frozen since 1.0.

## v1.5.0 — current

- First-class `PanelReport` matching the study reconstruction path
- Turing NUTS / k-cut models (extension)
- Makie `forest_chart` (extension); SVG forest remains in core

## Later

- Independent validation notes beyond `VALIDATION.md`
- General registry installation (`Pkg.add("AssaySentinel")`) after JuliaRegistrator

## Compatibility freeze

Only after, and only as a major bump if needed:

- Public API freeze remains (`API_STABLE_SINCE = v"1.0.0"`)
- Statistical behavior freeze for default detectors
- Stable report and provenance schemas
- Independent validation notes

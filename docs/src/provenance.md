# Provenance and reports

Every `analyze` call records a provenance chain: function, parameters, package
version, timestamp, input fingerprint, and statement kind.

```julia
save(report, "report.assay")
explain(report)
report(result, "assay-report.html")
```

Formats: `.assay` (Julia serialization), `.json`, `.md`, `.html`.

`QualityReport`, `StudyReport`, and `PanelReport` all follow that path.
Panel reports never pool incompatible units.

`explain` reconstructs the decision path and labels each sentence as
**observed**, **statistical**, **inference**, or **annotation**.

Temporal attribution uses nearby operational events and states the association
score. It never claims causation.

# Examples

See `examples/quickstart.jl` and `examples/showcase.jl` in the repository.

The showcase builds twelve months of synthetic glucose controls, three reagent
lots, two instruments, a calibration event, gradual drift, a variance shift,
and several control failures. `analyze` plus `explain` reconstructs the
analytical story without claiming that a lot change *caused* the shift.

```julia
using AssaySentinel
data = showcase_dataset()
r = analyze(data.stream)
println(r)
println(explain(r))
report(r, "assay-report.html")
```

Multi-site and multi-analyte histories use the same `explain` / `report` path:

```julia
srep = analyze(study, Dict("Lab-A" => a, "Lab-B" => b))
report(srep, "study-report.html")

prep = analyze(panel)
report(prep, "panel-report.html")
```

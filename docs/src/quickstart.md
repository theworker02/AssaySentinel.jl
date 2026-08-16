# Quickstart

```julia
using AssaySentinel
using Dates

stream = AssayStream(
    analyte = :glucose,
    unit = "mg/dL",
    instrument = "Analyzer-A",
)

push!(stream, Measurement(
    value = 101.2,
    timestamp = now(),
    batch = "B104",
    lot = "R22",
    control = true,
))

report = analyze(stream)
println(report)
println(explain(report))
```

## From a table

```julia
result = analyze(
    Assay(name = "Example Assay", analyte = :analyte_x, unit = "mg/dL"),
    table;
    value = :result,
    time = :timestamp,
    lot = :reagent_lot,
    instrument = :instrument,
)
```

Any Tables.jl source is accepted. DataFrames is not required internally.

## Synthetic walkthrough

```julia
sim = simulate_assay(n=800, drift=:step, drift_start=500)
r = analyze(sim.stream)
explain(r)
report(r, "assay-report.html")
```

Twelve months of glucose-like controls, lots, instruments, and a calibration
event: `showcase_dataset()` (see [Examples](@ref)).

## Panels and studies

```julia
prep = analyze(panel)
report(prep, "panel-report.html")

srep = analyze(study, Dict("Lab-A" => stream_a, "Lab-B" => stream_b))
report(srep, "study-report.html")
```

Panel reports do not pool units. Study reports include a forest plot, I², and
a 95% prediction interval for a new site mean (analytical process, not a
clinical reference).

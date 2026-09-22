# Buyer evaluation â€” AssaySentinel.jl

## Goal

In 15â€“45 minutes, verify the Product builds or runs as documented and that proprietary notices are present.

## Steps

1. Confirm root `LICENSE` is proprietary and `ACQUISITION.md` exists.
2. Skim `README.md` install/run claims.
3. Execute:

```
```julia
using AssaySentinel

data = showcase_dataset()
result = analyze(data.stream)
println(result)
explain(result)
report(result, "assay-report.html")
```
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
```julia
srep = analyze(study, Dict("Lab-A" => stream_a, "Lab-B" => stream_b))
explain(srep)
report(srep, "study-report.html")  # forest plot + per-site charts
```
```julia
panel = AssayPanel("chem-14")
push!(panel, glucose_stream)
push!(panel, creatinine_stream)
prep = analyze(panel)
explain(prep)
report(prep, "panel-report.html")  # status chart + per-analyte control charts
```
```julia
using Pkg
Pkg.add(url="https://github.com/theworker02/AssaySentinel.jl")
```
```julia
using Pkg
Pkg.add("AssaySentinel")   # after General registration
```
```

4. Run tests if present (`npm test`, `pytest`, `cargo test`, `go test ./...`, etc.).
5. Record README vs observed behavior gaps in workpapers.

## Pass criteria

- [ ] Clone succeeds
- [ ] Documented happy path works **or** failure is explained
- [ ] Minimal path needs no surprise secrets
- [ ] License notices intact

*Updated: 2026-09-22*

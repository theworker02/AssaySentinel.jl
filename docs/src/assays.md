# Assays

`Assay` names a measurement system. `AssayStream` holds its observations and
operational events. `AssayPanel` monitors many analytes together.

```julia
panel = AssayPanel("chem-14")
push!(panel, stream)
analyze(panel; parallel=true)
```

`Study` → `Site` → `Instrument` is the hierarchical container for multi-site
work. `compare_sites` reports statistical site location differences and
explicitly refuses causal language.

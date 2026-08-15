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

`hierarchical_sites` fits a DerSimonian–Laird / empirical-Bayes site model
(per-site means, between-site τ², shrinkage toward the grand mean) and
attributes sharing as `:global`, `:site_specific`, `:mixed`, or `:stable`.
That label is a statistical description of sharing, not a cause.

```julia
result = hierarchical_sites(values, sites)
analyze(study, Dict("Lab-A" => stream_a, "Lab-B" => stream_b))
```

`StudySentinel` is the streaming counterpart: a study-level alert fires when
enough sites alarm inside the concordance window (default: 2 sites within
7 days).

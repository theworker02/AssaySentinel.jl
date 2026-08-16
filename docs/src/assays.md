# Assays

`Assay` names a measurement system. `AssayStream` holds its observations and
operational events. `AssayPanel` monitors many analytes together.

```julia
panel = AssayPanel("chem-14")
push!(panel, stream)
prep = analyze(panel; parallel=true)
explain(prep)
report(prep, "panel-report.html")
```

`analyze(panel)` returns a `PanelReport` with the same reconstruction /
HTML / JSON / `.assay` path as a `StudyReport`. Units are never pooled
across analytes. `.panel` is an alias of `.name`.

`Study` → `Site` → `Instrument` is the hierarchical container for multi-site
work. `compare_sites` reports statistical site location differences and
explicitly refuses causal language.

`hierarchical_sites` fits a DerSimonian–Laird / empirical-Bayes site model
(per-site means, between-site τ², shrinkage toward the grand mean) and
reports Higgins I² plus a 95% prediction interval for a new site mean.
Sharing is attributed as `:global`, `:site_specific`, `:mixed`, or `:stable`.
That label is a statistical description of sharing, not a cause.

```julia
result = hierarchical_sites(values, sites)
svg_forest_chart(result)
srep = analyze(study, Dict("Lab-A" => stream_a, "Lab-B" => stream_b))
explain(srep)
report(srep, "study-report.html")
```

`StudySentinel` is the streaming counterpart: a study-level alert fires when
enough sites alarm inside the concordance window (default: 2 sites within
7 days), then respects a concordance cooldown so a persistent shared signal
is not re-emitted on every observation.

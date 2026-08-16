# AssaySentinel.jl

```@raw html
<div class="as-hero">
  <p class="as-tagline">Know when the measurement changed before the science does.</p>
  <p>
    A Julia instrument for scientists, assay developers, biostatisticians,
    clinical laboratory researchers, and physicians doing measurement-quality
    or method work. It watches the <em>measurement process</em> — instruments,
    reagent lots, calibrations, batches, controls, and distributions — and
    reconstructs a dated, uncertainty-aware, plotted, provenance-complete
    account of whether that process changed.
  </p>
  <div class="as-hero-links">
    <a href="quickstart/">Quickstart</a>
    <a class="as-ghost" href="examples/">Showcase</a>
    <a class="as-ghost" href="statistical_methods/">Methods</a>
    <a class="as-ghost" href="https://github.com/theworker02/AssaySentinel.jl">GitHub</a>
  </div>
</div>
```

```@raw html
<div class="as-notice">
  <strong>Research use only.</strong>
  This software is intended for research, analytical-quality assessment, method
  development, and scientific decision support. It is <em>not</em> a diagnostic
  medical device and must not independently determine patient diagnosis or treatment.
</div>
```

A result is stored as a system, not a bare number: instrument, lot, calibration,
batch, uncertainty, units, controls, processing history, and provenance travel
together. `analyze` → `explain` → `report` is the intended path from a history
to an auditable reconstruction.

```@raw html
<div class="as-figure">
  <img src="assets/how-it-works.svg" alt="How AssaySentinel reconstructs a measurement history: ingest, detect, reconstruct, deliver" width="880"/>
  <p class="as-caption">Ingest a history, run an explainable detector bank, then reconstruct, explain, and report.</p>
</div>
```

## First reconstruction

```julia
using AssaySentinel

data = showcase_dataset()
result = analyze(data.stream)
println(result)
explain(result)
report(result, "assay-report.html")
```

`showcase_dataset()` is twelve months of synthetic glucose controls: three
reagent lots, two instruments, a calibration event, gradual drift, a variance
shift, and a handful of control failures. The HTML report is the same object
`explain` narrates.

```@raw html
<div class="as-figure">
  <img src="assets/demo.gif" alt="AssaySentinel: analyze, reconstruct, explain, and report a year of assay measurements" width="880"/>
</div>
```

Install until General registration merges:

```julia
using Pkg
Pkg.add(url="https://github.com/theworker02/AssaySentinel.jl")
```

After [the General registry PR](https://github.com/JuliaRegistries/General/pull/164654)
is merged, `Pkg.add("AssaySentinel")` will work. The core package is stdlib-only.

## What it answers

- Did this instrument begin drifting?
- Did a reagent lot change alter the measurement distribution?
- Did a calibration curve shift?
- Is this batch statistically inconsistent with previous batches?
- When did the change most likely begin?
- How confident are we, and can the conclusion be reproduced?

It does **not** diagnose patients, label disease, or independently determine
treatment. Severity labels (`info`, `watch`, `warning`, `critical`) and the
Sentinel Score describe the **analytical process**, not clinical risk.

```@raw html
<div class="as-figure">
  <img src="assets/screenshot-reconstruction.png" alt="Reconstruction story: Stable, Calibration, Lot change, Drift" width="720"/>
  <p class="as-caption">The pedagogical chain scientists read first: Stable → Calibration → Lot change → Drift.</p>
</div>
```

## Walk through the docs

```@raw html
<div class="as-grid">
  <div class="as-card">
    <h3>Get a reconstruction</h3>
    <p><a href="quickstart/">Quickstart</a> and the examples page run <code>analyze</code>, <code>explain</code>, and <code>report</code> on synthetic streams.</p>
  </div>
  <div class="as-card">
    <h3>QC and drift</h3>
    <p><a href="qc/">QC</a>, <a href="drift/">drift / change-points</a>, and <a href="streaming/">streaming sentinels</a> for ongoing surveillance.</p>
  </div>
  <div class="as-card">
    <h3>Lots, sites, methods</h3>
    <p><a href="comparison/">Comparisons</a>, <a href="assays/">studies and panels</a>, <a href="calibration/">calibration</a>, <a href="batches/">batches</a>, and <a href="reference/">reference intervals</a>.</p>
  </div>
  <div class="as-card">
    <h3>Methods and proof</h3>
    <p><a href="statistical_methods/">Statistical methods</a>, <a href="validation/">validation</a>, <a href="provenance/">provenance</a>, and <a href="references/">bibliography</a>.</p>
  </div>
</div>
```

Markdown equivalents: [Quickstart](@ref), [Examples](@ref),
[Quality control](@ref), [Drift and change points](@ref), [Streaming](@ref),
[Method and instrument comparison](@ref), [Calibration](@ref),
[Batch effects](@ref), [Reference intervals](@ref),
[Statistical methods](@ref), [Validation](@ref),
[Provenance and reports](@ref), [References](@ref), [API](@ref),
[Extensions](@ref).

```@raw html
<div class="as-figure">
  <img src="assets/screenshot-report.png" alt="AssaySentinel HTML analytical report" width="720"/>
  <img src="assets/screenshot-control-chart.png" alt="Levey–Jennings control chart with lot and calibration events" width="720"/>
</div>
```

## Live site

Published docs: <https://theworker02.github.io/AssaySentinel.jl>

Rebuild locally on save:

```bash
julia --project=docs docs/live.jl
```

## Citation and funding

See [`CITATION.cff`](https://github.com/theworker02/AssaySentinel.jl/blob/main/CITATION.cff).
If you use AssaySentinel in research, cite the package and the statistical
methods you invoked.

[GitHub Sponsors](https://github.com/sponsors/theworker02) ·
[thanks.dev/u/gh/theworker02](https://thanks.dev/u/gh/theworker02)

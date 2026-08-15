# AssaySentinel.jl

```@raw html
<p align="center">
  <img src="assets/logo.svg" alt="AssaySentinel" width="140"/>
</p>
```

**Know when the measurement changed before the science does.**

AssaySentinel is a Julia instrument for scientists, assay developers,
biostatisticians, clinical laboratory researchers, and physicians doing
measurement-quality or method work. It watches the *measurement process* —
instruments, reagent lots, calibrations, batches, controls, and distributions —
and reconstructs a dated, uncertainty-aware, plotted, provenance-complete
account of whether that process changed.

It is not a diagnostic medical device. Doctors are valid users as laboratory
and assay researchers, not as a “diagnose patients” product.

```@raw html
<blockquote>
This software is intended for research, analytical-quality assessment, method
development, and scientific decision support. It is not a diagnostic medical
device and must not independently determine patient diagnosis or treatment.
</blockquote>
```

A result is stored as a system, not a bare number: instrument, lot, calibration,
batch, uncertainty, units, controls, processing history, and provenance travel
together. `analyze` → `explain` → `report` is the intended path from a history
to an auditable reconstruction.

## What it answers

- Did this instrument begin drifting?
- Did a reagent lot change alter the measurement distribution?
- Did a calibration curve shift?
- Is this batch statistically inconsistent with previous batches?
- When did the change most likely begin?
- How confident are we, and can the conclusion be reproduced?

It does **not** diagnose patients, label disease, or independently determine
treatment.

## Install

```julia
using Pkg
Pkg.add(url="https://github.com/theworker02/AssaySentinel.jl")
```

## Live site

Published docs: <https://theworker02.github.io/AssaySentinel.jl>

Rebuild locally on save:

```bash
julia --project=docs docs/live.jl
```

## Next

- [Quickstart](@ref)
- [Statistical methods](@ref)
- [Extensions](@ref)
- [Validation](@ref)

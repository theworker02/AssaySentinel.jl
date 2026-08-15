# Data

AssaySentinel ships generators rather than large binary datasets.

```julia
simulate_assay(...)
showcase_dataset()
```

Ground truth is returned alongside the stream so detectors can be scored with
`evaluate_detector`. Do not add identifiable laboratory files to this folder.

# Simulation and evaluation

```julia
simulate_assay(n=10_000, drift=:linear, drift_start=6000)
evaluate_detector(:cusum; nrep=20)
```

Drift kinds: `:none`, `:linear`, `:step`, `:variance`, `:lot`, `:batch`,
`:periodic`, `:failure`, `:outliers`.

`evaluate_detector` reports sensitivity, false-positive rate, precision, and
detection delay. Custom `AbstractDetector` types can be evaluated with the
same harness.

`showcase_dataset()` builds the 12-month demonstration: three lots, two
instruments, one calibration, gradual drift, variance shift, and control
failures.

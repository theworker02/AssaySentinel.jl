# Quality control

Control materials are first-class.

```julia
control = ControlSample(name="QC-Level-1", target=100.0, sd=2.0)
monitor(control, measurements)
```

Rules are composable objects, not a hard-coded `if` tree. `westgard_rules()`
implements the classical multirule set [westgard1981](@cite).

```julia
rule = @qcrule consecutive_high begin
    idx = findall(v -> v > spec.mean + 2spec.sd, values)
    QCRuleResult("consecutive_high", !isempty(idx), idx, "custom", :watch, :statistical)
end
evaluate(rule, values, QCSpec(control))
```

Levey–Jennings geometry [levey1950](@cite) is available as structured data via
`levey_jennings_data`. Plotting uses the optional Makie extension.

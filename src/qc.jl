# Composable laboratory QC rule engine. No giant hard-coded conditionals.

function evaluate(rule::QCRule, values::AbstractVector, spec::QCSpec)
    vals = valid_values(values)
    isempty(vals) && return QCRuleResult(rule.name, false, Int[],
                                         "No finite observations.", rule.severity, :observed)
    rule.fn(vals, spec)
end

function evaluate(rule::QCRule, series::ControlSeries)
    evaluate(rule, series.values, QCSpec(series.control))
end

function evaluate(rules::Vector{QCRule}, values::AbstractVector, spec::QCSpec)
    [evaluate(r, values, spec) for r in rules]
end

function evaluate(rules::Vector{QCRule}, series::ControlSeries)
    evaluate(rules, series.values, QCSpec(series.control))
end

"""
    monitor(control, measurements; rules=westgard_rules())

Evaluate control material against target ± SD and the configured rule set.
"""
function monitor(control::ControlSample, measurements::AbstractVector;
                 rules::Vector{QCRule} = westgard_rules())
    vals = if eltype(measurements) <: Measurement
        valid_values([m.value for m in measurements])
    else
        valid_values(measurements)
    end
    spec = QCSpec(control)
    results = evaluate(rules, vals, spec)
    z = (vals .- spec.mean) ./ spec.sd
    (control = control, values = vals, zscores = z, rules = results,
     n_triggered = count(r -> r.triggered, results))
end

function monitor(control::ControlSample, stream::AssayStream; kwargs...)
    ctrl = [m for m in stream.measurements if m.control]
    monitor(control, ctrl; kwargs...)
end

"""
Westgard-style multirule logic (Westgard, Barry, Hunt & Groth 1981)
expressed as independent composable rules.
"""
function westgard_rules()
    [
        _rule_1_3s(),
        _rule_1_2s(),
        _rule_2_2s(),
        _rule_R_4s(),
        _rule_4_1s(),
        _rule_10x(),
        _rule_7T(),
    ]
end

function _rule_1_3s()
    QCRule("1-3s",
           (values, spec) -> begin
               idx = findall(v -> abs(v - spec.mean) > 3 * spec.sd, values)
               QCRuleResult("1-3s", !isempty(idx), idx,
                            isempty(idx) ? "No point beyond ±3 SD." :
                            "Observed $(length(idx)) point(s) beyond ±3 SD.",
                            :critical, :observed)
           end;
           description = "One observation beyond ±3 SD (Westgard 1-3s).",
           severity = :critical)
end

function _rule_1_2s()
    QCRule("1-2s",
           (values, spec) -> begin
               idx = findall(v -> abs(v - spec.mean) > 2 * spec.sd, values)
               QCRuleResult("1-2s", !isempty(idx), idx,
                            isempty(idx) ? "No point beyond ±2 SD." :
                            "Watch: $(length(idx)) point(s) beyond ±2 SD.",
                            :watch, :observed)
           end;
           description = "One observation beyond ±2 SD (warning / 1-2s).",
           severity = :watch)
end

function _rule_2_2s()
    QCRule("2-2s",
           (values, spec) -> begin
               idx = Int[]
               for i in 2:length(values)
                   a, b = values[i - 1], values[i]
                   if (a > spec.mean + 2 * spec.sd && b > spec.mean + 2 * spec.sd) ||
                      (a < spec.mean - 2 * spec.sd && b < spec.mean - 2 * spec.sd)
                       push!(idx, i)
                   end
               end
               QCRuleResult("2-2s", !isempty(idx), idx,
                            isempty(idx) ? "No two consecutive points beyond ±2 SD on the same side." :
                            "Two consecutive points beyond ±2 SD on the same side.",
                            :warning, :statistical)
           end;
           description = "Two consecutive observations beyond ±2 SD, same side.",
           severity = :warning)
end

function _rule_R_4s()
    QCRule("R-4s",
           (values, spec) -> begin
               idx = Int[]
               for i in 2:length(values)
                   if abs(values[i] - values[i - 1]) > 4 * spec.sd
                       push!(idx, i)
                   end
               end
               QCRuleResult("R-4s", !isempty(idx), idx,
                            isempty(idx) ? "No consecutive range > 4 SD." :
                            "Consecutive observations differ by more than 4 SD.",
                            :warning, :statistical)
           end;
           description = "Range of two consecutive observations exceeds 4 SD.",
           severity = :warning)
end

function _rule_4_1s()
    QCRule("4-1s",
           (values, spec) -> begin
               idx = Int[]
               run = 0
               side = 0
               for (i, v) in enumerate(values)
                   s = v > spec.mean + spec.sd ? 1 : v < spec.mean - spec.sd ? -1 : 0
                   if s != 0 && s == side
                       run += 1
                   elseif s != 0
                       side = s
                       run = 1
                   else
                       side = 0
                       run = 0
                   end
                   run >= 4 && push!(idx, i)
               end
               QCRuleResult("4-1s", !isempty(idx), idx,
                            isempty(idx) ? "No run of 4 beyond ±1 SD." :
                            "Four consecutive observations beyond ±1 SD on the same side.",
                            :warning, :statistical)
           end;
           description = "Four consecutive observations beyond ±1 SD, same side.",
           severity = :warning)
end

function _rule_10x()
    QCRule("10x",
           (values, spec) -> begin
               idx = Int[]
               run = 0
               side = 0
               for (i, v) in enumerate(values)
                   s = v > spec.mean ? 1 : v < spec.mean ? -1 : 0
                   if s != 0 && s == side
                       run += 1
                   elseif s != 0
                       side = s
                       run = 1
                   else
                       run = 0
                       side = 0
                   end
                   run >= 10 && push!(idx, i)
               end
               QCRuleResult("10x", !isempty(idx), idx,
                            isempty(idx) ? "No run of 10 on one side of the mean." :
                            "Ten consecutive observations on the same side of the mean.",
                            :warning, :statistical)
           end;
           description = "Ten consecutive observations on one side of the mean.",
           severity = :warning)
end

function _rule_7T()
    QCRule("7T",
           (values, spec) -> begin
               idx = Int[]
               if length(values) >= 7
                   for i in 7:length(values)
                       w = view(values, (i - 6):i)
                       inc = all(w[j] < w[j + 1] for j in 1:6)
                       dec = all(w[j] > w[j + 1] for j in 1:6)
                       (inc || dec) && push!(idx, i)
                   end
               end
               QCRuleResult("7T", !isempty(idx), idx,
                            isempty(idx) ? "No 7-point monotone trend." :
                            "Seven consecutive observations form a monotone trend.",
                            :watch, :statistical)
           end;
           description = "Seven consecutive observations trending up or down.",
           severity = :watch)
end

"""
    @qcrule name begin
        ...
    end

Custom rule body sees `values::Vector{Float64}` and `spec::QCSpec` and must
return a `QCRuleResult`.
"""
macro qcrule(name, body)
    n = name isa QuoteNode ? name.value : name isa Symbol ? name : error("@qcrule expects a name")
    quote
        QCRule($(string(n)),
               (values, spec) -> begin
                   $(esc(body))
               end;
               description = "Custom rule $($(string(n))).")
    end
end

"""
    levey_jennings_data(values, spec) / control_chart_data

Structured series for Levey–Jennings charts (Levey & Jennings 1950).
Plotting is provided by the optional Makie extension.
"""
function levey_jennings_data(values::AbstractVector, spec::QCSpec;
                             timestamps = nothing,
                             events = AbstractEvent[])
    vals = valid_values(values)
    n = length(vals)
    ts = if timestamps === nothing
        collect(1:n)
    else
        timestamps
    end
    (
        values = vals,
        timestamps = ts,
        center = spec.mean,
        sd = spec.sd,
        limits = (
            m1 = spec.mean - spec.sd,
            p1 = spec.mean + spec.sd,
            m2 = spec.mean - 2 * spec.sd,
            p2 = spec.mean + 2 * spec.sd,
            m3 = spec.mean - 3 * spec.sd,
            p3 = spec.mean + 3 * spec.sd,
        ),
        events = events,
    )
end

control_chart_data(args...; kwargs...) = levey_jennings_data(args...; kwargs...)

"""
    levey_jennings(...)

Makie control chart. Requires the optional Makie.jl extension.
"""
function levey_jennings end

"""
    lot_chart(data; lot, value)

Makie lot comparison chart. Requires the optional Makie.jl extension.
"""
function lot_chart end

"""
    instrument_chart(data; instrument, value)

Makie instrument comparison chart. Requires the optional Makie.jl extension.
"""
function instrument_chart end

function levey_jennings_data(control::ControlSample, measurements; kwargs...)
    vals = eltype(measurements) <: Measurement ? [m.value for m in measurements] : measurements
    levey_jennings_data(vals, QCSpec(control); kwargs...)
end

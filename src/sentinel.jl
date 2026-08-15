# Sentinel engine: combine multiple evidence sources; streaming + batch.

"""
    Sentinel

Streaming monitor over a baseline. Incremental detectors, alert callbacks,
persistence, and cooldown are first-class.
"""
mutable struct Sentinel
    baseline::Baseline
    detector::AbstractDetector
    alerts::Vector{Alert}
    callbacks::Vector{Function}
    cooldown::Period
    last_alert::Union{Nothing, DateTime}
    min_severity::Symbol
    history_n::Int
end

function Sentinel(baseline::Baseline;
    detector::AbstractDetector = IncrementalCUSUM(),
    cooldown::Period = Hour(6),
    min_severity::Symbol = :watch)
    fit!(detector, baseline)
    Sentinel(baseline, detector, Alert[], Function[], cooldown, nothing, min_severity, 0)
end

function onalert(f::Function, sentinel::Sentinel)
    push!(sentinel.callbacks, f)
    sentinel
end

function alert(r::DriftResult)
    r.detected
end

function alert(::Nothing)
    false
end

function _severity_rank(s::Symbol)
    s === :info ? 1 : s === :watch ? 2 : s === :warning ? 3 : 4
end

function update!(sentinel::Sentinel, measurement)
    sentinel.history_n += 1
    update!(sentinel.detector, measurement)
    r = result(sentinel.detector)
    if alert(r)
        sev = r.probability > 0.9 ? :critical : r.probability > 0.7 ? :warning : :watch
        t = measurement isa Measurement ? measurement.timestamp : now()
        cooled =
            sentinel.last_alert === nothing ||
            t >= sentinel.last_alert + sentinel.cooldown
        if cooled && _severity_rank(sev) >= _severity_rank(sentinel.min_severity)
            a = Alert(; severity = sev, timestamp = t,
                message = "Analytical $(r.kind) signal from $(r.detector)",
                kind = r.kind, evidence = r.evidence)
            push!(sentinel.alerts, a)
            sentinel.last_alert = t
            for cb in sentinel.callbacks
                cb(a)
            end
            return a
        end
    end
    return r
end

"""
    analyze(stream::AssayStream; rng, outlier_policy=:annotate, parallel=false)

Combine change-point, drift, QC, distribution, outlier, and attribution
evidence into a `QualityReport`.
"""
function analyze(stream::AssayStream;
    rng::AbstractRNG = Random.default_rng(),
    outlier_policy::Symbol = :annotate,
    rules::Vector{QCRule} = westgard_rules(),
    parallel::Bool = false)
    rng_seed, rng = _capture_rng(rng)
    ms = sort(stream.measurements; by = m -> m.timestamp)
    vals = [m.value for m in ms]
    ts_all = [m.timestamp for m in ms]
    n_raw = length(vals)
    ts, finite = valid_pairs(ts_all, vals)
    miss = missing_fraction(vals)
    ms = [m for m in ms if m.value isa Number && isfinite(Float64(m.value))]
    prov = ProvenanceRecord[]
    parent = record_step!(prov;
        operation = :ingest, func = "analyze",
        parameters = Dict("n" => n_raw, "analyte" => string(stream.analyte),
            "rng_seed" => string(rng_seed)),
        input_fingerprint = fingerprint(finite),
        rng_seed = rng_seed,
        notes = "Raw measurements ingested. Missing/NaN omitted, not zero-filled.",
        statement_kind = :observed)

    outliers = detect_outliers(finite)
    record_step!(prov;
        operation = :outliers, func = "detect_outliers",
        parameters = Dict(
            "method" => string(outliers.method),
            "policy" => string(outlier_policy),
        ),
        input_fingerprint = fingerprint(finite),
        parent_ids = [parent.id],
        notes = outliers.notes,
        statement_kind = :statistical)

    work = finite
    if outlier_policy === :remove && !isempty(outliers.indices)
        keep = trues(length(work))
        for i in outliers.indices
            keep[i] = false
        end
        ts = ts[keep]
        work = work[keep]
        ms = ms[keep]
    end

    has_ctrl = any(m -> m.control, ms)
    cp = detect_changes(work; method = :auto, timestamps = ts, has_controls = has_ctrl, rng)
    record_step!(prov;
        operation = :changepoint, func = "detect_changes",
        parameters = Dict("method" => string(cp.method), "reason" => cp.selection_reason),
        input_fingerprint = fingerprint(work),
        parent_ids = [parent.id],
        notes = cp.selection_reason,
        statement_kind = :algorithmic)

    drift = detect_drift(work; kind = :auto, timestamps = ts, rng)
    record_step!(prov;
        operation = :drift, func = "detect_drift",
        parameters = Dict(
            "kind" => string(drift.kind),
            "detector" => string(drift.detector),
        ),
        input_fingerprint = fingerprint(work),
        parent_ids = [parent.id],
        notes = join(drift.evidence, " "),
        statement_kind = :algorithmic)

    vard = detect_drift(work; kind = :variance, timestamps = ts, rng)
    n0 = max(8, length(work) ÷ 3)
    dist = if length(work) >= 16
        compare_distribution(work[1:n0], work[(n0 + 1):end]; method = :auto)
    else
        nothing
    end

    qc_results = QCRuleResult[]
    ctrl_vals = [m.value for m in ms if m.control]
    if length(ctrl_vals) >= 5
        μ = mean(valid_values(ctrl_vals))
        σ = std(valid_values(ctrl_vals))
        σ = σ == 0 ? 1.0 : σ
        qc_results = evaluate(rules, ctrl_vals, QCSpec(μ, σ))
    end
    qc_pen =
        isempty(qc_results) ? 0.0 :
        count(r -> r.triggered && r.severity in (:warning, :critical), qc_results) /
        max(length(qc_results), 1)

    # Auto lot events (skip duplicates so re-analyze stays reproducible)
    for e in lot_transitions(ms)
        record_unique!(stream.events, e)
    end
    attr = nothing
    if drift.start_time !== nothing
        attr = attribute_change(drift.start_time, stream.events)
    elseif !isempty(cp.timestamps)
        attr = attribute_change(cp, stream.events)
    end

    var_pen = vard.detected ? min(1.0, abs(vard.magnitude)) : 0.0
    dist_pen = dist === nothing ? 0.0 : min(1.0, dist.statistic)
    score = sentinel_score(;
        drift_prob = drift.detected ? drift.probability : drift.probability * 0.3,
        variance_penalty = var_pen,
        qc_penalty = qc_pen,
        distribution_penalty = dist_pen,
        missing_penalty = miss,
    )
    status = status_from_score(score.value, drift.detected)

    evidence = String[]
    append!(evidence, drift.evidence)
    append!(evidence, cp.evidence)
    dist !== nothing && append!(evidence, dist.evidence)
    attr !== nothing && append!(evidence, attr.evidence)
    for r in qc_results
        r.triggered && push!(evidence, "$(r.name): $(r.message)")
    end

    limitations = [
        SAFETY_NOTICE,
        "Statistical signals are not diagnoses.",
        "Temporal association with operational events is not causation.",
        "Detector :$(cp.method) was selected because: $(cp.selection_reason)",
    ]
    miss > 0 && push!(
        limitations,
        "Missing/NaN fraction $(round(miss; digits=3)) was omitted, not imputed.",
    )

    tr = isempty(ts) ? nothing : (minimum(ts), maximum(ts))
    rec_step = record_step!(prov;
        operation = :reconstruct, func = "reconstruct",
        parameters = Dict("rng_seed" => string(rng_seed)),
        input_fingerprint = fingerprint(work),
        rng_seed = rng_seed,
        parent_ids = [parent.id],
        notes = "Ordered analytical story, uncertainty budget, and charts.",
        statement_kind = :algorithmic)
    story = reconstruct(stream, ms, work, ts, drift, cp, vard, qc_results, prov;
        rng_seed)
    QualityReport(
        stream.analyte,
        status,
        score,
        drift,
        cp,
        qc_results,
        dist,
        attr,
        outliers,
        evidence,
        limitations,
        prov,
        stream.unit,
        length(work),
        tr,
        SAFETY_NOTICE,
        story,
        (; instrument = stream.instrument, parallel = parallel,
            rng_seed = rng_seed, reconstruction_id = rec_step.id),
    )
end

function analyze(values::AbstractVector;
    timestamps = nothing,
    analyte::Symbol = :analyte,
    unit::AbstractString = "",
    rng::AbstractRNG = Random.default_rng(),
    kwargs...)
    stream = AssayStream(; analyte, unit)
    ts =
        timestamps === nothing ? [now() + Second(i) for i in 1:length(values)] :
        collect(timestamps)
    for (v, t) in zip(values, ts)
        v isa Number && isfinite(Float64(v)) || continue
        push!(stream, Measurement(; value = Float64(v), timestamp = DateTime(t), unit))
    end
    analyze(stream; rng, kwargs...)
end

function analyze(assay::Assay, table;
    value = :value,
    time = :timestamp,
    lot = :reagent_lot,
    instrument = :instrument,
    batch = :batch,
    control = :control,
    rng::AbstractRNG = Random.default_rng(),
    kwargs...)
    stream = from_table(table; analyte = assay.analyte, unit = assay.unit,
        value, time, lot, instrument, batch, control)
    stream.method = assay.method
    analyze(stream; rng, kwargs...)
end

function analyze(panel::AssayPanel;
    parallel::Bool = false,
    rng::AbstractRNG = Random.default_rng(),
    kwargs...)
    names = collect(keys(panel.streams))
    results = Vector{QualityReport}(undef, length(names))
    seed = rand(rng, UInt64)
    if parallel && Threads.nthreads() > 1
        Threads.@threads for i in eachindex(names)
            local_rng = Random.Xoshiro(seed + UInt64(i))
            results[i] = analyze(panel.streams[names[i]]; rng = local_rng, kwargs...)
        end
    else
        for i in eachindex(names)
            results[i] = analyze(panel.streams[names[i]]; rng, kwargs...)
        end
    end
    (; panel = panel.name, reports = Dict(names[i] => results[i] for i in eachindex(names)))
end

function Base.show(io::IO, r::QualityReport)
    println(io, "AssaySentinel Report")
    println(io, "Analyte:")
    println(io, r.analyte)
    println(io, "Status:")
    println(io, _status_label(r.status))
    if r.drift.start_time !== nothing
        println(io, "Estimated change point:")
        println(io, r.drift.start_time)
    elseif !isempty(r.change_points.timestamps)
        println(io, "Estimated change point:")
        println(io, r.change_points.timestamps[1])
    end
    println(io, "Direction:")
    magpct = r.drift.magnitude * 100
    sign =
        r.drift.direction === :increase ? "+" : r.drift.direction === :decrease ? "−" : ""
    println(
        io,
        isempty(sign) ? string(r.drift.direction) : @sprintf("%s%.1f%%", sign, abs(magpct)),
    )
    println(io, "Confidence:")
    println(io, round(r.drift.probability; digits = 2))
    println(io, "Primary evidence:")
    for e in r.evidence[1:min(end, 4)]
        println(io, "- ", e)
    end
    if r.attribution !== nothing && r.attribution.event !== nothing
        println(io, "Likely associated event:")
        println(io, event_label(r.attribution.event))
        println(io, "(temporal association, not causation)")
    end
    if r.reconstruction !== nothing
        println(io)
        println(io, "Reconstruction:")
        println(io, r.reconstruction.narrative)
        ub = r.reconstruction.uncertainty
        println(io, "Combined SD: ", round(ub.combined_sd; digits = 3),
            ub.rms_measurement === nothing ? " (analytical only)" :
            " (analytical + measurement)")
    end
    print(io, "Sentinel Score: ", round(r.score.value; digits = 1))
end

function _status_label(s::Symbol)
    s === :drift_suspected ? "DRIFT SUSPECTED" :
    s === :stable ? "STABLE" :
    s === :watch ? "WATCH" :
    s === :warning ? "WARNING" :
    s === :critical ? "CRITICAL" : uppercase(string(s))
end

function Base.summary(r::QualityReport)
    (
        analyte = r.analyte,
        status = _status_label(r.status),
        score = r.score.value,
        n = r.n,
        drift = r.drift.detected,
        method = r.change_points.method,
    )
end

function Base.summary(panel_result::NamedTuple)
    if haskey(panel_result, :reports)
        rows = [
            (
                analyte = k,
                status = _status_label(v.status),
                score = round(v.score.value; digits = 1),
            )
            for (k, v) in sort(collect(panel_result.reports); by = first)
        ]
        return rows
    end
    panel_result
end

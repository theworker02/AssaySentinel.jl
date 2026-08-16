# Reconstruct how the measurement system behaved. Association ≠ causation.

function _capture_rng(rng::AbstractRNG)
    seed = rand(rng, UInt64)
    return seed, Random.Xoshiro(seed)
end

function _beat_label(kind::Symbol, extra::AbstractString = "")
    base =
        kind === :stable ? "Stable" :
        kind === :calibration ? "Calibration" :
        kind === :lot_change ? "Reagent lot changed" :
        kind === :shift ? "Small distribution shift" :
        kind === :drift ? "Progressive analytical drift" :
        kind === :variance ? "Variance increase" :
        kind === :qc ? "QC deterioration" :
        kind === :changepoint ? "Detected change point" :
        kind === :instrument ? "Instrument difference" :
        string(kind)
    isempty(extra) ? base : base * extra
end

function _narrative(beats::Vector{StoryBeat})
    isempty(beats) && return "Insufficient structure to reconstruct a story."
    join((b.label for b in beats), "\n   ↓\n")
end

function _index_at(ts::AbstractVector{DateTime}, t::DateTime)
    isempty(ts) && return nothing
    best = 1
    best_d = typemax(Int)
    tv = Dates.value(t)
    for (i, x) in enumerate(ts)
        d = abs(Dates.value(x) - tv)
        if d < best_d
            best_d = d
            best = i
        end
    end
    best
end

function _segment_values(vals, ts, lo::DateTime, hi::DateTime)
    out = Float64[]
    for (v, t) in zip(vals, ts)
        if lo <= t <= hi
            push!(out, v)
        end
    end
    out
end

function _classify_segment(prev::Vector{Float64}, cur::Vector{Float64};
    qc_hit::Bool, drift_hint::Bool, var_hint::Bool)
    qc_hit && return (:qc, :observed, "Control-rule failures occurred in this window.")
    if length(cur) >= 16 && drift_hint
        d = detect_drift(cur; kind = :linear)
        d.detected && return (:drift, :algorithmic, join(d.evidence, " "))
    end
    if length(cur) >= 16 && var_hint
        v = detect_drift(cur; kind = :variance)
        v.detected && return (:variance, :statistical, join(v.evidence, " "))
    end
    if length(prev) >= 8 && length(cur) >= 8
        wt = welch_t(prev, cur)
        δ = mean(cur) - mean(prev)
        s = std(prev)
        if wt.pvalue < 0.01 && abs(δ) > 0.35 * max(s, eps())
            return (:shift, :statistical,
                "Location changed vs the previous segment (Welch p=$(round(wt.pvalue; digits=4))).",
            )
        end
    end
    if length(cur) >= 20
        d = detect_drift(cur; kind = :linear)
        d.detected && return (:drift, :algorithmic, join(d.evidence, " "))
    end
    (:stable, :statistical, "Segment is consistent with prior location and scale.")
end

function _event_kind_label(e::AbstractEvent)
    k = event_kind(e)
    k === :lot_change ? :lot_change :
    k === :calibration ? :calibration :
    k === :maintenance ? :calibration :
    k
end

"""
    reconstruct(stream, report_pieces; rng_seed)

Build the ordered analytical story, uncertainty budget, charts, and
provenance graph from an already-run analysis. Called by `analyze`.
"""
function reconstruct(stream::AssayStream,
    ms::AbstractVector{<:Measurement},
    vals::Vector{Float64},
    ts::Vector{DateTime},
    drift::DriftResult,
    cp::ChangePointResult,
    vard::DriftResult,
    qc::Vector{QCRuleResult},
    provenance::Vector{ProvenanceRecord};
    rng_seed = nothing)
    events = copy(stream.events.events)
    bounds = Tuple{DateTime, Symbol, Any}[]
    if !isempty(ts)
        push!(bounds, (ts[1], :start, nothing))
        push!(bounds, (ts[end], :end, nothing))
    end
    for e in events
        push!(bounds, (event_time(e), _event_kind_label(e), e))
    end
    for t in cp.timestamps
        push!(bounds, (t, :changepoint, nothing))
    end
    if drift.detected && drift.start_time !== nothing
        push!(bounds, (drift.start_time, :drift, nothing))
    end
    if vard.detected && vard.start_time !== nothing
        push!(bounds, (vard.start_time, :variance, nothing))
    end
    sort!(bounds; by = x -> x[1])
    # unique times, prefer event kinds over generic markers
    merged = Tuple{DateTime, Symbol, Any}[]
    for b in bounds
        if isempty(merged) || merged[end][1] != b[1]
            push!(merged, b)
        elseif b[2] in (:lot_change, :calibration, :qc) &&
               merged[end][2] in (:start, :changepoint, :end)
            merged[end] = b
        end
    end

    qc_times = DateTime[]
    ctrl = [m for m in ms if m.control]
    if !isempty(qc)
        for r in qc
            r.triggered || continue
            for i in r.indices
                if 1 <= i <= length(ctrl)
                    push!(qc_times, ctrl[i].timestamp)
                end
            end
        end
    end

    beats = StoryBeat[]
    prev_vals = Float64[]
    for i in 1:(length(merged) - 1)
        t0, k0, e0 = merged[i]
        t1 = merged[i + 1][1]
        if k0 in (:lot_change, :calibration) && e0 !== nothing
            extra =
                k0 === :lot_change && e0 isa LotChangeEvent ?
                (
                    e0.from_lot === nothing ? " ($(e0.to_lot))" :
                    " ($(e0.from_lot) → $(e0.to_lot))"
                ) : ""
            push!(
                beats,
                StoryBeat(_beat_label(k0, extra), k0, t0, _index_at(ts, t0),
                    :observed, event_label(e0)),
            )
        elseif k0 === :changepoint
            push!(
                beats,
                StoryBeat(_beat_label(:changepoint), :changepoint, t0,
                    _index_at(ts, t0), :algorithmic, cp.selection_reason),
            )
        end
        cur = _segment_values(vals, ts, t0, t1)
        qc_hit = any(t -> t0 <= t <= t1, qc_times)
        kind, sk, notes = _classify_segment(prev_vals, cur;
            qc_hit,
            drift_hint = drift.detected && drift.start_time !== nothing &&
                         t0 >= drift.start_time,
            var_hint = vard.detected && vard.start_time !== nothing &&
                       t0 >= vard.start_time)
        # Avoid repeating an event label as the segment label
        if kind !== k0 || k0 === :start
            push!(
                beats,
                StoryBeat(_beat_label(kind), kind, t0, _index_at(ts, t0), sk, notes),
            )
        end
        !isempty(cur) && (prev_vals = cur)
    end
    # collapse consecutive identical kinds
    compact = StoryBeat[]
    for b in beats
        if !isempty(compact) && compact[end].kind === b.kind &&
           compact[end].kind === :stable
            continue
        end
        push!(compact, b)
    end
    isempty(compact) && push!(
        compact,
        StoryBeat("Stable", :stable, isempty(ts) ? nothing : ts[1],
            1, :statistical, "No transitions localized."),
    )

    lot = try
        compare_lots(ms, :reagent_lot)
    catch
        nothing
    end
    inst = try
        compare_lots(ms, :instrument)
    catch
        nothing
    end

    spec = if count(m -> m.control, ms) >= 5
        cv = valid_values([m.value for m in ms if m.control])
        QCSpec(mean(cv), max(std(cv), eps()))
    elseif length(vals) >= 5
        QCSpec(mean(vals), max(std(vals), eps()))
    else
        nothing
    end
    cps = cp.timestamps
    lot_labs = String[]
    lot_vals = Float64[]
    inst_labs = String[]
    inst_vals = Float64[]
    for m in ms
        if m.reagent_lot !== nothing
            push!(lot_labs, m.reagent_lot)
            push!(lot_vals, Float64(m.value))
        end
        if m.instrument !== nothing
            push!(inst_labs, m.instrument)
            push!(inst_vals, Float64(m.value))
        end
    end
    lot_svg =
        length(unique(lot_labs)) >= 2 ?
        svg_group_chart(lot_labs, lot_vals; title = "Reagent lots") : ""
    inst_svg =
        length(unique(inst_labs)) >= 2 ?
        svg_group_chart(inst_labs, inst_vals; title = "Instruments") : ""
    charts = (
        timeline = svg_timeline(compact),
        control_chart = svg_control_chart(ts, vals; spec, events, changepoints = cps),
        provenance = svg_provenance(provenance),
        lots = lot_svg,
        instruments = inst_svg,
    )
    g = provenance_graph(provenance)
    ub = uncertainty_budget(ms, vals; magnitude = drift.magnitude)
    Reconstruction(
        compact,
        _narrative(compact),
        ub,
        lot,
        inst,
        charts,
        (; nodes = [(string(n[1]), string(n[2]), string(n[3])) for n in g.nodes],
            edges = [(string(a), string(b)) for (a, b) in g.edges]),
        rng_seed === nothing ? nothing : UInt64(rng_seed),
        fingerprint(vals),
        string(PACKAGE_VERSION),
    )
end

"""
    reconstruct(stream; rng)

Analyze a stream and return only the `Reconstruction`.
"""
function reconstruct(
    stream::AssayStream;
    rng::AbstractRNG = Random.default_rng(),
    kwargs...,
)
    analyze(stream; rng, kwargs...).reconstruction
end

"""
    reconstruct(hierarchy, site_reports; rng_seed, name)

Study-level reconstruction: sharing narrative, between/within uncertainty,
forest plot, and provenance. Called by `analyze(study, streams)`.
"""
function reconstruct(hier::HierarchicalSiteResult,
    site_reports::AbstractDict = Dict{String, QualityReport}();
    rng_seed = nothing,
    name::AbstractString = "study")
    beats = StoryBeat[]
    push!(
        beats,
        StoryBeat("Multi-site ingest", :stable, nothing, nothing, :observed,
            "Study $name: $(length(hier.sites)) sites. Missing/NaN omitted, not zero-filled."),
    )
    for s in hier.sites
        if s.drift.detected
            push!(
                beats,
                StoryBeat("Site $(s.site) drift", :drift, s.drift.start_time,
                    s.drift.start_index, :algorithmic,
                    join(s.drift.evidence, " ")),
            )
        end
    end
    if hier.global_drift.detected
        push!(
            beats,
            StoryBeat("Shared location shift", :shift, hier.global_drift.start_time,
                hier.global_drift.start_index, :statistical,
                join(hier.global_drift.evidence, " ")),
        )
    end
    share =
        hier.attribution === :global ? "Shared across sites" :
        hier.attribution === :site_specific ? "Site-specific pattern" :
        hier.attribution === :mixed ? "Mixed sharing" : "Sites statistically stable"
    push!(
        beats,
        StoryBeat(share, :changepoint, nothing, nothing, :algorithmic,
            "Attribution :$(hier.attribution); I²=$(round(hier.i2; digits=1))%; concordance=$(round(hier.concordance; digits=2)). Statistical sharing, not causation."),
    )
    ub = UncertaintyBudget(
        0,
        nothing,
        hier.within_sd,
        sqrt(hier.within_sd^2 + hier.between_sd^2),
        hier.grand_mean,
        (hier.prediction_hi - hier.prediction_lo) / (2 * 1.96),
        "Combined SD = √(within² + between²). 95% prediction interval for a new site mean is $(round(hier.prediction_lo; digits=3))–$(round(hier.prediction_hi; digits=3)). I²=$(round(hier.i2; digits=1))%. Analytical-process interval, not a clinical reference.",
    )
    prov = ProvenanceRecord[]
    p0 = record_step!(prov;
        operation = :ingest, func = "analyze",
        parameters = Dict("n_sites" => length(hier.sites), "name" => string(name)),
        input_fingerprint = fingerprint(string(name, hier.grand_mean)),
        rng_seed = rng_seed,
        notes = "Per-site streams ingested for hierarchical combine.",
        statement_kind = :observed)
    p1 = record_step!(prov;
        operation = :hierarchical, func = "hierarchical_sites",
        parameters = Dict("attribution" => string(hier.attribution),
            "i2" => hier.i2),
        input_fingerprint = fingerprint(string(hier.grand_mean, hier.between_sd)),
        parent_ids = [p0.id],
        rng_seed = rng_seed,
        notes = join(hier.evidence, " "),
        statement_kind = :statistical)
    record_step!(prov;
        operation = :reconstruct, func = "reconstruct",
        parameters = Dict("kind" => "study"),
        parent_ids = [p1.id],
        rng_seed = rng_seed,
        notes = "Study reconstruction with forest plot.",
        statement_kind = :algorithmic)
    g = provenance_graph(prov)
    site_charts = Dict{String, String}()
    for (k, r) in site_reports
        if r isa QualityReport && r.reconstruction !== nothing
            site_charts[string(k)] = r.reconstruction.charts.control_chart
        end
    end
    charts = (
        timeline = svg_timeline(beats),
        forest = svg_forest_chart(hier),
        provenance = svg_provenance(prov),
        control_chart = svg_forest_chart(hier),
        lots = "",
        instruments = "",
        sites = site_charts,
    )
    Reconstruction(
        beats,
        _narrative(beats),
        ub,
        nothing,
        nothing,
        charts,
        (; nodes = [(string(n[1]), string(n[2]), string(n[3])) for n in g.nodes],
            edges = [(string(a), string(b)) for (a, b) in g.edges]),
        rng_seed === nothing ? nothing : UInt64(rng_seed),
        fingerprint(string(hier.grand_mean, "|", hier.between_sd, "|", hier.i2)),
        string(PACKAGE_VERSION),
    )
end

function reconstruct(r::StudyReport)
    r.reconstruction
end

function reconstruct(
    study::Study,
    streams::AbstractDict;
    rng::AbstractRNG = Random.default_rng(),
    kwargs...,
)
    analyze(study, streams; rng, kwargs...).reconstruction
end

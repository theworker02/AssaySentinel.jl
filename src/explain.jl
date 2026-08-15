"""
    explain(result)

Human-readable reconstruction of why a conclusion was reached.
Leads with the dated analytical story, then the uncertainty budget,
then the evidence that assigned status. Distinguishes observed facts,
statistical results, algorithmic inference, and user annotations.
"""
function explain(r::QualityReport)
    io = IOBuffer()
    println(io, "AssaySentinel reconstruction")
    println(io, "============================")
    println(io)
    println(io, SAFETY_NOTICE)
    println(io)
    println(io, "Analyte: ", r.analyte, "  (", r.unit, ")")
    println(io, "Status:  ", _status_label(r.status))
    println(io, "Score:   ", round(r.score.value; digits = 1), " / 100  (analytical stability, not patient risk)")
    if r.reconstruction !== nothing
        rec = r.reconstruction
        println(io)
        println(io, "Reconstruction")
        println(io, "--------------")
        println(io, rec.narrative)
        if rec.rng_seed !== nothing
            println(io, "rng_seed=", rec.rng_seed, "  fingerprint=", rec.input_fingerprint)
        else
            println(io, "fingerprint=", rec.input_fingerprint)
        end
        _explain_uncertainty(io, rec.uncertainty)
        if rec.lot_analysis !== nothing
            println(io, "Lot analysis")
            println(io, "------------")
            for e in rec.lot_analysis.evidence
                println(io, "- ", e)
            end
            println(io)
        end
        if rec.instrument_analysis !== nothing
            println(io, "Instrument analysis")
            println(io, "-------------------")
            for e in rec.instrument_analysis.evidence
                println(io, "- ", e)
            end
            println(io)
        end
    end
    println(io, "Why was this status assigned?")
    n = 1
    if r.drift.detected
        println(io, n, ". [inference] ", r.drift.kind, " drift flagged by :", r.drift.detector,
                " (P=", round(r.drift.probability; digits = 2), ", magnitude=",
                round(r.drift.magnitude; sigdigits = 3), ").")
        n += 1
    else
        println(io, n, ". [inference] No drift detector exceeded its decision threshold.")
        n += 1
    end
    if r.change_points.detected && !isempty(r.change_points.indices)
        println(io, n, ". [statistical] Change-point method :", r.change_points.method,
                " localized transition(s) at observation(s) ",
                join(r.change_points.indices, ", "), ".")
        println(io, "   Selection reason: ", r.change_points.selection_reason)
        n += 1
    end
    if r.distribution !== nothing
        println(io, n, ". [statistical] Distribution comparison via :",
                r.distribution.method, " — ", join(r.distribution.evidence, " "))
        n += 1
    end
    triggered = [q for q in r.qc if q.triggered]
    if !isempty(triggered)
        println(io, n, ". [observed] QC rule(s) triggered: ",
                join((q.name for q in triggered), ", "), ".")
        n += 1
    end
    if r.outliers !== nothing && !isempty(r.outliers.indices)
        println(io, n, ". [statistical] ", length(r.outliers.indices),
                " outlier(s) annotated with :", r.outliers.method,
                " (not removed unless requested).")
        n += 1
    end
    if r.attribution !== nothing
        println(io, n, ". [inference] ", r.attribution.statement)
        n += 1
    end
    println(io)
    println(io, "Score components (penalties in [0, 1]):")
    for k in keys(r.score.components)
        println(io, "  ", rpad(k, 14), " ", round(getfield(r.score.components, k); digits = 3),
                "   weight=", getfield(r.score.weights, k))
    end
    println(io)
    println(io, "Provenance")
    println(io, "----------")
    for line in provenance_lines(r.provenance)
        println(io, line)
    end
    println(io)
    println(io, "Limitations")
    println(io, "-----------")
    for L in r.limitations
        println(io, "- ", L)
    end
    println(io)
    println(io, "Statement legend: [observed] fact from data; [statistical] computed ",
            "statistic; [inference] algorithmic conclusion; [annotation] user note.")
    String(take!(io))
end

function explain(r::Reconstruction)
    io = IOBuffer()
    println(io, "AssaySentinel reconstruction")
    println(io, "============================")
    println(io)
    println(io, r.narrative)
    println(io)
    if r.rng_seed !== nothing
        println(io, "rng_seed=", r.rng_seed, "  fingerprint=", r.input_fingerprint)
    else
        println(io, "fingerprint=", r.input_fingerprint)
    end
    _explain_uncertainty(io, r.uncertainty)
    println(io, "Statement legend: [observed] fact from data; [statistical] computed ",
            "statistic; [inference] algorithmic conclusion; [annotation] user note.")
    String(take!(io))
end

function explain(d::AbstractDict)
    rec = _dget(d, "reconstruction")
    io = IOBuffer()
    println(io, "AssaySentinel reconstruction")
    println(io, "============================")
    println(io)
    notice = _dget(d, "safety_notice")
    notice !== nothing && (println(io, notice); println(io))
    analyte = _dget(d, "analyte")
    unit = _dget(d, "unit")
    status = _dget(d, "status_label", _dget(d, "status"))
    analyte !== nothing && println(io, "Analyte: ", analyte, unit === nothing ? "" : "  ($unit)")
    status !== nothing && println(io, "Status:  ", status)
    if rec isa AbstractDict
        println(io)
        println(io, "Reconstruction")
        println(io, "--------------")
        println(io, _dget(rec, "narrative", ""))
        seed = _dget(rec, "rng_seed")
        fp = _dget(rec, "input_fingerprint")
        seed !== nothing && print(io, "rng_seed=", seed, "  ")
        fp !== nothing && println(io, "fingerprint=", fp)
        seed === nothing && fp === nothing && println(io)
        ub = _dget(rec, "uncertainty")
        ub isa AbstractDict && _explain_uncertainty(io, ub)
    end
    println(io, "Statement legend: [observed] fact from data; [statistical] computed ",
            "statistic; [inference] algorithmic conclusion; [annotation] user note.")
    String(take!(io))
end

function explain(r::DriftResult)
    io = IOBuffer()
    println(io, "DriftResult (:", r.kind, " via :", r.detector, ")")
    println(io, "detected=", r.detected, "  P=", round(r.probability; digits = 3),
            "  magnitude=", r.magnitude, "  direction=", r.direction)
    for e in r.evidence
        println(io, "- ", e)
    end
    String(take!(io))
end

function explain(r::ChangePointResult)
    io = IOBuffer()
    println(io, "ChangePointResult method=:", r.method)
    println(io, r.selection_reason)
    println(io, "indices=", r.indices, "  confidence=", r.confidence)
    for e in r.evidence
        println(io, "- ", e)
    end
    String(take!(io))
end

function explain(r::HierarchicalSiteResult)
    io = IOBuffer()
    println(io, "AssaySentinel hierarchical sites")
    println(io, "================================")
    println(io)
    println(io, r.notes)
    println(io)
    println(io, "Attribution: ", r.attribution, "  concordance=", round(r.concordance; digits = 2))
    println(io, "Grand mean:  ", round(r.grand_mean; digits = 4),
            "  τ=", round(r.between_sd; digits = 4),
            "  σ=", round(r.within_sd; digits = 4))
    println(io)
    for s in r.sites
        println(io, "- ", s.site, " n=", s.n,
                " raw=", round(s.raw_mean; digits = 3),
                " shrunk=", round(s.shrunk_mean; digits = 3),
                " B=", round(s.shrinkage; digits = 2),
                " drift=", s.drift.detected)
    end
    println(io)
    for e in r.evidence
        println(io, e)
    end
    String(take!(io))
end

function explain(r::StudyReport)
    io = IOBuffer()
    println(io, "AssaySentinel study reconstruction")
    println(io, "==================================")
    println(io)
    println(io, r.safety_notice)
    println(io)
    println(io, "Study: ", r.name, "  schema ", r.schema_version)
    println(io, explain(r.hierarchy))
    println(io, "Per-site reports: ", join(sort(collect(keys(r.site_reports))), ", "))
    String(take!(io))
end

function explain(x)
    sprint(show, x)
end

function _explain_uncertainty(io::IO, ub::UncertaintyBudget)
    println(io)
    println(io, "Uncertainty budget")
    println(io, "------------------")
    println(io, "n with uncertainty: ", ub.n_with_uncertainty)
    println(io, "RMS(u):             ", ub.rms_measurement === nothing ? "—" : round(ub.rms_measurement; digits = 4))
    println(io, "analytical SD:      ", round(ub.analytical_sd; digits = 4))
    println(io, "combined SD:        ", round(ub.combined_sd; digits = 4))
    println(io, "weighted mean:      ", ub.weighted_mean === nothing ? "—" : round(ub.weighted_mean; digits = 4))
    println(io, "magnitude SE:       ", round(ub.magnitude_se; digits = 4))
    println(io, ub.notes)
    println(io)
end

function _explain_uncertainty(io::IO, ub::AbstractDict)
    println(io)
    println(io, "Uncertainty budget")
    println(io, "------------------")
    println(io, "n with uncertainty: ", _dget(ub, "n_with_uncertainty", "—"))
    rms = _dget(ub, "rms_measurement")
    println(io, "RMS(u):             ", rms === nothing ? "—" : rms)
    println(io, "analytical SD:      ", _dget(ub, "analytical_sd", "—"))
    println(io, "combined SD:        ", _dget(ub, "combined_sd", "—"))
    wm = _dget(ub, "weighted_mean")
    println(io, "weighted mean:      ", wm === nothing ? "—" : wm)
    println(io, "magnitude SE:       ", _dget(ub, "magnitude_se", "—"))
    notes = _dget(ub, "notes")
    notes !== nothing && println(io, notes)
    println(io)
end

_dget(d::AbstractDict, k::AbstractString, default = nothing) =
    get(d, k, get(d, Symbol(k), default))

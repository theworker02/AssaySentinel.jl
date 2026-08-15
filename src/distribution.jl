# Distribution surveillance against an explicit baseline.

function Baseline(values::AbstractVector;
    timestamps = nothing,
    instrument = nothing,
    reagent_lot = nothing,
    method = nothing,
    unit::AbstractString = "")
    ts, vals = if timestamps === nothing
        DateTime[], valid_values(values)
    else
        valid_pairs(collect(timestamps), collect(values))
    end
    isempty(vals) && throw(InsufficientDataError(1, 0, "Baseline"))
    tr = isempty(ts) ? nothing : (minimum(ts), maximum(ts))
    Baseline(
        vals,
        ts,
        length(vals),
        tr,
        _nothing_string(instrument),
        _nothing_string(reagent_lot),
        _nothing_string(method),
        mean(vals),
        std(vals),
        median(vals),
        robust_mad(vals),
        String(unit),
        ProvenanceRecord[],
        EmptyMeta,
    )
end

function Baseline(stream::AssayStream; kwargs...)
    Baseline([m.value for m in stream.measurements];
        timestamps = [m.timestamp for m in stream.measurements],
        instrument = stream.instrument,
        method = stream.method,
        unit = stream.unit,
        kwargs...)
end

"""
    compare_distribution(baseline, current; method=:auto)
"""
function compare_distribution(baseline, current; method::Symbol = :auto)
    a = baseline isa Baseline ? baseline.values : valid_values(baseline)
    b = current isa Baseline ? current.values : valid_values(current)
    (length(a) < 5 || length(b) < 5) &&
        throw(InsufficientDataError(5, min(length(a), length(b)), "compare_distribution"))
    chosen = method
    reason = "User-selected :$method."
    if method === :auto
        n = min(length(a), length(b))
        if n < 20
            chosen = :ks
            reason = "Small samples: Kolmogorov–Smirnov."
        elseif excess_kurtosis(vcat(a, b)) > 3
            chosen = :energy
            reason = "Heavy tails: energy distance."
        else
            chosen = :wasserstein
            reason = "Moderate n and light tails: 1-Wasserstein."
        end
    end
    if chosen === :ks
        d = ks_statistic(a, b)
        p = ks_pvalue(d, length(a), length(b))
        return DistributionComparison(d, p, :ks, reason, length(a), length(b),
            ["KS D=$(round(d; digits=3)), p=$(round(p; digits=4))."],
            (;))
    elseif chosen === :energy
        d = energy_distance(a, b)
        return DistributionComparison(d, nothing, :energy, reason, length(a), length(b),
            ["Energy distance $(round(d; digits=4))."], (;))
    elseif chosen === :wasserstein
        d = wasserstein1d(a, b)
        return DistributionComparison(d, nothing, :wasserstein, reason, length(a),
            length(b),
            ["1-Wasserstein distance $(round(d; digits=4))."], (;))
    elseif chosen === :js || chosen === :jensen_shannon
        d = jensen_shannon(a, b)
        return DistributionComparison(d, nothing, :jensen_shannon, reason, length(a),
            length(b),
            ["Jensen–Shannon divergence $(round(d; digits=4))."], (;))
    else
        throw(ArgumentError("Unknown distribution method :$chosen"))
    end
end

# Outlier detection is separate from deletion. Default: annotate only.

"""
    detect_outliers(x; method=:mad, k=3.5)

Detect outliers without removing them.

Methods:
- `:mad` — robust z-score using normalized MAD (Rousseeuw & Croux 1993)
- `:iqr` — Tukey fences at `Q1 − k IQR`, `Q3 + k IQR` (Tukey 1977); default k=1.5
- `:zscore` — classical |z| > k
- `:robust_z` — alias of `:mad`
"""
function detect_outliers(x::AbstractVector;
                         method::Symbol = :mad,
                         k::Real = method === :iqr ? 1.5 : 3.5)
    vals = Float64[]
    idxmap = Int[]
    for (i, v) in enumerate(x)
        if v isa Number && isfinite(Float64(v))
            push!(vals, Float64(v))
            push!(idxmap, i)
        end
    end
    isempty(vals) && return OutlierResult(Int[], Float64[], method, Float64(k), false,
                                          "No finite observations.")
    scores = similar(vals)
    flagged = Int[]
    if method === :iqr
        q1, q3 = quantile(vals, [0.25, 0.75])
        iqr = q3 - q1
        lo, hi = q1 - k * iqr, q3 + k * iqr
        for (j, v) in enumerate(vals)
            scores[j] = iqr == 0 ? 0.0 : (v - median(vals)) / iqr
            if v < lo || v > hi
                push!(flagged, idxmap[j])
            end
        end
    else
        loc = method === :zscore ? mean(vals) : median(vals)
        scl = method === :zscore ? std(vals) : robust_mad(vals)
        scl = scl == 0 || !isfinite(scl) ? 1.0 : scl
        for (j, v) in enumerate(vals)
            scores[j] = (v - loc) / scl
            if abs(scores[j]) > k
                push!(flagged, idxmap[j])
            end
        end
    end
    OutlierResult(flagged, scores, method, Float64(k), false,
                  "Outliers annotated, not removed.")
end

"""
    annotate_outliers(x; kwargs...)

Alias of `detect_outliers`. Removal is never performed here.
"""
annotate_outliers(x; kwargs...) = detect_outliers(x; kwargs...)

function apply_outlier_policy(values::AbstractVector{<:Real}, policy::Symbol;
                              method::Symbol = :mad)
    result = detect_outliers(values; method)
    if policy === :remove
        keep = trues(length(values))
        for i in result.indices
            keep[i] = false
        end
        return values[keep], OutlierResult(result.indices, result.scores, result.method,
                                           result.threshold, true,
                                           "Outliers removed by explicit policy.")
    end
    return values, result
end

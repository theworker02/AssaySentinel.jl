# Uncertainty is used, not merely stored.

function _measurement_uncertainties(ms::AbstractVector{<:Measurement})
    u = Union{Nothing, Float64}[]
    sizehint!(u, length(ms))
    for m in ms
        if m.uncertainty !== nothing && isfinite(Float64(m.uncertainty)) && m.uncertainty > 0
            push!(u, Float64(m.uncertainty))
        else
            push!(u, nothing)
        end
    end
    u
end

function inverse_variance_mean(values::AbstractVector{<:Real},
                               uncs::AbstractVector)
    num = 0.0
    den = 0.0
    n = 0
    for (v, u) in zip(values, uncs)
        u === nothing && continue
        w = 1 / Float64(u)^2
        num += w * Float64(v)
        den += w
        n += 1
    end
    n == 0 && return nothing
    den == 0 && return nothing
    num / den
end

"""
    uncertainty_budget(measurements, values; magnitude=0)

Combine reported measurement uncertainty with observed analytical scatter.
Combined SD is `√(s² + ū²)` when per-point uncertainties exist (RSS of
independent analytical and measurement components). Magnitude SE uses
`combined_sd / √n` scaled to a relative magnitude when `magnitude` is relative.
"""
function uncertainty_budget(measurements::AbstractVector{<:Measurement},
                            values::AbstractVector{<:Real};
                            magnitude::Real = 0.0)
    uncs = _measurement_uncertainties(measurements)
    present = [u for u in uncs if u !== nothing]
    n = length(values)
    σ = n >= 2 ? std(values) : 0.0
    σ = isfinite(σ) ? σ : 0.0
    rms = isempty(present) ? nothing : sqrt(mean(abs2, present))
    combined = rms === nothing ? σ : sqrt(σ^2 + rms^2)
    wmean = inverse_variance_mean(values, uncs)
    se = n > 0 ? combined / sqrt(n) : combined
    notes = if rms === nothing
        "No per-observation uncertainty was supplied. Combined SD is the analytical scatter only."
    else
        "$(length(present)) of $n observations carried uncertainty. Combined SD = √(analytical² + RMS(u)²)."
    end
    UncertaintyBudget(length(present), rms, σ, combined, wmean, se, notes)
end

# Multivariate drift across panels, channels, and multiplex assays.

"""
    detect_drift(X::AbstractMatrix; method=:mahalanobis, timestamps=nothing)

`X` is observations × features. Methods:
- `:mahalanobis` — Hotelling-style distance from baseline mean/covariance
- `:pca` — Hotelling T² on leading principal components
- `:covariance` — Frobenius shift of correlation matrices
- `:energy` — multivariate energy distance between halves
"""
function detect_drift(X::AbstractMatrix;
                      method::Symbol = :mahalanobis,
                      timestamps = nothing,
                      baseline_frac::Float64 = 0.4)
    n, p = size(X)
    n < 12 && return DriftResult(; detected = false, detector = method, kind = :multivariate,
                                 evidence = ["Multivariate drift needs ≥ 12 complete rows."])
    M = _finite_rows(X)
    n = size(M, 1)
    n < 12 && return DriftResult(; detected = false, detector = method, kind = :multivariate,
                                 evidence = ["Too many non-finite rows."])
    n0 = max(8, round(Int, baseline_frac * n))
    B = M[1:n0, :]
    C = M[(n0 + 1):end, :]
    if method === :mahalanobis
        return _mv_mahalanobis(B, C, n0)
    elseif method === :pca
        return _mv_pca(B, C, n0)
    elseif method === :covariance
        return _mv_cov(B, C, n0)
    elseif method === :energy
        return _mv_energy(B, C, n0)
    else
        throw(ArgumentError("Unknown multivariate method :$method"))
    end
end

function _finite_rows(X::AbstractMatrix)
    rows = Int[]
    for i in 1:size(X, 1)
        ok = true
        for j in 1:size(X, 2)
            v = X[i, j]
            if !(v isa Number) || !isfinite(Float64(v))
                ok = false
                break
            end
        end
        ok && push!(rows, i)
    end
    return Float64.(X[rows, :])
end

function _mv_mahalanobis(B, C, n0)
    μ = vec(mean(B; dims = 1))
    Σ = cov(B)
    Σ = Σ + 1e-6 * I
    invΣ = try
        inv(Σ)
    catch
        pinv(Σ)
    end
    dvals = Float64[]
    for i in 1:size(C, 1)
        δ = vec(C[i, :]) .- μ
        push!(dvals, sqrt(max(δ' * invΣ * δ, 0.0)))
    end
    p = size(B, 2)
    # Chi-squared mean for Mahalanobis^2 is p; compare mean distance
    md = mean(dvals)
    expected = sqrt(p)
    detected = md > expected * 1.6
    DriftResult(;
        detected,
        probability = detected ? min(0.95, 0.5 + (md / expected - 1) / 3) : 0.2,
        magnitude = md / (expected + eps()),
        direction = :multivariate,
        start_index = n0 + 1,
        detector = :mahalanobis,
        kind = :multivariate,
        evidence = detected ?
                   ["Mean Mahalanobis distance $(round(md; digits=3)) exceeded √p baseline."] :
                   String["Current window remains inside the baseline Mahalanobis envelope."],
        details = (; mean_distance = md, p),
    )
end

function _mv_pca(B, C, n0; k::Int = 0)
    μ = vec(mean(B; dims = 1))
    Bc = B .- μ'
    U, S, _ = svd(Bc; full = false)
    kk = k <= 0 ? max(1, min(3, length(S))) : min(k, length(S))
    scores_b = U[:, 1:kk] .* S[1:kk]'
    # project current
    V = (Bc' * U[:, 1:kk]) ./ (S[1:kk]' .+ eps())  # not used; use right vectors
    # Use SVD of centered B: B_c = U S V'
    _, _, Vt = svd(Bc; full = false)
    V = Vt[:, 1:kk]
    Cb = (B .- μ') * V
    Cc = (C .- μ') * V
    μs = vec(mean(Cb; dims = 1))
    Σ = cov(Cb) + 1e-6 * I
    invΣ = inv(Σ)
    t2 = Float64[]
    for i in 1:size(Cc, 1)
        δ = vec(Cc[i, :]) .- μs
        push!(t2, δ' * invΣ * δ)
    end
    mt2 = mean(t2)
    detected = mt2 > 2 * kk
    DriftResult(;
        detected,
        probability = detected ? min(0.95, mt2 / (mt2 + kk)) : 0.2,
        magnitude = mt2,
        direction = :multivariate,
        start_index = n0 + 1,
        detector = :pca,
        kind = :multivariate,
        evidence = detected ?
                   ["Hotelling T² on $kk PC(s) rose to mean $(round(mt2; digits=2))."] :
                   String["PCA subspace T² remains consistent with baseline."],
        details = (; k = kk, mean_t2 = mt2),
    )
end

function _mv_cov(B, C, n0)
    ρ1 = cor(B)
    ρ2 = cor(C)
    d = norm(ρ1 - ρ2) / size(B, 2)
    detected = d > 0.25
    DriftResult(;
        detected,
        probability = detected ? min(0.9, d) : 0.15,
        magnitude = d,
        direction = :covariance,
        start_index = n0 + 1,
        detector = :covariance,
        kind = :multivariate,
        evidence = detected ?
                   ["Correlation-matrix Frobenius shift $(round(d; digits=3))."] :
                   String["Covariance structure is stable."],
        details = (; frobenius = d),
    )
end

function _mv_energy(B, C, n0)
    # Average pairwise Euclidean energy (Székely & Rizzo), O(n²)
    function mean_dist(P, Q)
        s = 0.0
        n = size(P, 1)
        m = size(Q, 1)
        for i in 1:n, j in 1:m
            s += norm(view(P, i, :) .- view(Q, j, :))
        end
        s / (n * m)
    end
    d = 2 * mean_dist(B, C) - mean_dist(B, B) - mean_dist(C, C)
    detected = d > 0.15 * (mean(abs.(B)) + 1)
    DriftResult(;
        detected,
        probability = detected ? 0.75 : 0.2,
        magnitude = d,
        direction = :multivariate,
        start_index = n0 + 1,
        detector = :energy,
        kind = :multivariate,
        evidence = detected ?
                   ["Multivariate energy distance $(round(d; digits=4))."] :
                   String["Energy distance between windows is small."],
        details = (; energy = d),
    )
end

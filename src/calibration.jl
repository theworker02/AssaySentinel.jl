# Calibration curves and calibration-to-calibration comparison.

"""
    calibrate(concentrations, responses; model=:linear, weights=nothing)

Fit a calibration curve.

Models: `:linear`, `:weighted_linear`, `:polynomial`, `:robust`,
`:spline`, `:fourpl`.
"""
function calibrate(concentrations::AbstractVector, responses::AbstractVector;
                   model::Symbol = :linear,
                   weights = nothing,
                   degree::Int = 2)
    x, y = _xy_finite(concentrations, responses)
    n = length(x)
    n < 3 && throw(InsufficientDataError(3, n, "calibrate"))
    if model === :linear
        return _cal_ols(x, y, :linear)
    elseif model === :weighted_linear
        w = weights === nothing ? 1.0 ./ (abs.(x) .+ 0.1) : Float64.(weights)
        return _cal_wls(x, y, w)
    elseif model === :polynomial
        return _cal_poly(x, y, degree)
    elseif model === :robust
        return _cal_robust(x, y)
    elseif model === :spline
        return _cal_spline(x, y)
    elseif model === :fourpl || model === :nonlinear
        return _cal_fourpl(x, y)
    else
        throw(ArgumentError("Unknown calibration model :$model"))
    end
end

function _xy_finite(x, y)
    xs = Float64[]
    ys = Float64[]
    for (a, b) in zip(x, y)
        if a isa Number && b isa Number && isfinite(Float64(a)) && isfinite(Float64(b))
            push!(xs, Float64(a))
            push!(ys, Float64(b))
        end
    end
    xs, ys
end

function _r2(y, yhat)
    ss_res = sum(abs2, y .- yhat)
    ss_tot = sum(abs2, y .- mean(y))
    ss_tot == 0 ? 1.0 : 1 - ss_res / ss_tot
end

function _curve(model, β, x, y, yhat; weights = nothing, extra = EmptyMeta)
    CalibrationCurve(model, collect(Float64, β), sqrt(mean(abs2, y .- yhat)),
                     length(y), _r2(y, yhat), weights, collect(x), collect(y),
                     Any[], extra)
end

function _cal_ols(x, y, model)
    X = hcat(ones(length(x)), x)
    β = X \ y
    yhat = X * β
    _curve(model, β, x, y, yhat)
end

function _cal_wls(x, y, w)
    W = sqrt.(w)
    X = hcat(W, W .* x)
    β = X \ (W .* y)
    yhat = β[1] .+ β[2] .* x
    _curve(:weighted_linear, β, x, y, yhat; weights = collect(w))
end

function _cal_poly(x, y, degree)
    degree = clamp(degree, 1, 5)
    X = ones(length(x), degree + 1)
    for p in 1:degree
        X[:, p + 1] = x .^ p
    end
    β = X \ y
    _curve(:polynomial, β, x, y, X * β; extra = (; degree))
end

function _cal_robust(x, y)
    fit = theil_sen(x, y)
    β = [fit.intercept, fit.slope]
    yhat = β[1] .+ β[2] .* x
    _curve(:robust, β, x, y, yhat)
end

function _cal_spline(x, y)
    fit = _natural_cubic_fit(x, y)
    if fit === nothing
        c = _cal_ols(x, y, :linear)
        return CalibrationCurve(:spline, c.coefficients, c.residual_sd, c.n, c.r_squared,
                                nothing, c.concentrations, c.responses, Any[],
                                (; fallback = :linear))
    end
    xs, ys, M = fit
    yhat = [_eval_natural_cubic(xs, ys, M, xi) for xi in x]
    β = vcat(Float64(length(xs)), xs, ys, M)
    _curve(:spline, β, x, y, yhat; extra = (; knots = length(xs), kind = :natural_cubic))
end

"""
Natural cubic spline on unique knots (averaged y at repeated x).
Second derivatives M_i from the standard tridiagonal system; M_1 = M_n = 0.
"""
function _natural_cubic_fit(x::AbstractVector, y::AbstractVector)
    perm = sortperm(x)
    xs = x[perm]
    ys = y[perm]
    ux = Float64[]
    uy = Float64[]
    i = 1
    n0 = length(xs)
    while i <= n0
        j = i
        s = ys[i]
        c = 1
        while j < n0 && xs[j + 1] == xs[i]
            j += 1
            s += ys[j]
            c += 1
        end
        push!(ux, xs[i])
        push!(uy, s / c)
        i = j + 1
    end
    n = length(ux)
    n < 3 && return nothing
    h = diff(ux)
    any(iszero, h) && return nothing
    A = zeros(n, n)
    rhs = zeros(n)
    A[1, 1] = 1.0
    A[n, n] = 1.0
    for i in 2:(n - 1)
        A[i, i - 1] = h[i - 1] / 6
        A[i, i] = (h[i - 1] + h[i]) / 3
        A[i, i + 1] = h[i] / 6
        rhs[i] = (uy[i + 1] - uy[i]) / h[i] - (uy[i] - uy[i - 1]) / h[i - 1]
    end
    M = A \ rhs
    return ux, uy, M
end

function _eval_natural_cubic(xs, ys, M, x)
    if x <= xs[1]
        h = xs[2] - xs[1]
        yp = (ys[2] - ys[1]) / h - h * (2 * M[1] + M[2]) / 6
        return ys[1] + yp * (x - xs[1])
    elseif x >= xs[end]
        h = xs[end] - xs[end - 1]
        yp = (ys[end] - ys[end - 1]) / h + h * (M[end - 1] + 2 * M[end]) / 6
        return ys[end] + yp * (x - xs[end])
    end
    i = searchsortedlast(xs, x)
    i = clamp(i, 1, length(xs) - 1)
    h = xs[i + 1] - xs[i]
    A = (xs[i + 1] - x) / h
    B = (x - xs[i]) / h
    return A * ys[i] + B * ys[i + 1] + ((A^3 - A) * M[i] + (B^3 - B) * M[i + 1]) * h^2 / 6
end

"""
4-parameter logistic: y = d + (a-d) / (1 + (x/c)^b)
Iterative Gauss–Newton on log-safe parameters.
"""
function _cal_fourpl(x, y)
    a0 = maximum(y)
    d0 = minimum(y)
    c0 = median(x)
    b0 = 1.0
    θ = [a0, b0, c0, d0]
    for _ in 1:40
        a, b, c, d = θ
        c = c == 0 ? 1e-6 : c
        yhat = similar(y)
        J = zeros(length(y), 4)
        for i in eachindex(x)
            xc = max(x[i], 0) / abs(c)
            den = 1 + xc^b
            yhat[i] = d + (a - d) / den
            J[i, 1] = 1 / den
            J[i, 2] = -(a - d) * (xc^b * log(max(xc, 1e-12))) / den^2
            J[i, 3] = (a - d) * (b * xc^b / c) / den^2
            J[i, 4] = 1 - 1 / den
        end
        r = y .- yhat
        try
            δ = J \ r
            θ = θ + 0.5 .* δ
        catch
            break
        end
    end
    a, b, c, d = θ
    yhat = [d + (a - d) / (1 + (max(xi, 0) / abs(c))^b) for xi in x]
    _curve(:fourpl, θ, x, y, yhat)
end

function predict_response(curve::CalibrationCurve, x::Real)
    if curve.model === :linear || curve.model === :weighted_linear || curve.model === :robust
        return curve.coefficients[1] + curve.coefficients[2] * x
    elseif curve.model === :polynomial
        s = 0.0
        xp = 1.0
        for β in curve.coefficients
            s += β * xp
            xp *= x
        end
        return s
    elseif curve.model === :fourpl
        a, b, c, d = curve.coefficients
        return d + (a - d) / (1 + (max(x, 0) / abs(c))^b)
    elseif curve.model === :spline
        n = Int(curve.coefficients[1])
        xs = curve.coefficients[2:(n + 1)]
        ys = curve.coefficients[(n + 2):(2n + 1)]
        if length(curve.coefficients) >= 3n + 1
            M = curve.coefficients[(2n + 2):(3n + 1)]
            return _eval_natural_cubic(xs, ys, M, x)
        end
        return _interp_linear(xs, ys, x)
    else
        return curve.coefficients[1] + curve.coefficients[2] * x
    end
end

function _interp_linear(xs, ys, x)
    x <= xs[1] && return ys[1]
    x >= xs[end] && return ys[end]
    i = searchsortedlast(xs, x)
    t = (x - xs[i]) / (xs[i + 1] - xs[i])
    return ys[i] * (1 - t) + ys[i + 1] * t
end

"""
    calibration_diagnostics(curve)

Residual, runs, relative-error, and (when replicates exist) lack-of-fit
diagnostics for a fitted calibration. Does not claim clinical impact.
"""
function calibration_diagnostics(curve::CalibrationCurve)
    x = curve.concentrations
    y = curve.responses
    yhat = predict_response.(Ref(curve), x)
    resid = y .- yhat
    rel = resid ./ (abs.(y) .+ eps())
    rt = runs_test(resid)
    npar = _cal_nparams(curve)
    lof = _lack_of_fit(x, y, yhat, npar)
    names = if curve.model === :fourpl && length(curve.coefficients) >= 4
        (; a = curve.coefficients[1], hill = curve.coefficients[2],
         ec50 = curve.coefficients[3], d = curve.coefficients[4])
    else
        EmptyMeta
    end
    (
        residual_sd = curve.residual_sd,
        r_squared = curve.r_squared,
        mean_relative_error = mean(abs.(rel)),
        max_relative_error = maximum(abs.(rel)),
        runs = rt,
        lack_of_fit = lof,
        parameters = names,
        residuals = resid,
        fitted = yhat,
        notes = "Analytical-curve diagnostics only. Not a clinical performance claim.",
    )
end

function _cal_nparams(curve::CalibrationCurve)
    curve.model === :fourpl && return 4
    curve.model === :polynomial && return length(curve.coefficients)
    curve.model === :spline && return get(curve.metadata, :knots, length(curve.coefficients))
    2
end

function _lack_of_fit(x, y, yhat, npar::Int)
    ux = unique(x)
    has_rep = any(u -> count(==(u), x) >= 2, ux)
    has_rep || return nothing
    ss_pe = 0.0
    df_pe = 0
    for u in ux
        idx = findall(==(u), x)
        length(idx) < 2 && continue
        ym = mean(y[idx])
        ss_pe += sum(abs2, y[idx] .- ym)
        df_pe += length(idx) - 1
    end
    df_pe < 1 && return nothing
    ss_res = sum(abs2, y .- yhat)
    ss_lof = max(ss_res - ss_pe, 0.0)
    df_lof = max(length(ux) - npar, 1)
    ms_lof = ss_lof / df_lof
    ms_pe = ss_pe / df_pe
    F = ms_pe == 0 ? Inf : ms_lof / ms_pe
    # Regularized F tail via chi-squared ratio approximation
    p = F >= Inf ? 0.0 : 1 - _f_cdf(F, df_lof, df_pe)
    (; F, pvalue = p, df_lack = df_lof, df_pure = df_pe, ss_lack = ss_lof, ss_pure = ss_pe)
end

function _f_cdf(F, d1, d2)
    F <= 0 && return 0.0
    # Regularized incomplete beta: P(F ≤ f) = I_{x}(d1/2, d2/2), x = d1 f / (d1 f + d2)
    x = (d1 * F) / (d1 * F + d2)
    _reg_inc_beta(x, d1 / 2, d2 / 2)
end

_loggamma(z::Real) = z <= 0 ? Inf : (z - 0.5) * log(z) - z + 0.5 * log(2π) + 1 / (12z)

function _reg_inc_beta(x, a, b; nterms::Int = 80)
    # Continued series for I_x(a,b) via the incomplete beta series
    x = clamp(x, 0.0, 1.0)
    x == 0 && return 0.0
    x == 1 && return 1.0
    # Prefactor x^a (1-x)^b / (a B(a,b)) * series
    logB = _loggamma(a) + _loggamma(b) - _loggamma(a + b)
    front = exp(a * log(x) + b * log1p(-x) - logB) / a
    term = 1.0
    s = 1.0
    for i in 1:nterms
        term *= (a + i - 1) / (a + i) * x
        s += term
    end
    clamp(front * s, 0.0, 1.0)
end

"""
    compare_calibrations(curve1, curve2)

Report slope/intercept/nonlinearity/residual change. Does not claim a
clinical impact.
"""
function compare_calibrations(c1::CalibrationCurve, c2::CalibrationCurve)
    grid = sort(unique(vcat(c1.concentrations, c2.concentrations)))
    isempty(grid) && (grid = collect(range(0.0, 1.0; length = 11)))
    y1 = predict_response.(Ref(c1), grid)
    y2 = predict_response.(Ref(c2), grid)
    δ = y2 .- y1
    s1 = length(c1.coefficients) >= 2 ? c1.coefficients[2] : NaN
    s2 = length(c2.coefficients) >= 2 ? c2.coefficients[2] : NaN
    i1 = c1.coefficients[1]
    i2 = c2.coefficients[1]
    (
        slope_change = s2 - s1,
        intercept_change = i2 - i1,
        nonlinearity_change = (c2.r_squared - c1.r_squared),
        residual_shift = c2.residual_sd - c1.residual_sd,
        practical_magnitude = mean(abs.(δ)),
        relative_magnitude = mean(abs.(δ)) / (mean(abs.(y1)) + eps()),
        uncertainty = hypot(c1.residual_sd, c2.residual_sd) / sqrt(length(grid)),
        grid = grid,
        delta = δ,
    )
end

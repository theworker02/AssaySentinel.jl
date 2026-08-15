# Synthetic assay streams with known ground truth.

"""
    simulate_assay(; n, drift=:none, rng, ...)

Generate a synthetic measurement stream.

Drift kinds: `:none`, `:linear`, `:step`, `:variance`, `:lot`, `:batch`,
`:periodic`, `:failure`, `:outliers`.
"""
function simulate_assay(;
    n::Int = 1000,
    drift::Symbol = :none,
    drift_start::Int = max(1, n ÷ 2),
    mean::Float64 = 100.0,
    sd::Float64 = 2.0,
    unit::AbstractString = "mg/dL",
    analyte::Symbol = :analyte_x,
    start::DateTime = DateTime(2025, 1, 1),
    step::Period = Hour(6),
    n_lots::Int = 1,
    n_instruments::Int = 1,
    control_every::Int = 10,
    outlier_rate::Float64 = 0.0,
    rng::AbstractRNG = Random.default_rng(),
)
    n >= 2 || throw(ArgumentError("n must be ≥ 2"))
    stream = AssayStream(; analyte, unit, instrument = "Analyzer-1")
    truth = (; drift, drift_start, mean, sd, n)
    lots = ["R$(20 + i)" for i in 1:max(n_lots, 1)]
    instruments = ["Analyzer-$i" for i in 1:max(n_instruments, 1)]
    lot_cuts = [round(Int, i * n / length(lots)) for i in 1:length(lots)]
    for i in 1:n
        t = start + (i - 1) * step
        μ = mean
        σ = sd
        if drift === :linear && i >= drift_start
            μ += 0.004 * (i - drift_start)
        elseif drift === :step && i >= drift_start
            μ += 0.08 * mean
        elseif drift === :variance && i >= drift_start
            σ *= 1.8
        elseif drift === :periodic
            μ += 0.015 * mean * sin(2π * i / 48)
        elseif drift === :failure && i >= drift_start
            μ += 0.2 * mean
            σ *= 2.2
        end
        lot = lots[searchsortedfirst(lot_cuts, i)]
        if drift === :lot && i >= drift_start
            μ += 0.04 * mean
        end
        inst = instruments[mod1(i, length(instruments))]
        if drift === :batch && (i % 96) < 8
            μ += 0.03 * mean
        end
        v = μ + σ * randn(rng)
        if drift === :outliers || outlier_rate > 0
            if rand(rng) < max(outlier_rate, drift === :outliers ? 0.02 : 0.0)
                v += (rand(rng) < 0.5 ? -1 : 1) * 6σ
            end
        end
        push!(stream, Measurement(;
            value = v,
            timestamp = t,
            unit,
            lot,
            instrument = inst,
            batch = "B$(div(i - 1, 48) + 1)",
            control = control_every > 0 && i % control_every == 0,
        ))
    end
    if n_lots > 1
        prev = nothing
        for (i, m) in enumerate(stream.measurements)
            if m.reagent_lot !== prev && prev !== nothing
                record!(stream, LotChangeEvent(m.timestamp, m.reagent_lot; from_lot = prev))
            end
            prev = m.reagent_lot
        end
    end
    return (stream = stream, truth = truth)
end

"""
    showcase_dataset(; rng)

12 months of synthetic measurements: 3 reagent lots, 2 instruments,
one calibration event, gradual drift, variance shift, and control failures.
"""
function showcase_dataset(; rng::AbstractRNG = Random.Xoshiro(20260814))
    n = 1460  # ~4/day for 365 days
    start = DateTime(2025, 8, 1)
    stream = AssayStream(; analyte = :glucose, unit = "mg/dL", instrument = "Analyzer-A")
    lots = ["R21", "R22", "R23"]
    lot_at = [1, 480, 980]
    cal_at = 720
    drift_at = 980
    var_at = 1200
    record!(stream, CalibrationEvent(start + Hour(6) * (cal_at - 1), "CAL-08"))
    record!(stream, LotChangeEvent(start + Hour(6) * 479, "R22"; from_lot = "R21"))
    record!(stream, LotChangeEvent(start + Hour(6) * 979, "R23"; from_lot = "R22"))
    for i in 1:n
        t = start + Hour(6) * (i - 1)
        lot = lots[searchsortedlast(lot_at, i)]
        inst = i % 2 == 0 ? "Analyzer-A" : "Analyzer-B"
        μ = 100.0
        σ = 2.0
        lot == "R22" && (μ += 1.2)
        lot == "R23" && (μ += 2.0)
        i >= cal_at && i < cal_at + 20 && (μ -= 0.8)
        if i >= drift_at
            μ += 0.006 * (i - drift_at)
        end
        if i >= var_at
            σ *= 1.7
        end
        # intentional control failures
        fail = i in (1100, 1101, 1300, 1301, 1302)
        v = μ + σ * randn(rng)
        fail && (v = μ + 3.6 * σ)
        push!(stream, Measurement(;
            value = v,
            timestamp = t,
            unit = "mg/dL",
            lot,
            instrument = inst,
            batch = "B$(div(i - 1, 56) + 1)",
            control = i % 8 == 0 || fail,
            calibration_id = i >= cal_at ? "CAL-08" : "CAL-07",
            uncertainty = 0.4,
        ))
    end
    truth = (
        lots = lots,
        instruments = ["Analyzer-A", "Analyzer-B"],
        calibration_index = cal_at,
        drift_start = drift_at,
        variance_start = var_at,
        control_failures = [1100, 1101, 1300, 1301, 1302],
        months = 12,
    )
    return (stream = stream, truth = truth)
end

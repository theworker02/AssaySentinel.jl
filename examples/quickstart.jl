using AssaySentinel
using Dates
using Random

stream = AssayStream(
    analyte = :glucose,
    unit = "mg/dL",
    instrument = "Analyzer-A",
)

rng = Random.Xoshiro(42)
t0 = DateTime(2026, 1, 1)
for i in 1:240
    μ = i < 140 ? 100.0 : 103.5
    push!(
        stream,
        Measurement(
            value = μ + 1.2 * randn(rng),
            timestamp = t0 + Hour(6) * (i - 1),
            batch = "B$(div(i - 1, 40) + 1)",
            lot = i < 140 ? "R21" : "R22",
            control = i % 8 == 0,
        ),
    )
end

result = analyze(stream; rng)
println(result)
println()
println(explain(result))

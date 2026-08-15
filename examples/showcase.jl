using AssaySentinel
using Random

# 12 months, 3 lots, 2 instruments, calibration, drift, variance, QC failures
data = showcase_dataset(; rng = Random.Xoshiro(20260814))
result = analyze(data.stream; rng = Random.Xoshiro(20260814))

println(result)
println()
println(explain(result))
println()
println("Ground truth (simulation, not inferred):")
println(data.truth)
if result.reconstruction !== nothing
    println()
    println("Reconstruction fingerprint: ", result.reconstruction.input_fingerprint)
    println("rng_seed: ", result.reconstruction.rng_seed)
end

lots = compare_lots(data.stream)
println()
println("Lot analysis:")
foreach(println, lots.evidence)

mkpath(joinpath(@__DIR__, "..", "tmp"))
report(result, joinpath(@__DIR__, "..", "tmp", "showcase-report.html"))
println()
println("Wrote tmp/showcase-report.html")

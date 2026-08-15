using AssaySentinel
using Random
using Statistics

function bench(n; rng = Random.Xoshiro(1))
    sim = simulate_assay(; n, drift = :step, drift_start = max(20, n ÷ 2), rng)
    t0 = time_ns()
    analyze(sim.stream; rng)
    dt = (time_ns() - t0) / 1e9
    return dt
end

function stream_throughput(n; rng = Random.Xoshiro(2))
    sim = simulate_assay(; n, drift = :none, rng)
    base = Baseline(sim.stream)
    sent = Sentinel(base)
    t0 = time_ns()
    for m in sim.stream.measurements
        update!(sent, m)
    end
    dt = (time_ns() - t0) / 1e9
    return n / dt
end

println("AssaySentinel.jl ", AssaySentinel.PACKAGE_VERSION, " benchmarks")
println("Julia ", VERSION, "  threads=", Threads.nthreads())
for n in (100, 10_000)
    times = [bench(n; rng = Random.Xoshiro(10 + k)) for k in 1:3]
    println("analyze n=", n, "  median_s=", median(times))
end
tp = stream_throughput(10_000)
println("streaming throughput n=10000  obs_per_s=", round(tp; digits = 1))
println("Note: 1e6 / 1e7 sizes are opt-in: `julia --project benchmark/run.jl large`")

if get(ARGS, 1, "") == "large"
    for n in (1_000_000,)
        println("analyze n=", n, "  s=", bench(n))
    end
end

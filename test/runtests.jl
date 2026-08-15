using AssaySentinel
using AssaySentinel: IncrementalCUSUM, IncrementalEWMA, valid_values, fingerprint
using AssaySentinel: ks_statistic, wasserstein1d, energy_distance, theil_sen
using AssaySentinel: welch_t, robust_mad, UnitMismatchError, InsufficientDataError
using AssaySentinel: westgard_rules, QCSpec, lot_transitions, record_step!
using Dates
using Random
using Statistics
using Test

@testset "AssaySentinel" begin
    include("test_types.jl")
    include("test_stats.jl")
    include("test_change_points.jl")
    include("test_drift.jl")
    include("test_qc.jl")
    include("test_calibration.jl")
    include("test_batches.jl")
    include("test_reference.jl")
    include("test_comparison.jl")
    include("test_streaming.jl")
    include("test_hierarchy.jl")
    include("test_simulation.jl")
    include("test_reconstruction.jl")
    include("test_provenance.jl")
    include("test_edge_cases.jl")
    include("test_cli.jl")
    include("test_aqua.jl")
end

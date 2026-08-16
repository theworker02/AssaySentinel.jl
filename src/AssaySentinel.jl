"""
    AssaySentinel

Know when the measurement changed before the science does.

AssaySentinel.jl is a high-performance analytical quality and drift-detection
framework for repeated quantitative measurements. It monitors the measurement
process itself — instruments, reagent lots, calibrations, batches, and controls —
rather than diagnosing patients.

# Safety boundary

This software is intended for research, analytical-quality assessment, method
development, and scientific decision support. It is **not** a diagnostic medical
device and must not independently determine patient diagnosis or treatment.

# Example

```julia
using AssaySentinel
using Dates

stream = AssayStream(analyte = :glucose, unit = "mg/dL", instrument = "Analyzer-A")
push!(stream, Measurement(value = 101.2, timestamp = now(), batch = "B104", lot = "R22", control = true))
report = analyze(stream)
explain(report)
```
"""
module AssaySentinel

using Dates
using LinearAlgebra
using Logging
using Printf
using Random
using SHA
using Serialization
using Statistics
using UUIDs

export SAFETY_NOTICE, PACKAGE_VERSION
export UnitMismatchError, InsufficientDataError, AssaySentinelError

export Measurement, Assay, AssayStream, AssayPanel
export ControlSample, ControlSeries, Batch, Instrument, ReagentLot
export Calibration, CalibrationCurve, ReferenceInterval
export Method, Site, Study, Experiment
export Event, Alert, DriftEvent, QualityReport, ProvenanceRecord
export EventTimeline, Baseline, Sentinel, SentinelScore
export DriftResult, ChangePointResult, QCRule, QCRuleResult, QCSpec
export BatchEffectResult, ComparisonResult, DistributionComparison
export AttributionResult, OutlierResult, PartitionResult
export StoryBeat, Reconstruction, UncertaintyBudget
export SiteEffect, HierarchicalSiteResult, StudyReport, StudySentinel
export hierarchical_sites, svg_forest_chart
export SCHEMA_VERSION
export API_STABLE_SINCE
export AbstractDetector, AbstractEvent
export CalibrationEvent, LotChangeEvent, MaintenanceEvent
export MethodChangeEvent, SoftwareUpdateEvent, OperatorChangeEvent
export TemperatureEvent, SiteEvent

export analyze, monitor, detect_drift, detect_changes, detect_batch_effects
export correct_batch_effects, calibrate, compare_calibrations
export compare_methods, compare_instruments, compare_lots, compare_sites
export compare_distribution, reference_interval, assess_partitions, reference_curve
export simulate_assay, evaluate_detector, explain, report, summary
export reconstruct
export detect_outliers, annotate_outliers
export calibration_diagnostics
export lot_chart, instrument_chart
export record!, onalert, update!, alert, fit!, result
export IncrementalCUSUM, IncrementalEWMA
export save, load_report
export convert_unit, check_units
export levey_jennings, levey_jennings_data, control_chart_data
export westgard_rules, evaluate
export @qcrule
export showcase_dataset
export online_series
export main

const PACKAGE_VERSION = v"1.4.0"
const SCHEMA_VERSION = v"1.4.0"
const API_STABLE_SINCE = v"1.0.0"

const SAFETY_NOTICE = """
This software is intended for research, analytical-quality assessment, method \
development, and scientific decision support. It is not a diagnostic medical \
device and must not independently determine patient diagnosis or treatment.
"""

include("errors.jl")
include("types.jl")
include("json.jl")
include("stats.jl")
include("units.jl")
include("outliers.jl")
include("provenance.jl")
include("events.jl")
include("detectors.jl")
include("change_points.jl")
include("drift.jl")
include("multivariate.jl")
include("qc.jl")
include("calibration.jl")
include("batches.jl")
include("reference.jl")
include("comparison.jl")
include("distribution.jl")
include("attribution.jl")
include("streaming.jl")
include("score.jl")
include("sentinel.jl")
include("hierarchy.jl")
include("tables.jl")
include("simulation.jl")
include("evaluation.jl")
include("uncertainty.jl")
include("plots.jl")
include("reconstruction.jl")
include("explain.jl")
include("reporting.jl")
include("cli.jl")

end

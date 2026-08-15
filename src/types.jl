# Core domain types. Prefer concrete structs over dictionaries.

const EmptyMeta = NamedTuple()

_nothing_string(x::Nothing) = nothing
_nothing_string(x::AbstractString) = String(x)
_nothing_string(x::Symbol) = String(x)

"""
    Measurement{T}

A single quantitative observation with provenance metadata.

Keyword `lot` is accepted as an alias for `reagent_lot`.
Missing values and NaN must be represented explicitly; they are never
coerced to zero.
"""
struct Measurement{T <: Real}
    value::T
    uncertainty::Union{Nothing, T}
    unit::String
    timestamp::DateTime
    batch::Union{Nothing, String}
    instrument::Union{Nothing, String}
    reagent_lot::Union{Nothing, String}
    calibration_id::Union{Nothing, String}
    site::Union{Nothing, String}
    method::Union{Nothing, String}
    control::Bool
    control_name::Union{Nothing, String}
    metadata::NamedTuple
end

function Measurement{T}(;
    value,
    uncertainty = nothing,
    unit::AbstractString = "",
    timestamp::DateTime = now(),
    batch = nothing,
    instrument = nothing,
    reagent_lot = nothing,
    lot = nothing,
    calibration_id = nothing,
    site = nothing,
    method = nothing,
    control::Bool = false,
    control_name = nothing,
    metadata::NamedTuple = EmptyMeta,
) where {T <: Real}
    lot_id = reagent_lot === nothing ? lot : reagent_lot
    unc = uncertainty === nothing ? nothing : T(uncertainty)
    Measurement{T}(
        T(value),
        unc,
        String(unit),
        timestamp,
        _nothing_string(batch),
        _nothing_string(instrument),
        _nothing_string(lot_id),
        _nothing_string(calibration_id),
        _nothing_string(site),
        _nothing_string(method),
        control,
        _nothing_string(control_name),
        metadata,
    )
end

Measurement(; kwargs...) = Measurement{Float64}(; kwargs...)

function Base.show(io::IO, m::Measurement)
    ctrl = m.control ? " control" : ""
    print(io, "Measurement(", m.value, " ", m.unit, " @ ", m.timestamp, ctrl, ")")
end

"""
    Instrument
"""
struct Instrument
    name::String
    model::Union{Nothing, String}
    site::Union{Nothing, String}
    metadata::NamedTuple
end

Instrument(name::AbstractString; model = nothing, site = nothing, metadata = EmptyMeta) =
    Instrument(String(name), _nothing_string(model), _nothing_string(site), metadata)

"""
    ReagentLot
"""
struct ReagentLot
    id::String
    analyte::Union{Nothing, Symbol}
    opened_at::Union{Nothing, DateTime}
    metadata::NamedTuple
end

ReagentLot(id::AbstractString; analyte = nothing, opened_at = nothing, metadata = EmptyMeta) =
    ReagentLot(String(id), analyte === nothing ? nothing : Symbol(analyte), opened_at, metadata)

"""
    Method
"""
struct Method
    name::String
    description::String
    metadata::NamedTuple
end

Method(name::AbstractString; description = "", metadata = EmptyMeta) =
    Method(String(name), String(description), metadata)

"""
    Site
"""
struct Site
    name::String
    instruments::Vector{Instrument}
    metadata::NamedTuple
end

Site(name::AbstractString; instruments = Instrument[], metadata = EmptyMeta) =
    Site(String(name), instruments, metadata)

"""
    Study

Hierarchical monitoring container: Study → Site → Instrument.
"""
struct Study
    name::String
    sites::Vector{Site}
    metadata::NamedTuple
end

Study(name::AbstractString; sites = Site[], metadata = EmptyMeta) =
    Study(String(name), sites, metadata)

"""
    Batch
"""
struct Batch
    id::String
    timestamp::Union{Nothing, DateTime}
    metadata::NamedTuple
end

Batch(id::AbstractString; timestamp = nothing, metadata = EmptyMeta) =
    Batch(String(id), timestamp, metadata)

"""
    ControlSample
"""
struct ControlSample
    name::String
    target::Float64
    sd::Float64
    unit::String
    level::Union{Nothing, String}
    metadata::NamedTuple
end

function ControlSample(;
    name::AbstractString,
    target::Real,
    sd::Real,
    unit::AbstractString = "",
    level = nothing,
    metadata = EmptyMeta,
)
    sd > 0 || throw(ArgumentError("ControlSample sd must be positive"))
    ControlSample(String(name), Float64(target), Float64(sd), String(unit),
                  _nothing_string(level), metadata)
end

"""
    Assay
"""
struct Assay
    name::String
    analyte::Symbol
    unit::String
    method::Union{Nothing, String}
    metadata::NamedTuple
end

function Assay(;
    name::AbstractString = "Assay",
    analyte::Symbol,
    unit::AbstractString = "",
    method = nothing,
    metadata = EmptyMeta,
)
    Assay(String(name), analyte, String(unit), _nothing_string(method), metadata)
end

"""
    Experiment
"""
struct Experiment
    name::String
    assays::Vector{Assay}
    metadata::NamedTuple
end

Experiment(name::AbstractString; assays = Assay[], metadata = EmptyMeta) =
    Experiment(String(name), assays, metadata)

"""
    Calibration
"""
struct Calibration
    id::String
    timestamp::DateTime
    instrument::Union{Nothing, String}
    reagent_lot::Union{Nothing, String}
    model::Symbol
    metadata::NamedTuple
end

function Calibration(;
    id::AbstractString = string(uuid4())[1:8],
    timestamp::DateTime = now(),
    instrument = nothing,
    reagent_lot = nothing,
    model::Symbol = :linear,
    metadata = EmptyMeta,
)
    Calibration(String(id), timestamp, _nothing_string(instrument),
                _nothing_string(reagent_lot), model, metadata)
end

"""
    CalibrationCurve
"""
struct CalibrationCurve
    model::Symbol
    coefficients::Vector{Float64}
    residual_sd::Float64
    n::Int
    r_squared::Float64
    weights::Union{Nothing, Vector{Float64}}
    concentrations::Vector{Float64}
    responses::Vector{Float64}
    provenance::Vector{Any}
    metadata::NamedTuple
end

"""
    ReferenceInterval
"""
struct ReferenceInterval
    lower::Float64
    upper::Float64
    lower_ci::Union{Nothing, Tuple{Float64, Float64}}
    upper_ci::Union{Nothing, Tuple{Float64, Float64}}
    method::Symbol
    n::Int
    unit::String
    notes::String
    metadata::NamedTuple
end

# --- events ---

"""
    AbstractEvent
"""
abstract type AbstractEvent end

"""
    Event

Generic operational event on the measurement system.
"""
struct Event <: AbstractEvent
    kind::Symbol
    timestamp::DateTime
    label::String
    metadata::NamedTuple
end

Event(kind::Symbol, timestamp::DateTime, label::AbstractString; metadata = EmptyMeta) =
    Event(kind, timestamp, String(label), metadata)

struct CalibrationEvent <: AbstractEvent
    timestamp::DateTime
    calibration_id::String
    label::String
    metadata::NamedTuple
end

CalibrationEvent(timestamp::DateTime, calibration_id::AbstractString;
                 label = "calibration", metadata = EmptyMeta) =
    CalibrationEvent(timestamp, String(calibration_id), String(label), metadata)

struct LotChangeEvent <: AbstractEvent
    timestamp::DateTime
    from_lot::Union{Nothing, String}
    to_lot::String
    label::String
    metadata::NamedTuple
end

LotChangeEvent(timestamp::DateTime, to_lot::AbstractString;
               from_lot = nothing, label = "reagent lot change", metadata = EmptyMeta) =
    LotChangeEvent(timestamp, _nothing_string(from_lot), String(to_lot), String(label), metadata)

struct MaintenanceEvent <: AbstractEvent
    timestamp::DateTime
    label::String
    metadata::NamedTuple
end

MaintenanceEvent(timestamp::DateTime; label = "instrument maintenance", metadata = EmptyMeta) =
    MaintenanceEvent(timestamp, String(label), metadata)

struct MethodChangeEvent <: AbstractEvent
    timestamp::DateTime
    from_method::Union{Nothing, String}
    to_method::String
    label::String
    metadata::NamedTuple
end

MethodChangeEvent(timestamp::DateTime, to_method::AbstractString;
                  from_method = nothing, label = "method change", metadata = EmptyMeta) =
    MethodChangeEvent(timestamp, _nothing_string(from_method), String(to_method),
                      String(label), metadata)

struct SoftwareUpdateEvent <: AbstractEvent
    timestamp::DateTime
    label::String
    metadata::NamedTuple
end

SoftwareUpdateEvent(timestamp::DateTime; label = "software update", metadata = EmptyMeta) =
    SoftwareUpdateEvent(timestamp, String(label), metadata)

struct OperatorChangeEvent <: AbstractEvent
    timestamp::DateTime
    label::String
    metadata::NamedTuple
end

OperatorChangeEvent(timestamp::DateTime; label = "operator change", metadata = EmptyMeta) =
    OperatorChangeEvent(timestamp, String(label), metadata)

struct TemperatureEvent <: AbstractEvent
    timestamp::DateTime
    label::String
    metadata::NamedTuple
end

TemperatureEvent(timestamp::DateTime; label = "temperature excursion", metadata = EmptyMeta) =
    TemperatureEvent(timestamp, String(label), metadata)

struct SiteEvent <: AbstractEvent
    timestamp::DateTime
    label::String
    metadata::NamedTuple
end

SiteEvent(timestamp::DateTime; label = "site change", metadata = EmptyMeta) =
    SiteEvent(timestamp, String(label), metadata)

event_time(e::AbstractEvent) = e.timestamp
event_label(e::AbstractEvent) = e.label
event_kind(::CalibrationEvent) = :calibration
event_kind(::LotChangeEvent) = :lot_change
event_kind(::MaintenanceEvent) = :maintenance
event_kind(::MethodChangeEvent) = :method_change
event_kind(::SoftwareUpdateEvent) = :software_update
event_kind(::OperatorChangeEvent) = :operator_change
event_kind(::TemperatureEvent) = :temperature
event_kind(::SiteEvent) = :site

function event_kind(e::Event)
    e.kind
end

"""
    EventTimeline
"""
struct EventTimeline
    events::Vector{AbstractEvent}
end

EventTimeline() = EventTimeline(AbstractEvent[])

"""
    Alert

Analytical alert. Severity is one of `:info`, `:watch`, `:warning`, `:critical`.
These are analytical-process severities, not clinical interpretations.
"""
struct Alert
    severity::Symbol
    timestamp::DateTime
    message::String
    kind::Symbol
    evidence::Vector{String}
    metadata::NamedTuple
end

function Alert(;
    severity::Symbol = :watch,
    timestamp::DateTime = now(),
    message::AbstractString,
    kind::Symbol = :drift,
    evidence = String[],
    metadata = EmptyMeta,
)
    severity in (:info, :watch, :warning, :critical) ||
        throw(ArgumentError("severity must be :info, :watch, :warning, or :critical"))
    Alert(severity, timestamp, String(message), kind, Vector{String}(evidence), metadata)
end

"""
    DriftResult
"""
struct DriftResult
    detected::Bool
    probability::Float64
    magnitude::Float64
    direction::Symbol
    start_time::Union{Nothing, DateTime}
    start_index::Union{Nothing, Int}
    detector::Symbol
    kind::Symbol
    evidence::Vector{String}
    details::NamedTuple
end

function DriftResult(;
    detected::Bool,
    probability::Real = detected ? 0.8 : 0.2,
    magnitude::Real = 0.0,
    direction::Symbol = :none,
    start_time = nothing,
    start_index = nothing,
    detector::Symbol = :auto,
    kind::Symbol = :unspecified,
    evidence = String[],
    details = EmptyMeta,
)
    DriftResult(detected, Float64(probability), Float64(magnitude), direction,
                start_time, start_index, detector, kind,
                Vector{String}(evidence), details)
end

"""
    DriftEvent
"""
struct DriftEvent <: AbstractEvent
    timestamp::DateTime
    label::String
    result::DriftResult
    metadata::NamedTuple
end

"""
    ChangePointResult
"""
struct ChangePointResult
    detected::Bool
    indices::Vector{Int}
    timestamps::Vector{DateTime}
    statistic::Float64
    method::Symbol
    selection_reason::String
    confidence::Float64
    evidence::Vector{String}
    details::NamedTuple
end

"""
    QCSpec
"""
struct QCSpec
    mean::Float64
    sd::Float64
end

QCSpec(c::ControlSample) = QCSpec(c.target, c.sd)

"""
    QCRuleResult
"""
struct QCRuleResult
    name::String
    triggered::Bool
    indices::Vector{Int}
    message::String
    severity::Symbol
    statement_kind::Symbol  # :observed, :statistical, :inference, :annotation
end

"""
    QCRule
"""
struct QCRule
    name::String
    description::String
    fn::Function
    severity::Symbol
end

function QCRule(name::AbstractString, fn::Function;
                description::AbstractString = "",
                severity::Symbol = :warning)
    QCRule(String(name), String(description), fn, severity)
end

"""
    ControlSeries
"""
struct ControlSeries
    control::ControlSample
    values::Vector{Float64}
    timestamps::Vector{DateTime}
    metadata::NamedTuple
end

"""
    OutlierResult
"""
struct OutlierResult
    indices::Vector{Int}
    scores::Vector{Float64}
    method::Symbol
    threshold::Float64
    removed::Bool
    notes::String
end

"""
    BatchEffectResult
"""
struct BatchEffectResult
    detected::Bool
    batch_statistic::Float64
    batch_pvalue::Float64
    biological_statistic::Union{Nothing, Float64}
    biological_pvalue::Union{Nothing, Float64}
    interpretation::String
    batches::Vector{String}
    method::Symbol
    evidence::Vector{String}
    details::NamedTuple
end

"""
    ComparisonResult
"""
struct ComparisonResult
    kind::Symbol
    bias::Float64
    proportional_bias::Float64
    loa_lower::Float64
    loa_upper::Float64
    slope::Float64
    intercept::Float64
    n::Int
    method::Symbol
    evidence::Vector{String}
    details::NamedTuple
end

"""
    DistributionComparison
"""
struct DistributionComparison
    statistic::Float64
    pvalue::Union{Nothing, Float64}
    method::Symbol
    selection_reason::String
    n_baseline::Int
    n_current::Int
    evidence::Vector{String}
    details::NamedTuple
end

"""
    PartitionResult
"""
struct PartitionResult
    groups::Vector{String}
    statistic::Float64
    pvalue::Float64
    method::Symbol
    may_partition::Bool
    notes::String
    evidence::Vector{String}
end

"""
    AttributionResult

Temporal association between a detected change and nearby operational events.
Never claims causation from association alone.
"""
struct AttributionResult
    event::Union{Nothing, AbstractEvent}
    score::Float64
    statement::String
    evidence::Vector{String}
end

"""
    ProvenanceRecord
"""
struct ProvenanceRecord
    id::String
    timestamp::DateTime
    operation::Symbol
    func::String
    parameters::Dict{String, Any}
    input_fingerprint::String
    output_fingerprint::Union{Nothing, String}
    package_version::String
    rng_seed::Union{Nothing, UInt64}
    parent_ids::Vector{String}
    notes::String
    statement_kind::Symbol
end

"""
    Baseline

Reference window against which incoming measurements are compared.
"""
struct Baseline
    values::Vector{Float64}
    timestamps::Vector{DateTime}
    n::Int
    time_range::Union{Nothing, Tuple{DateTime, DateTime}}
    instrument::Union{Nothing, String}
    reagent_lot::Union{Nothing, String}
    method::Union{Nothing, String}
    mean::Float64
    sd::Float64
    median::Float64
    mad::Float64
    unit::String
    provenance::Vector{ProvenanceRecord}
    metadata::NamedTuple
end

"""
    SentinelScore

Composite analytical-stability score on 0–100. This is **not** a patient-risk
score. Components are always retained and never hidden.
"""
struct SentinelScore
    value::Float64
    components::NamedTuple
    weights::NamedTuple
    formula::String
end

"""
    StoryBeat

One dated chapter in an analytical reconstruction.
"""
struct StoryBeat
    label::String
    kind::Symbol
    timestamp::Union{Nothing, DateTime}
    index::Union{Nothing, Int}
    statement_kind::Symbol
    notes::String
end

"""
    UncertaintyBudget

How measurement uncertainty and analytical scatter combine.
This is analytical-process uncertainty, not a clinical interval.
"""
struct UncertaintyBudget
    n_with_uncertainty::Int
    rms_measurement::Union{Nothing, Float64}
    analytical_sd::Float64
    combined_sd::Float64
    weighted_mean::Union{Nothing, Float64}
    magnitude_se::Float64
    notes::String
end

"""
    Reconstruction

A defensible reconstruction of how the measurement system behaved:
ordered story beats, uncertainty, lot/instrument evidence, SVG charts,
and a provenance graph. Produced by `analyze` / `reconstruct`.
"""
struct Reconstruction
    beats::Vector{StoryBeat}
    narrative::String
    uncertainty::UncertaintyBudget
    lot_analysis::Any
    instrument_analysis::Any
    charts::NamedTuple
    provenance_graph::NamedTuple
    rng_seed::Union{Nothing, UInt64}
    input_fingerprint::String
    package_version::String
end

"""
    QualityReport
"""
struct QualityReport
    analyte::Symbol
    status::Symbol
    score::SentinelScore
    drift::DriftResult
    change_points::ChangePointResult
    qc::Vector{QCRuleResult}
    distribution::Union{Nothing, DistributionComparison}
    attribution::Union{Nothing, AttributionResult}
    outliers::Union{Nothing, OutlierResult}
    evidence::Vector{String}
    limitations::Vector{String}
    provenance::Vector{ProvenanceRecord}
    unit::String
    n::Int
    time_range::Union{Nothing, Tuple{DateTime, DateTime}}
    safety_notice::String
    reconstruction::Union{Nothing, Reconstruction}
    metadata::NamedTuple
end

"""
    AssayStream{T}

Ordered stream of measurements for one analyte / measurement system.
"""
mutable struct AssayStream{T <: Real}
    analyte::Symbol
    unit::String
    instrument::Union{Nothing, String}
    method::Union{Nothing, String}
    site::Union{Nothing, String}
    measurements::Vector{Measurement{T}}
    events::EventTimeline
    provenance::Vector{ProvenanceRecord}
    metadata::NamedTuple
end

function AssayStream(;
    analyte::Symbol,
    unit::AbstractString,
    instrument = nothing,
    method = nothing,
    site = nothing,
    metadata = EmptyMeta,
)
    AssayStream{Float64}(
        analyte,
        String(unit),
        _nothing_string(instrument),
        _nothing_string(method),
        _nothing_string(site),
        Measurement{Float64}[],
        EventTimeline(),
        ProvenanceRecord[],
        metadata,
    )
end

function Base.push!(stream::AssayStream{T}, m::Measurement{S}) where {T, S}
    if !isempty(m.unit) && !isempty(stream.unit)
        check_units(stream.unit, m.unit)
    end
    inst = m.instrument === nothing ? stream.instrument : m.instrument
    lot = m.reagent_lot
    converted = Measurement{T}(;
        value = m.value,
        uncertainty = m.uncertainty,
        unit = isempty(m.unit) ? stream.unit : m.unit,
        timestamp = m.timestamp,
        batch = m.batch,
        instrument = inst,
        reagent_lot = lot,
        calibration_id = m.calibration_id,
        site = m.site === nothing ? stream.site : m.site,
        method = m.method === nothing ? stream.method : m.method,
        control = m.control,
        control_name = m.control_name,
        metadata = m.metadata,
    )
    push!(stream.measurements, converted)
    stream
end

Base.length(stream::AssayStream) = length(stream.measurements)
Base.eltype(::AssayStream{T}) where {T} = Measurement{T}
Base.iterate(stream::AssayStream) = iterate(stream.measurements)
Base.iterate(stream::AssayStream, state) = iterate(stream.measurements, state)

"""
    AssayPanel

Simultaneous monitoring of many analytes.
"""
struct AssayPanel
    name::String
    streams::Dict{Symbol, AssayStream}
    metadata::NamedTuple
end

AssayPanel(name::AbstractString; streams = Dict{Symbol, AssayStream}(), metadata = EmptyMeta) =
    AssayPanel(String(name), streams, metadata)

function Base.push!(panel::AssayPanel, stream::AssayStream)
    panel.streams[stream.analyte] = stream
    panel
end

"""
    SiteEffect

Empirical-Bayes site location after hierarchical shrinkage.
"""
struct SiteEffect
    site::String
    n::Int
    raw_mean::Float64
    shrunk_mean::Float64
    raw_sd::Float64
    shrinkage::Float64
    drift::DriftResult
end

"""
    HierarchicalSiteResult

Study-level random-effects summary. Attribution is statistical
(global vs site-specific vs mixed), not causal.
"""
struct HierarchicalSiteResult
    sites::Vector{SiteEffect}
    grand_mean::Float64
    between_sd::Float64
    within_sd::Float64
    global_drift::DriftResult
    heterogeneity_q::Float64
    heterogeneity_p::Float64
    attribution::Symbol
    concordance::Float64
    evidence::Vector{String}
    notes::String
    metadata::NamedTuple
end

"""
    StudyReport

Frozen study-level product: per-site `QualityReport`s plus the hierarchical
combine. Schema version is stored for reload compatibility.
"""
struct StudyReport
    name::String
    hierarchy::HierarchicalSiteResult
    site_reports::Dict{String, QualityReport}
    safety_notice::String
    schema_version::String
    package_version::String
    metadata::NamedTuple
end

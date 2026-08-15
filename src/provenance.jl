# Provenance graph: every analysis step can be recorded and later explained.

function ProvenanceRecord(;
    operation::Symbol,
    func::AbstractString,
    parameters = Dict{String, Any}(),
    input_fingerprint::AbstractString = "",
    output_fingerprint = nothing,
    rng_seed = nothing,
    parent_ids = String[],
    notes::AbstractString = "",
    statement_kind::Symbol = :algorithmic,
    timestamp::DateTime = now(),
    id::AbstractString = new_id(),
)
    ProvenanceRecord(
        String(id),
        timestamp,
        operation,
        String(func),
        Dict{String, Any}(parameters),
        String(input_fingerprint),
        output_fingerprint === nothing ? nothing : String(output_fingerprint),
        string(PACKAGE_VERSION),
        rng_seed === nothing ? nothing : UInt64(rng_seed),
        Vector{String}(parent_ids),
        String(notes),
        statement_kind,
    )
end

function record_step!(dest::Vector{ProvenanceRecord}; kwargs...)
    rec = ProvenanceRecord(; kwargs...)
    push!(dest, rec)
    rec
end

function provenance_graph(records::Vector{ProvenanceRecord})
    nodes = [(r.id, r.operation, r.func) for r in records]
    edges = Tuple{String, String}[]
    for r in records
        for p in r.parent_ids
            push!(edges, (p, r.id))
        end
    end
    return (nodes = nodes, edges = edges)
end

function provenance_lines(records::Vector{ProvenanceRecord})
    isempty(records) && return ["(no provenance recorded)"]
    lines = String[]
    for (i, r) in enumerate(records)
        push!(
            lines,
            @sprintf("%d. %s → %s  [%s]  fp=%s  v=%s",
                i, r.operation, r.func, r.statement_kind,
                r.input_fingerprint, r.package_version)
        )
        if !isempty(r.notes)
            push!(lines, "   " * r.notes)
        end
    end
    lines
end

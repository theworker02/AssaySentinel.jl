# Tables.jl interface. Do not require DataFrames internally.

function from_table(table;
                    analyte::Symbol,
                    unit::AbstractString = "",
                    value = :value,
                    time = :timestamp,
                    lot = nothing,
                    instrument = nothing,
                    batch = nothing,
                    control = nothing,
                    site = nothing)
    stream = AssayStream(; analyte, unit)
    for row in _table_rows(table)
        v = _rowget(row, value)
        v isa Number && isfinite(Float64(v)) || continue
        t = time === nothing ? now() : _rowget(row, time)
        t === nothing && (t = now())
        lotv = lot === nothing ? nothing : _rowget(row, lot)
        inst = instrument === nothing ? nothing : _rowget(row, instrument)
        bat = batch === nothing ? nothing : _rowget(row, batch)
        ctrl = control === nothing ? false : Bool(_truthy(_rowget(row, control)))
        st = site === nothing ? nothing : _rowget(row, site)
        push!(stream, Measurement(;
            value = Float64(v),
            timestamp = DateTime(t),
            unit,
            lot = lotv === nothing ? nothing : string(lotv),
            instrument = inst === nothing ? nothing : string(inst),
            batch = bat === nothing ? nothing : string(bat),
            site = st === nothing ? nothing : string(st),
            control = ctrl,
        ))
    end
    stream
end

_truthy(x::Bool) = x
_truthy(::Nothing) = false
_truthy(::Missing) = false
_truthy(x::Number) = x != 0
_truthy(x::AbstractString) = lowercase(x) in ("true", "1", "yes", "control", "qc")
_truthy(x) = false

# First-class unit awareness. No silent conversion between incompatible units.

const UNIT_ALIASES = Dict{String, String}(
    "mg/dl" => "mg/dL",
    "mg/dL" => "mg/dL",
    "mmol/l" => "mmol/L",
    "mmol/L" => "mmol/L",
    "g/l" => "g/L",
    "g/L" => "g/L",
    "ug/l" => "μg/L",
    "μg/l" => "μg/L",
    "ug/dl" => "μg/dL",
    "iu/l" => "IU/L",
    "u/l" => "U/L",
    "percent" => "%",
    "pct" => "%",
)

normalize_unit(u::AbstractString) = get(UNIT_ALIASES, String(u), String(u))
normalize_unit(u::Symbol) = normalize_unit(String(u))

"""
    check_units(a, b)

Throw `UnitMismatchError` unless `a` and `b` denote the same unit after
alias normalization. Empty units are treated as unspecified and allowed.
"""
function check_units(a, b)
    ua, ub = normalize_unit(string(a)), normalize_unit(string(b))
    (isempty(ua) || isempty(ub) || ua == ub) && return nothing
    throw(UnitMismatchError(ua, ub))
end

"""
    convert_unit(value, from, to; molar_mass=nothing, factor=nothing)

Explicit conversion only. Common clinical-chemistry conversions require
`molar_mass` (g/mol) when moving between mass and molar concentration.

This function never guesses an analyte.
"""
function convert_unit(value::Real, from, to; molar_mass = nothing, factor = nothing)
    src, dst = normalize_unit(from), normalize_unit(to)
    src == dst && return Float64(value)
    factor !== nothing && return Float64(value) * Float64(factor)
    if src == "mg/dL" && dst == "mmol/L"
        molar_mass === nothing &&
            throw(ArgumentError("convert_unit(mg/dL → mmol/L) requires molar_mass in g/mol"))
        return Float64(value) * 10 / Float64(molar_mass)
    elseif src == "mmol/L" && dst == "mg/dL"
        molar_mass === nothing &&
            throw(ArgumentError("convert_unit(mmol/L → mg/dL) requires molar_mass in g/mol"))
        return Float64(value) * Float64(molar_mass) / 10
    elseif src == "g/L" && dst == "mg/dL"
        return Float64(value) * 100
    elseif src == "mg/dL" && dst == "g/L"
        return Float64(value) / 100
    else
        throw(UnitMismatchError(src, dst,
            "No built-in conversion from $src to $dst. Pass factor= or convert with Unitful."))
    end
end

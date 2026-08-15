module AssaySentinelUnitfulExt

using AssaySentinel
using Unitful

function AssaySentinel.check_units(a::Unitful.Units, b::Unitful.Units)
    dimension(a) == dimension(b) ||
        throw(AssaySentinel.UnitMismatchError(string(a), string(b)))
    return nothing
end

function AssaySentinel.check_units(a::Unitful.Quantity, b::Unitful.Quantity)
    AssaySentinel.check_units(unit(a), unit(b))
end

function AssaySentinel.convert_unit(value::Unitful.Quantity, from, to; kwargs...)
    uconvert(to isa Unitful.Units ? to : uparse(string(to)), value)
end

end

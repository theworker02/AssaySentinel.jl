"""
    AssaySentinelError

Base error type for AssaySentinel.
"""
abstract type AssaySentinelError <: Exception end

"""
    UnitMismatchError

Raised when two quantities are compared or combined without an explicit
unit conversion. `mg/dL` is never treated as equivalent to `mmol/L`.
"""
struct UnitMismatchError <: AssaySentinelError
    left::String
    right::String
    message::String
end

function UnitMismatchError(left, right)
    UnitMismatchError(
        string(left),
        string(right),
        "Refusing to compare incompatible units $(left) and $(right). \
         Convert explicitly with convert_unit.",
    )
end

function Base.showerror(io::IO, e::UnitMismatchError)
    print(io, "UnitMismatchError: ", e.message)
end

"""
    InsufficientDataError

Raised when a method cannot be applied because too few valid observations
remain after missing/NaN handling.
"""
struct InsufficientDataError <: AssaySentinelError
    needed::Int
    got::Int
    context::String
end

function Base.showerror(io::IO, e::InsufficientDataError)
    print(io, "InsufficientDataError: ", e.context,
          " (need ≥ ", e.needed, ", got ", e.got, ")")
end

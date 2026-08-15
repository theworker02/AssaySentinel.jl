# Minimal JSON writer so the core package stays stdlib-only.

function json_print(io::IO, x, indent::Int = 0)
    print(io, json_string(x))
end

function json_string(x)
    io = IOBuffer()
    _json(io, x)
    String(take!(io))
end

function _json(io::IO, x::AbstractDict)
    print(io, '{')
    first = true
    for (k, v) in x
        first || print(io, ',')
        first = false
        _json(io, string(k))
        print(io, ':')
        _json(io, v)
    end
    print(io, '}')
end

function _json(io::IO, x::AbstractVector)
    print(io, '[')
    for (i, v) in enumerate(x)
        i > 1 && print(io, ',')
        _json(io, v)
    end
    print(io, ']')
end

_json(io::IO, x::Bool) = print(io, x ? "true" : "false")
_json(io::IO, ::Nothing) = print(io, "null")
_json(io::IO, x::Integer) = print(io, x)
function _json(io::IO, x::Real)
    isfinite(x) || (print(io, "null"); return)
    print(io, x)
end

function _json(io::IO, x::AbstractString)
    print(io, '"')
    for c in x
        if c == '"'
            print(io, "\\\"")
        elseif c == '\\'
            print(io, "\\\\")
        elseif c == '\n'
            print(io, "\\n")
        elseif c == '\r'
            print(io, "\\r")
        elseif c == '\t'
            print(io, "\\t")
        else
            print(io, c)
        end
    end
    print(io, '"')
end

_json(io::IO, x::Symbol) = _json(io, string(x))
_json(io::IO, x::NamedTuple) =
    _json(io, Dict{String, Any}(string(k) => getfield(x, k) for k in keys(x)))
_json(io::IO, x::Tuple) = _json(io, collect(x))
_json(io::IO, x) = _json(io, string(x))

# --- minimal JSON reader (objects, arrays, strings, numbers, bool, null) ---

mutable struct _JSONParser
    s::String
    i::Int
end

"""
    json_parse(text)

Parse a JSON object, array, or scalar produced by `json_string`.
Used so `.json` reports can be reloaded without a JSON.jl dependency.
"""
function json_parse(text::AbstractString)
    p = _JSONParser(String(text), 1)
    v = _parse_value!(p)
    _skip_ws!(p)
    p.i <= lastindex(p.s) && error("json_parse: trailing content at $(p.i)")
    v
end

function _skip_ws!(p::_JSONParser)
    s, i, n = p.s, p.i, lastindex(p.s)
    while i <= n && (s[i] == ' ' || s[i] == '\n' || s[i] == '\r' || s[i] == '\t')
        i = nextind(s, i)
    end
    p.i = i
end

function _peek(p::_JSONParser)
    _skip_ws!(p)
    p.i > lastindex(p.s) && error("json_parse: unexpected end of input")
    p.s[p.i]
end

function _take!(p::_JSONParser)
    c = _peek(p)
    p.i = nextind(p.s, p.i)
    c
end

function _expect!(p::_JSONParser, c::Char)
    got = _take!(p)
    got == c || error("json_parse: expected '$c', got '$got'")
    got
end

function _parse_value!(p::_JSONParser)
    c = _peek(p)
    c == '{' && return _parse_object!(p)
    c == '[' && return _parse_array!(p)
    c == '"' && return _parse_string!(p)
    c == 't' && return _parse_literal!(p, "true", true)
    c == 'f' && return _parse_literal!(p, "false", false)
    c == 'n' && return _parse_literal!(p, "null", nothing)
    (c == '-' || isdigit(c)) && return _parse_number!(p)
    error("json_parse: unexpected '$c' at $(p.i)")
end

function _parse_literal!(p::_JSONParser, word::String, value)
    for c in word
        _expect!(p, c)
    end
    value
end

function _parse_object!(p::_JSONParser)
    _expect!(p, '{')
    d = Dict{String, Any}()
    _skip_ws!(p)
    if _peek(p) == '}'
        _take!(p)
        return d
    end
    while true
        _peek(p) == '"' || error("json_parse: object key must be a string")
        k = _parse_string!(p)
        _expect!(p, ':')
        d[k] = _parse_value!(p)
        c = _peek(p)
        if c == ','
            _take!(p)
            continue
        elseif c == '}'
            _take!(p)
            return d
        else
            error("json_parse: expected ',' or '}' in object")
        end
    end
end

function _parse_array!(p::_JSONParser)
    _expect!(p, '[')
    a = Any[]
    _skip_ws!(p)
    if _peek(p) == ']'
        _take!(p)
        return a
    end
    while true
        push!(a, _parse_value!(p))
        c = _peek(p)
        if c == ','
            _take!(p)
            continue
        elseif c == ']'
            _take!(p)
            return a
        else
            error("json_parse: expected ',' or ']' in array")
        end
    end
end

function _parse_string!(p::_JSONParser)
    _expect!(p, '"')
    io = IOBuffer()
    s = p.s
    while p.i <= lastindex(s)
        c = s[p.i]
        p.i = nextind(s, p.i)
        if c == '"'
            return String(take!(io))
        elseif c == '\\'
            p.i > lastindex(s) && error("json_parse: truncated escape")
            e = s[p.i]
            p.i = nextind(s, p.i)
            if e == '"' || e == '\\' || e == '/'
                print(io, e)
            elseif e == 'n'
                print(io, '\n')
            elseif e == 'r'
                print(io, '\r')
            elseif e == 't'
                print(io, '\t')
            elseif e == 'b'
                print(io, '\b')
            elseif e == 'f'
                print(io, '\f')
            elseif e == 'u'
                p.i + 3 > lastindex(s) && error("json_parse: truncated \\u escape")
                hex = s[p.i:(p.i + 3)]
                p.i = nextind(s, p.i + 3)
                print(io, Char(parse(UInt32, hex; base = 16)))
            else
                error("json_parse: unknown escape '\\$e'")
            end
        else
            print(io, c)
        end
    end
    error("json_parse: unterminated string")
end

function _parse_number!(p::_JSONParser)
    start = p.i
    s = p.s
    s[p.i] == '-' && (p.i = nextind(s, p.i))
    while p.i <= lastindex(s) && isdigit(s[p.i])
        p.i = nextind(s, p.i)
    end
    isfloat = false
    if p.i <= lastindex(s) && s[p.i] == '.'
        isfloat = true
        p.i = nextind(s, p.i)
        while p.i <= lastindex(s) && isdigit(s[p.i])
            p.i = nextind(s, p.i)
        end
    end
    if p.i <= lastindex(s) && (s[p.i] == 'e' || s[p.i] == 'E')
        isfloat = true
        p.i = nextind(s, p.i)
        if p.i <= lastindex(s) && (s[p.i] == '+' || s[p.i] == '-')
            p.i = nextind(s, p.i)
        end
        while p.i <= lastindex(s) && isdigit(s[p.i])
            p.i = nextind(s, p.i)
        end
    end
    tok = s[start:prevind(s, p.i)]
    isfloat && return parse(Float64, tok)
    try
        return parse(Int, tok)
    catch
        try
            return parse(Int128, tok)
        catch
            return parse(Float64, tok)
        end
    end
end

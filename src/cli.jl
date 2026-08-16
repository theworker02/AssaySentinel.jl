# Optional command-line interface. JSON output supported.

function main(args::Vector{String} = ARGS)
    isempty(args) && return _cli_help()
    cmd = args[1]
    rest = args[2:end]
    json_out = any(==("--json"), rest)
    rest = filter(!=("--json"), rest)
    if cmd in ("help", "-h", "--help")
        return _cli_help()
    elseif cmd == "version"
        println("AssaySentinel.jl ", PACKAGE_VERSION)
        return 0
    elseif cmd == "doctor"
        return _cli_doctor()
    elseif cmd == "simulate"
        return _cli_simulate(rest, json_out)
    elseif cmd in ("analyze", "drift", "batch", "reference", "compare", "report", "study")
        isempty(rest) && (println(stderr, "error: $cmd requires a CSV path"); return 2)
        return _cli_file(cmd, rest[1], rest[2:end], json_out)
    else
        println(stderr, "unknown command: ", cmd)
        _cli_help()
        return 2
    end
end

function _cli_help()
    println("""
    assaysentinel — analytical quality intelligence for Julia

    Usage:
      assaysentinel analyze measurements.csv [--json]
      assaysentinel drift measurements.csv [--json]
      assaysentinel batch measurements.csv [--json]
      assaysentinel reference measurements.csv [--json]
      assaysentinel compare lots.csv [--json]
      assaysentinel report measurements.csv [out.md]
      assaysentinel study measurements.csv [--json]
      assaysentinel simulate [--json]
      assaysentinel doctor
      assaysentinel version

    $(SAFETY_NOTICE)
    """)
    0
end

function _cli_doctor()
    println("AssaySentinel.jl ", PACKAGE_VERSION)
    println("Julia ", VERSION)
    println("threads ", Threads.nthreads())
    println("safety ", strip(SAFETY_NOTICE))
    println(
        "optional Makie / Unitful / Measurements / Turing / OnlineStats: weak dependencies (load to enable extensions)",
    )
    0
end

function _cli_simulate(rest, json_out)
    n = 400
    for a in rest
        if startswith(a, "--n=")
            n = parse(Int, a[5:end])
        end
    end
    sim = simulate_assay(; n, drift = :step, rng = Random.Xoshiro(1))
    r = analyze(sim.stream; rng = Random.Xoshiro(1))
    if json_out
        print(stdout, json_string(report_dict(r)))
        println()
    else
        println(r)
    end
    0
end

function _cli_file(cmd, path, rest, json_out)
    isfile(path) || (println(stderr, "error: file not found: ", path); return 2)
    table = _read_csv(path)
    if cmd == "reference"
        col = _first_numeric(table)
        ri = reference_interval(col; rng = Random.Xoshiro(1))
        json_out ?
        print(
            stdout,
            json_string(
                Dict("lower" => ri.lower, "upper" => ri.upper,
                    "method" => string(ri.method), "n" => ri.n),
            ),
        ) :
        println("RI ", ri.lower, " – ", ri.upper, " (", ri.method, ", n=", ri.n, ")")
        println()
        return 0
    elseif cmd == "batch"
        be = detect_batch_effects(table; batch = :batch, value = _value_col(table))
        json_out ?
        print(
            stdout,
            json_string(
                Dict("detected" => be.detected, "p" => be.batch_pvalue,
                    "interpretation" => be.interpretation),
            ),
        ) :
        println(be.interpretation)
        println()
        return 0
    elseif cmd == "compare"
        lotcol = hasproperty(first(table), :lot) ? :lot : :reagent_lot
        cmp = compare_lots(table, lotcol; value = _value_col(table))
        json_out ?
        print(stdout, json_string(Dict("lots" => cmp.lots, "evidence" => cmp.evidence))) :
        foreach(println, cmp.evidence)
        println()
        return 0
    elseif cmd == "study"
        sitecol = _optional_col(table, (:site, :lab, :laboratory))
        sitecol === nothing &&
            (println(stderr, "error: study CSV needs a site column"); return 2)
        streams = Dict{String, AssayStream}()
        sites = Site[]
        for r in table
            s = string(getproperty(r, sitecol))
            haskey(streams, s) && continue
            sub = [row for row in table if string(getproperty(row, sitecol)) == s]
            streams[s] = from_table(sub; analyte = :analyte, unit = "",
                value = _value_col(table),
                time = _time_col(table),
                lot = _optional_col(table, (:reagent_lot, :lot)),
                instrument = _optional_col(table, (:instrument,)),
                batch = _optional_col(table, (:batch,)),
                control = _optional_col(table, (:control,)))
            streams[s].site = s
            push!(sites, Site(s))
        end
        study = Study("cli-study"; sites)
        report_ = analyze(study, streams; rng = Random.Xoshiro(1))
        json_out ?
        print(stdout, json_string(study_report_dict(report_))) :
        (println(report_); println(); println(explain(report_)))
        println()
        return 0
    end
    stream = from_table(table; analyte = :analyte, unit = "",
        value = _value_col(table),
        time = _time_col(table),
        lot = _optional_col(table, (:reagent_lot, :lot)),
        instrument = _optional_col(table, (:instrument,)),
        batch = _optional_col(table, (:batch,)),
        control = _optional_col(table, (:control,)))
    if cmd == "drift"
        r = detect_drift([m.value for m in stream.measurements];
            timestamps = [m.timestamp for m in stream.measurements])
        json_out ?
        print(
            stdout,
            json_string(
                Dict("detected" => r.detected, "kind" => string(r.kind),
                    "probability" => r.probability),
            ),
        ) : println(explain(r))
        println()
        return 0
    end
    report_ = analyze(stream; rng = Random.Xoshiro(1))
    if cmd == "report"
        out = isempty(rest) ? replace(path, r"\.[^.]+$" => "") * ".md" : rest[1]
        save(report_, out)
        println("wrote ", out)
        return 0
    end
    if json_out
        print(stdout, json_string(report_dict(report_)))
        println()
    else
        println(report_)
        println()
        println(explain(report_))
    end
    0
end

function _read_csv(path::AbstractString)
    rows = NamedTuple[]
    open(path) do io
        header = strip.(split(readline(io), ','))
        names = Tuple(Symbol.(header))
        for line in eachline(io)
            isempty(strip(line)) && continue
            parts = split(line, ',')
            vals = Any[_parse_cell(p) for p in parts]
            length(vals) < length(names) &&
                append!(vals, fill(nothing, length(names) - length(vals)))
            push!(rows, NamedTuple{names}(Tuple(vals[1:length(names)])))
        end
    end
    rows
end

function _parse_cell(s)
    t = strip(s)
    t == "" && return nothing
    try
        return parse(Float64, t)
    catch
    end
    try
        return DateTime(t)
    catch
    end
    try
        return DateTime(t, dateformat"yyyy-mm-dd HH:MM:SS")
    catch
    end
    try
        return DateTime(t, dateformat"yyyy-mm-dd")
    catch
    end
    lowercase(t) in ("true", "false") && return lowercase(t) == "true"
    t
end

function _value_col(table)
    row = first(table)
    for c in (:value, :result, :measurement, :y)
        hasproperty(row, c) && return c
    end
    for n in propertynames(row)
        getproperty(row, n) isa Number && return n
    end
    :value
end

function _time_col(table)
    row = first(table)
    for c in (:timestamp, :time, :datetime, :date)
        hasproperty(row, c) && return c
    end
    :timestamp
end

function _optional_col(table, names)
    row = first(table)
    for c in names
        hasproperty(row, c) && return c
    end
    nothing
end

function _first_numeric(table)
    vals = Float64[]
    col = _value_col(table)
    for r in table
        v = getproperty(r, col)
        v isa Number && isfinite(Float64(v)) && push!(vals, Float64(v))
    end
    vals
end

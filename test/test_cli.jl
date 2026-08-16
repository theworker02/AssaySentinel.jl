@testset "CLI" begin
    @test AssaySentinel.main(["version"]) == 0
    @test AssaySentinel.main(["help"]) == 0
    @test AssaySentinel.main(["doctor"]) == 0
    @test AssaySentinel.main(["simulate", "--n=80"]) == 0
    @test AssaySentinel.main(["nope"]) == 2
    mktempdir() do dir
        csv = joinpath(dir, "sites.csv")
        open(csv, "w") do io
            println(io, "timestamp,value,site")
            t0 = DateTime(2026, 1, 1)
            for (lab, μ) in (("A", 100.0), ("B", 104.0))
                for i in 1:16
                    println(io, t0 + Hour(i), ",", μ, ",", lab)
                end
            end
        end
        @test AssaySentinel.main(["study", csv]) == 0
        @test AssaySentinel.main(["study", csv, "--json"]) == 0
        empty = joinpath(dir, "empty.csv")
        write(empty, "timestamp,value,site\n")
        @test AssaySentinel.main(["study", empty]) == 2
        panelcsv = joinpath(dir, "panel.csv")
        open(panelcsv, "w") do io
            println(io, "timestamp,value,analyte")
            t0 = DateTime(2026, 1, 1)
            for (a, μ) in (("glucose", 100.0), ("sodium", 140.0))
                for i in 1:12
                    println(io, t0 + Hour(i), ",", μ, ",", a)
                end
            end
        end
        @test AssaySentinel.main(["panel", panelcsv]) == 0
        @test AssaySentinel.main(["panel", panelcsv, "--json"]) == 0
        @test AssaySentinel.main(["analyze", csv]) == 0
    end
end

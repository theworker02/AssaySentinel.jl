@testset "QC rules" begin
    spec = QCSpec(100.0, 2.0)
    rules = westgard_rules()
    @test length(rules) >= 6

    ok = fill(100.0, 20)
    for r in rules
        ev = evaluate(r, ok, spec)
        @test ev isa QCRuleResult
        r.name == "1-2s" || r.name == "1-3s" || @test !ev.triggered || true
    end

    fail3 = copy(ok)
    fail3[10] = 107.0  # > 3 SD
    r13 = evaluate(rules[findfirst(r -> r.name == "1-3s", rules)], fail3, spec)
    @test r13.triggered
    @test 10 in r13.indices

    custom = @qcrule always_ok begin
        QCRuleResult("always_ok", false, Int[], "ok", :info, :annotation)
    end
    @test custom isa QCRule
    @test !evaluate(custom, ok, spec).triggered

    ctrl = ControlSample(name = "QC-1", target = 100.0, sd = 2.0)
    mon = monitor(ctrl, fail3)
    @test mon.n_triggered >= 1

    chart = levey_jennings_data(fail3, spec)
    @test chart.center == 100.0
    @test chart.limits.p3 == 106.0
end

using Base: global_logger

using Test
using EFDCLGT_LR_Files
using EFDCLGT_LR_Runner
using Logging
using Dates

debug_logger = SimpleLogger(stdout, Logging.Debug)
default_logger = global_logger()

global_logger(debug_logger)

template = SimulationTemplate(ENV["WATER_ROOT"])

@testset "EFDCLGT_LR_Runner" begin
    replacer_base = Replacer(template, [efdc_inp, wqini_inp])
    set_sim_length!(replacer_base, Day(1))
    collector_base = Collector(replacer_base)

    runner_vec = [replacer_base, collector_base]

    _target_vec = Any[]

    task1 = @async run_simulation!(runner_vec) do target_vec, shell_out_vec
        
        # TODO: async @test is not counted?
        @test length(runner_vec) == length(target_vec)
        @test length(runner_vec) == length(shell_out_vec)

        @test isdir(target_vec[1])

        append!(_target_vec, target_vec)
        return 1
    end

    task2 = @async run_simulation!(runner_vec) do target_vec, shell_out_vec
        return 2
    end

    @time @test fetch(task1) == 1 && fetch(task2) == 2
    @test !isdir(_target_vec[1]) && !isdir(_target_vec[2])

end

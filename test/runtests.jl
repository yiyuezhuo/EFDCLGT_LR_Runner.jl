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
    replacer = Replacer(template, [efdc_inp, wqini_inp])
    set_sim_length!(replacer, Day(1))
    restarter = Restarter(replacer)
    collector1 = Collector(replacer)
    collector2 = Collector(restarter)

    @testset "batch_processing" begin

        dir_completed_vec = String[]

        # It seems that the following code charges more virtual memory significantly more than the commented code.
        runner_vec1 = [replacer, restarter]
        runner_vec2 = [collector1, collector2]
        
        task1 = @async run_simulation!(runner_vec1) do res_vec
            @test length(runner_vec1) == length(res_vec)
            for res in res_vec
                @test isdir(res.dir_completed)
                push!(dir_completed_vec, res.dir_completed)
            end

            return 1
        end

        task2 = @async run_simulation!(runner_vec1) do res_vec
            return 2
        end

        @time @test fetch(task1) == 1 && fetch(task2) == 2
        
        #=
        runner_vec = [replacer, restarter, collector1, collector2]
        # runner_vec = [replacer, restarter, collector1, collector2, collector1, collector2]

        run_simulation!(runner_vec) do res_vec
            # TODO: async @test is not counted?
            @test length(runner_vec) == length(res_vec)
            for res in res_vec
                @test isdir(res.dir_completed)
                push!(dir_completed_vec, res.dir_completed)
            end
        end
        =#

        @test !isdir(dir_completed_vec[1]) && !isdir(dir_completed_vec[2])
    end

    @testset "auto_step" begin

        collector = Collector{Restarter}(Collector(replacer))

        @test isempty(collector.stats_running)

        collector2 = Collector{Restarter}(collector)

        @test !isempty(collector.stats_running)
        @test isempty(collector2.stats_running)
    end
end

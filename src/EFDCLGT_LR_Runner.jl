module EFDCLGT_LR_Runner

using Base: Float64, String, create_expr_cache

export run_simulation!, Collector

using EFDCLGT_LR_Files
using EFDCLGT_LR_Files: Runner, RunnerFunc, RunnerStateful, AbstractFile, name
import EFDCLGT_LR_Files: create_simulation, parent

include("runner.jl")
include("collector.jl")
include("batch_processing.jl")

# greet() = print("Hello World!")

end # module

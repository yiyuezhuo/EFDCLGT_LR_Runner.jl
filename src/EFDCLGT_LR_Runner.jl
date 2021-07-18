module EFDCLGT_LR_Runner

using Base: Float64, String, create_expr_cache

export run_simulation!, Collector, cleanup, default_async_throttle_ref

using EFDCLGT_LR_Files
using EFDCLGT_LR_Files: RunnerFunc, RunnerStateful, name
import EFDCLGT_LR_Files: create_simulation, parent, Restarter, Replacer, master_map

import ProgressMeter

include("progress_async.jl")
include("async_throttle.jl")
include("runner.jl")
include("collector.jl")
include("batch_processing.jl")
include("auto_step.jl")

function __init__()
    default_async_throttle_ref[] = AsyncThrottle()
end

# greet() = print("Hello World!")

end # module

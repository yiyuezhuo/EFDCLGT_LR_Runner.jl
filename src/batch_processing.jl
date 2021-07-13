


function run_simulation!(runner_vec::AbstractVector{<:Runner};
                        ntasks=min(length(Sys.cpu_info()) ÷ 2, length(runner_vec)),
                        progress=false)
    # It's expected that some parsing errors, which denote model running failure, will be raised.
    # length(Sys.cpu_info) ÷ 2 assumes 2x hyper thread to leverage all the physic CPU cores.
    if !progress
        return asyncmap(run_simulation!, runner_vec, ntasks=ntasks)
    end
    prog = ProgressAsync(length(runner_vec))
    return asyncmap(runner_vec, ntasks=ntasks) do runner
        ret = run_simulation!(runner)
        step!(prog)
        return ret
    end
end

function run_simulation!(func::Function, runner_vec::AbstractVector{<:Runner}; progress=false, kwargs...)
    res_vec = run_simulation!(runner_vec; progress=progress, kwargs...)
    ret = func(res_vec)
    for res in res_vec # TODO: add a @async here?
        cleanup(res)
    end
    return ret
end

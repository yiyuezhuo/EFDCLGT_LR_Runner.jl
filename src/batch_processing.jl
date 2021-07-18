
function _run_with_progress(runner, prog)
    ret = run_simulation!(runner)
    step!(prog)
    return ret
end

function run_simulation!(runner_vec::AbstractVector{<:Runner}; progress=false)
    if !progress
        task_vec = map(runner_vec) do runner
            @async run_simulation!(runner)
        end
    else
        prog = ProgressAsync(length(runner_vec))
        task_vec = map(runner_vec) do runner
            @async _run_with_progress(runner, prog)
        end
    end
    return fetch.(task_vec)
end

function run_simulation!(func::Function, runner_vec::AbstractVector{<:Runner}; progress=false, kwargs...)
    res_vec = run_simulation!(runner_vec; progress=progress, kwargs...)
    ret = func(res_vec)
    for res in res_vec # TODO: add a @async here?
        cleanup(res)
    end
    return ret
end

#=
function run_simulation!(runner_vec::AbstractVector{<:Runner};
                        ntasks=min(get_default_ntasks(), length(runner_vec)),
                        progress=false)
    # It's expected that some parsing errors, which denote model running failure, will be raised.
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
=#

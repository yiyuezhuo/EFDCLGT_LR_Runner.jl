
function get_default_ntasks()
    # length(Sys.cpu_info) ÷ 2 assumes 2x hyper thread to leverage all the physic CPU cores.
    if "WATER_WORKERS" in keys(ENV)
        return parse(Int, ENV["WATER_WORKERS"])
    else
        return length(Sys.cpu_info()) ÷ 2
    end
end


"""
Limit current running tasks to prevent performance degradation.

"Low level" usage:

task_vec = map(collector_vec) do collector 
    task = @task run_simulation(collector)
    schedule(at, task)
    return task
end
map(fetch, task_vec)

Reference:
https://github.com/JuliaLang/julia/blob/master/base/asyncmap.jl#L262
"""
struct AsyncThrottle
    channel::Channel
    worker_vec::Vector{Task}
    idle_vec::Vector{Bool}
end

function Base.show(io::IO, at::AsyncThrottle)
    print(io, "AsyncThrottle(ch_isempty->$(isempty(at.channel)), ch_isopen->$(isopen(at.channel)),"*
            " ch_isready->$(isready(at.channel)), worker_size->$(length(at.worker_vec)), idle_vec=$(at.idle_vec))")
end

function async_throttle_worker(channel::Channel, idle_vec::Vector{Bool}, idx::Int)
    idle_vec[idx] = true
    @debug "throttle: worker $idx started"
    while true
        task = take!(channel)
        schedule(task)
        idle_vec[idx] = false
        @debug "throttle: worker $idx running"
        wait(task)
        @debug "throttle: worker $idx got result"
        idle_vec[idx] = true
    end
end

function AsyncThrottle(ntasks::Int=get_default_ntasks())
    channel = Channel(Inf)
    idle_vec = Vector{Bool}(undef, ntasks)
    worker_vec = map(1:ntasks) do idx
        @async async_throttle_worker(channel, idle_vec, idx)
    end
    return AsyncThrottle(channel, worker_vec, idle_vec)
end

function reset_workers!(at::AsyncThrottle, ntasks::Int)
    empty!(at.worker_vec)
    empty!(at.idle_vec)

    idle_vec = Vector{Bool}(undef, ntasks)
    worker_vec = map(1:ntasks) do i
        @async async_throttle_worker(channel, idle_vec, idx)
    end

    append!(at.worker_vec, worker_vec)
    append!(at.idle_vec, idle_vec)
end

function Base.schedule(at::AsyncThrottle, task::Task)
    put!(at.channel, task)
end

const default_async_throttle_ref = Ref{AsyncThrottle}()

#=
struct ASYNC end

Base.broadcastable(async_trait::ASYNC) = Ref(async_trait)

function run_simulation!(::ASYNC, args...; kwargs...)
    return run_simulation!(default_async_throttle, args...; kwargs...)
end

function run_simulation!(at::AsyncThrottle, runner::Runner)
    task = @task run_simulation!(runner)
    schedule(at, task)
    return task
end

function run_simulation!(at::AsyncThrottle, runner_vec::AbstractVector{<:Runner})
    task_vec = run_simulation!.(at, runner_vec)
    return @async map(fetch, task_vec)
end
=#

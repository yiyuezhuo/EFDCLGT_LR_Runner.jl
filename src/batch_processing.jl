
function worker(worker_idx, ch_in, ch_out)
    # @debug "worker $worker_idx: started"
    for (runner_idx, arg) in ch_in
        # @debug "worker $worker_idx: start to process job $runner_idx $arg"
        try
            res = run_simulation!(arg...)
            put!(ch_out, (worker_idx, runner_idx, nothing, res))
            break
        catch err
            @debug "worker $worker_idx: try to put err $err"
            put!(ch_out, (worker_idx, runner_idx, err, nothing))
            # @debug "worker $worker_idx: put err $err"
            rethrow(err)
        end
    end
end

function run_simulation!(runner_vec::AbstractVector{T}, 
                target_vec::AbstractVector{String}=[tempname() for _ in 1:length(runner_vec)];
                batch_size=min(length(Sys.cpu_info()) ÷ 2, length(runner_vec))) where T
    # It's expected that some parsing errors, which denote model running failure, will be raised.
    # length(Sys.cpu_info) ÷ 2 assumes 2x hyper thread to leverage all the physic CPU cores.

    ch_in = Channel{Tuple{Int, Tuple{T, String}}}()
    ch_out = Channel{Tuple{Int, Int, Union{Nothing, Exception}, Union{Nothing, SimulationResult}}}()

    @debug "Batch processing: jobs->$(length(runner_vec)), batch_size=$batch_size"

    @async for (runner_idx, arg) in enumerate(zip(runner_vec, target_vec))
        # @debug "Try to put job $runner_idx"
        put!(ch_in, (runner_idx, arg))
        # @debug "Put job $runner_idx"
    end
    # TODO: close ch_in?

    task_vec = Task[]

    for worker_idx in 1:batch_size
        push!(task_vec, @async worker(worker_idx, ch_in, ch_out))
    end

    n = length(runner_vec)

    # target_vec = Vector{Tuple{String, String}}(undef, n)
    res_vec = Vector{SimulationResult}(undef, n)

    # @debug "Batch_processing: yield to collect."

    for (solved_idx, (worker_idx, runner_idx, err, res)) in enumerate(Iterators.take(ch_out, n))
        if !isnothing(err)
            throw(err)
        end
        @debug "Solved worker: $worker_idx, job: $runner_idx, $solved_idx/$n"
        res_vec[runner_idx] = res
    end

    # TODO: close ch_out?

    return res_vec
end

function run_simulation!(func::Function, runner_vec::AbstractVector{<:Runner}; kwargs...)
    res_vec = run_simulation!(runner_vec)
    ret = func(res_vec)
    for res in res_vec
        rm(res.dir_completed, recursive=true)
    end
    return ret
end

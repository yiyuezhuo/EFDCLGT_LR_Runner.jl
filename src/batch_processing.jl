
function worker(worker_idx, ch_in, ch_out, max_quota)
    for (runner_idx, arg) in ch_in
        for quota in max_quota:-1:0
            try
                @debug runner_idx arg
                out = run_simulation!(arg...)
                put!(ch_out, (worker_idx, runner_idx, nothing, out))
                break
            catch err
                @debug err
                if err isa ModelRunningFailed
                    @warn "Potential fixable ModelRunningFailed: worker: $worker_idx, ruuner: $runner_idx, quota: $quota/$max_quota."
                    if used_quota > 0
                        continue
                    end
                end
                put!(ch_out, (worker_idx, runner_idx, err, nothing))
                rethrow(err)
            end
        end
    end
end

function run_simulation!(runner_vec::AbstractVector{T}, 
                target_vec::AbstractVector{String}=[tempname() for _ in 1:length(runner_vec)];
                batch_size=min(length(Sys.cpu_info()) ÷ 2, length(runner_vec)),
                max_quota=2) where T
    # It's expected that some parsing errors, which denote model running failure, will be raised.
    # length(Sys.cpu_info) ÷ 2 assumes 2x hyper thread to leverage all the physic CPU cores.

    ch_in = Channel{Tuple{Int, Tuple{T, String}}}()
    ch_out = Channel{Tuple{Int, Int, Union{Nothing, Exception}, Tuple{String, String}}}()

    @debug "Batch processing: job->$(length(runner_vec)), batch_size=$batch_size, max_quota=$max_quota"

    @async for (runner_idx, arg) in enumerate(zip(runner_vec, target_vec))
        put!(ch_in, (runner_idx, arg))
    end
    # TODO: close ch_in?

    for worker_idx in 1:batch_size
        @async worker(worker_idx, ch_in, ch_out, max_quota)
    end

    n = length(runner_vec)

    # target_vec = Vector{Tuple{String, String}}(undef, n)
    shell_out_vec = Vector{String}(undef, n)

    for (solved_idx, (worker_idx, runner_idx, err, (_, shell_out))) in enumerate(Iterators.take(ch_out, n))
        if !isnothing(err)
            rethrow(err)
        end
        @debug "Solved $worker_idx $runner_idx, $solved_idx/$n"
        shell_out_vec[runner_idx] = shell_out
    end

    # TODO: close ch_out?

    return target_vec, shell_out_vec
end

function run_simulation!(func::Function, runner_vec::AbstractVector{<:Runner}; kwargs...)
    target_vec, shell_out_vec = run_simulation!(runner_vec)
    ret = func(target_vec, shell_out_vec)
    for target in target_vec
        rm(target, recursive=true)
    end
    return ret
end


function worker(worker_idx, ch_in, ch_out, max_quota)
    for (runner_idx, arg) in ch_in
        for quota in max_quota:-1:0
            try
                out = run_simulation!(arg...)
                break
            catch err
                if err isa ModelRunningFailed
                    @warn "Potential fixable ModelRunningFailed: worker: $worker_idx, ruuner: $runner_idx, quota: $quota/$max_quota."
                    if used_quota == 0
                        rethrow(err)
                    end
                else
                    rethrow(err)
                end
            end
        end
        put!(ch_out, (runner_idx, out))
    end
end

function run_simulation!(runner_vec::AbstractVector{T}, 
                target_vec::AbstractVector{String}=[tempdir() for _ in 1:length(runner_vec)];
                batch_size=min(length(Sys.cpu_info) ÷ 2, length(runner_vec)),
                max_quota=2) where T
    # It's expected that some parsing errors, which denote model running failure, will be raised.
    # length(Sys.cpu_info) ÷ 2 assumes 2x hyper thread to leverage all the physic CPU cores.

    ch_in = Channel{Tuple{Int, Tuple{T, String}}}()
    ch_out = Channel{Tuple{Int, Tuple{String, String}}}()
    for (runner_idx, arg) in enumerate(zip(runner_vec, target_vec))
        put!(ch_in, (runner_idx, arg))
    end

    for worker_idx in 1:batch_size
        @async worker(worker_idx, ch_in, ch_out, max_quota)
    end

    n = length(runner_vec)
    out_vec = Vector{Tuple{String, String}}(undef, n)

    for (runner_idx, out) in Iterators.take(ch_out, n)
        out_vec[runner_idx] = out
    end

    return out_vec
end
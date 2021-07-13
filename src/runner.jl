
const MAX_QUOTA=2
const shell_end_anchor = "TIMING INFORMATION IN SECONDS"

struct ModelRunningFailed
    msg::String
end

Base.showerror(io::IO, e::ModelRunningFailed) = print(io, "Model running seems failed:", e.msg, "!")

function parse_shell_output(full_output::String)
    slice = findfirst(shell_end_anchor, full_output)
    if isnothing(slice)
        throw(ModelRunningFailed(full_output[end-300:end]))
    end

    word_list = split(full_output[slice[end] + 1:end])
    rd = Dict{String, Float64}()
    stack = String[]
    it = Iterators.Stateful(word_list)

    for word in it
        if word == "="
            key = join(stack, " ")
            empty!(stack)
            value = popfirst!(it)
            rd[key] = Meta.parse(value)
        else
            push!(stack, word)
        end
    end
    return rd
end

"""
Simulation result except the "useful part", which is collected by Collector.
"""
struct SimulationResult
    dir_completed::String
    output::String
    stats_running::Dict{String, Float64}
end

function cleanup(r::SimulationResult)
    rm(r.dir_completed, recursive=true)
end

function Base.show(io::IO, sr::SimulationResult)
    elapsed_time = sr.stats_running["ELLAPSED TIME"] # the original program wrongly spelled the word.
    print(io, "SimulationResult(dir_completed=$(sr.dir_completed), length(output)=$(length(sr.output)), length(stats_running)=$(length(sr.stats_running)), elapsed_time->$elapsed_time)")
end

"""
Run without creating environment.

As the model executable may charge a lot of virtual memory (in my case, 30Mb physic memory vs 1.8Gb virtual memory),
there're three possible result:

* The program even failed to start as virtual memory is not enough, at this time, you can't even run the executable manually.
* The program started but for some reason failed to read input files, then it is catched by ModelRunningFailed. The function will try to restart it until MAX_QUOTA is reached. 
* The program started and exited with "regular" output, so the disk files it leaves and shell output is valid and can be fetched.
"""
function _run_simulation!(template::AbstractSimulationTemplate, target)
    exe_p = get_exe_path(template)
    cmd = setenv(`$exe_p`, dir=target)
    @debug "Run $cmd"
    for quota in MAX_QUOTA:-1:0
        try
            output = read(cmd, String)
            stats_running = parse_shell_output(output)
            return SimulationResult(target, output, stats_running)
        catch err
            @debug "Simulation failed: $err"
            if err isa ModelRunningFailed
                @warn "Potential fixable ModelRunningFailed: quota: $quota/$MAX_QUOTA."
                if quota > 0
                    continue
                end
            end
            rethrow(err)
        end
    end
end

_run_simulation!(replacer::Replacer, target) = _run_simulation!(replacer.template, target)
_run_simulation!(restarter::Restarter, target) = _run_simulation!(restarter.replacer, target)

# run_simulation(runner::RunnerFunc, target) = run_simulation!(runner, target)

"""
Create a new environment and run simulation, return a SimulationResult.
Results on disk may be loaded into runner's field.

target is expected to be "empty", and a environment will be created in it. 
To run simulation only, refer to `_run_simulation!`. As the `_` shows, 
this way is not recommended as it will not save the resumable state. 
"""
function run_simulation!(runner::Runner, target=tempname())
    create_simulation(runner, target)
    return _run_simulation!(runner, target)
end


function run_simulation!(func::Function, runner::Runner)
    res = run_simulation!(runner)
    ret = func(res)
    cleanup(res)
    return ret
end



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

"""
Run without creating environment
"""
function _run_simulation!(template::SimulationTemplate, target)
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
Create a new environment and run simulation, return created dir and shell_output.
Results on disk may be loaded into runner's field.
"""
function run_simulation!(runner::Runner, target=tempname())
    create_simulation(runner, target)
    return _run_simulation!(runner, target)
end


function run_simulation!(func::Function, runner::Runner)
    target, shell_output = run_simulation!(runner)
    ret = func(target, shell_output)
    rm(target, recursive=true)
    return ret
end


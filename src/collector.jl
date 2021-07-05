
abstract type RunnerMutable <: RunnerStateful end

struct Collector{T, T_collect_vec<:Vector{<:Type}} <: RunnerMutable
    runner::T # SimulationTemplate, Replacer or Restarter
    collect_vec::T_collect_vec
    result_map::Dict{Type, AbstractFile}
    stats_running::Dict{String, Float64}
end

function Collector(runner::Runner, collect_vec::Vector{<:Type})
    result_map = Dict{Type, AbstractFile}()
    stats_running = Dict{String, Float64}()
    return Collector(runner, collect_vec, result_map, stats_running)
end

Collector(runner::Runner) = Collector(runner, Type[]) # This can be used to verify context logic.

create_simulation(collector::Collector, target=tempname()) = create_simulation(collector.runner, target)
_run_simulation!(collector::Collector, target=tempname()) = _run_simulation!(collector.runner, target)

const shell_end_anchor = "TIMING INFORMATION IN SECONDS"

struct ModelRunningFailed
    msg::String
end

Base.showerror(io::IO, e::ModelRunningFailed) = print(io, "Model running seems failed:", e.msg, "!")

function parse_shell_output(full_output::String)
    slice = findfirst(shell_end_anchor, full_output)
    if isnothing(slice)
        raise(ModelRunningFailed(full_output))
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


function run_simulation!(collector::Collector, target=tempname())
    _, shell_output = run_simulation!(collector.runner, target)
    stats_running = parse_shell_output(shell_output) # this may raise error
    merge!(collector.stats_running, stats_running)
    for ftype in collector.collect_vec
        p = joinpath(target, name(ftype))
        collector.result_map[ftype] = load(p, ftype)
    end
    return target, shell_output
end

function Base.show(io::IO, c::Collector)
    base_str_vec = [
        "runner=$(c.runner)",
        "collect_vec=$(c.collect_vec)",
        "has_result_map->$(!isempty(c.result_map))",
        "has_stats_running->$(!isempty(c.stats_running))"
    ]
    base_str = join(base_str_vec, ", ")
    print(io, "Collector($base_str)")
end
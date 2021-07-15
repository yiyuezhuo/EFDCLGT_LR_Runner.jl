
abstract type RunnerMutable <: RunnerStateful end

struct Collector{T, T_collect_vec<:Vector{<:Type}} <: RunnerMutable
    runner::T # SimulationTemplate, Replacer or Restarter
    collect_vec::T_collect_vec
    _result_map::Dict{Type, AbstractFile}
    stats_running::Dict{String, Float64}
end

function Collector(runner::Runner, collect_vec::Vector{<:Type})
    _result_map = Dict{Type, AbstractFile}()
    stats_running = Dict{String, Float64}()
    return Collector(runner, collect_vec, _result_map, stats_running)
end

master_map(c::Collector) = c._result_map

Collector(runner::Runner) = Collector(runner, Type[]) # This can be used to verify context logic.

parent(c::Collector) = c.runner

is_over(c::Collector) = !isempty(c.stats_running)

create_simulation(collector::Collector, target=efdc_lp_tempname()) = create_simulation(collector.runner, target)
_run_simulation!(collector::Collector, target=efdc_lp_tempname()) = _run_simulation!(collector.runner, target)

function run_simulation!(collector::Collector, target=efdc_lp_tempname())
    res = run_simulation!(collector.runner, target)
    merge!(collector.stats_running, res.stats_running)
    for ftype in collector.collect_vec
        p = joinpath(target, name(ftype))
        collector[ftype] = load(p, ftype)
    end
    return res
end

function Base.show(io::IO, c::Collector)
    base_str_vec = [
        "runner=$(c.runner)",
        "collect_vec=$(c.collect_vec)",
        "has_result->$(!isempty(c._result_map))",
        "has_stats_running->$(!isempty(c.stats_running))"
    ]
    base_str = join(base_str_vec, ", ")
    print(io, "Collector($base_str)")
end

function Base.copy(c::Collector)
    @assert isempty(c.stats_running)
    Collector(copy(c.runner), copy(c.collect_vec))
end


"""
This construtor will run a simulation, fetch the output and set nesscery state to match a restarting.
"""
function Restarter(replacer::Replacer)
    res = run_simulation!(replacer)
    replacer_backbone = add_begin_day!(set_restarting!(copy(replacer), true))
    return Restarter(replacer_backbone, res.dir_completed)
end

function Restarter(restarter::Restarter)
    res = run_simulation!(restarter)
    replacer_backbone = add_begin_day!(copy(restarter.replacer))
    return Restarter(replacer_backbone, dir_completed)
end

function Collector{Restarter}(collector::Collector{<:Union{Replacer, Restarter}})
    @assert isempty(collector.stats_running)

    res = run_simulation!(collector)
    replacer_backbone = set_restarting!(copy_replacer(collector), true) |> add_begin_day!
    restarter = Restarter(replacer_backbone, res.dir_completed)

    return Collector(restarter, collector.collect_vec)
end

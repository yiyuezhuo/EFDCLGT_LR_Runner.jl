
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
    return Restarter(replacer_backbone, res.dir_completed)
end

function Collector{Restarter}(collector::Collector{<:Union{Replacer, Restarter}})
    @assert !is_over(collector)

    res = run_simulation!(collector)
    replacer_backbone = set_restarting!(copy_replacer(collector), true) |> add_begin_day!
    restarter = Restarter(replacer_backbone, res.dir_completed)

    return Collector(restarter, collector.collect_vec)
end

# function Base.broadcasted(::typeof(Collector{Restarter}), collector_vec::Vector{<:Collector{<:Union{Replacer, Restarter}}})
function Collector{Restarter}(collector_vec::Vector{<:Collector})
    # TODO: How can we override "constructor.()"?
    # https://discourse.julialang.org/t/custom-broadcasting-for-constructors/64574
    # ugly hack

    @assert !any(is_over.(collector_vec))

    res_vec = run_simulation!(collector_vec)
    replacer_backbone_vec = set_restarting!.(copy_replacer.(collector_vec), true) .|> add_begin_day!
    restarter_vec = Restarter.(replacer_backbone_vec, getfield.(res_vec, :dir_completed))

    return Collector.(restarter_vec, getfield.(collector_vec, :collect_vec))
end

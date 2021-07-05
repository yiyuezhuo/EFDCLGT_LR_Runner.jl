

"""
Run without creating environment
"""
function _run_simulation!(template::SimulationTemplate, target)
    exe_p = get_exe_path(template)
    cmd = setenv(`$exe_p`, dir=target)
    @debug "Run $cmd"
    return target, read(cmd, String)
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


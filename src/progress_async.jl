
struct ProgressAsync
    prog::ProgressMeter.Progress
    ch::Channel{Nothing}
    task::Task
end

function ProgressAsync(num::Int)
    prog = ProgressMeter.Progress(num)
    ch = Channel{Nothing}(Inf)
    task = @async begin
        for _ in ch
            ProgressMeter.next!(prog)
        end
        ProgressMeter.finished!(prog)
    end
    return ProgressAsync(prog, ch, task)
end

function step!(prog::ProgressAsync)
    put!(prog.ch, nothing)
end

function finished!(prog::ProgressAsync)
    close(prog.ch)
end

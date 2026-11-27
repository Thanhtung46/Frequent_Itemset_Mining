# Run: julia --project=. applications/run_visual.jl [--minsup 0.12] [--words 16]
include("Chapter3.jl")
using .Chapter3

function main(args::Vector{String})
    opts = Chapter3.parse_kv_args(args, Dict(
        "--minsup" => "0.12", "--words" => "16", "--seed" => "42",
        "--algo" => "baseline", "--max-per-class" => "150"))
    run_visual_words(; minsup=parse(Float64, opts["--minsup"]),
                     words=parse(Int, opts["--words"]), seed=parse(Int, opts["--seed"]),
                     algo=Symbol(opts["--algo"]),
                     max_per_class=parse(Int, opts["--max-per-class"]))
end
if abspath(PROGRAM_FILE) == @__FILE__
    main(ARGS)
end

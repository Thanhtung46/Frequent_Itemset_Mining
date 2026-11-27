# Run: julia --project=. applications/run_market.jl [--minsup 0.01] [--minconf 0.15]
include("Chapter3.jl")
using .Chapter3

function main(args::Vector{String})
    opts = Chapter3.parse_kv_args(args, Dict(
        "--minsup" => "0.01", "--minconf" => "0.15", "--algo" => "baseline",
        "--csv" => joinpath(Chapter3.ROOT, "data", "chapter3", "groceries.csv")))
    algo = Symbol(opts["--algo"])
    run_market_basket(; csv_path=opts["--csv"], minsup=parse(Float64, opts["--minsup"]),
                      minconf=parse(Float64, opts["--minconf"]), algo=algo)
end
if abspath(PROGRAM_FILE) == @__FILE__
    main(ARGS)
end

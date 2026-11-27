"""
CLI chạy Ứng dụng 1 — Phân tích giỏ hàng (Market Basket Analysis).
Ví dụ:
    julia --project=. src/applications/run_market_basket.jl --minsup 0.01 --minconf 0.15
"""

include("applications.jl")
using .Applications: Applications, run_market_basket

function main(args::Vector{String})
    defaults = Dict(
        "--minsup" => "0.01",
        "--minconf" => "0.15",
        "--algo" => "baseline",
        "--csv" => joinpath(Applications.ROOT, "data", "chapter3", "groceries.csv"),
    )
    opts = Applications.parse_kv_args(args, defaults)
    return run_market_basket(;
        csv_path=opts["--csv"],
        minsup=parse(Float64, opts["--minsup"]),
        minconf=parse(Float64, opts["--minconf"]),
        algo=Symbol(opts["--algo"]),
    )
end

if abspath(PROGRAM_FILE) == @__FILE__
    main(ARGS)
end

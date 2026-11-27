"""
CLI chạy Ứng dụng 2 — Khai thác mẫu trực quan trên hình ảnh (Bag of Visual Words).
Ví dụ:
    julia --project=. src/applications/run_visual_words.jl --minsup 0.12 --words 16
"""

include("applications.jl")
using .Applications: Applications, run_visual_words

function main(args::Vector{String})
    defaults = Dict(
        "--minsup" => "0.12",
        "--words" => "16",
        "--seed" => "42",
        "--algo" => "baseline",
        "--max-per-class" => "150",
    )
    opts = Applications.parse_kv_args(args, defaults)
    return run_visual_words(;
        minsup=parse(Float64, opts["--minsup"]),
        words=parse(Int, opts["--words"]),
        seed=parse(Int, opts["--seed"]),
        algo=Symbol(opts["--algo"]),
        max_per_class=parse(Int, opts["--max-per-class"]),
    )
end

if abspath(PROGRAM_FILE) == @__FILE__
    main(ARGS)
end

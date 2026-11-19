"""
Entry-point dòng lệnh (CLI) cho thuật toán `negFIN`.
Ví dụ: `julia --project=. src/main.jl --input data.txt --output out.txt --minsup 0.05`
"""

include("utils.jl")
include("structures.jl")
include("negfin_baseline.jl")
include("negfin_optimized.jl")

# TODO (Phần 1 - Bậc 4): Xử lý tham số CLI (--input, --output, --minsup, --algo).

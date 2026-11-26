"""
File chạy chính cho toàn bộ bộ kiểm thử tự động:
`julia --project=. tests/runtests.jl`
"""

using Test: @testset

include("../src/utils.jl")
include("../src/structures.jl")
include("../src/algorithm/negfin_baseline.jl")
include("../src/algorithm/negfin_optimized.jl")

@testset "NegFIN Test Suite" begin
    include("test_correctness.jl")
    include("test_benchmark.jl")
end

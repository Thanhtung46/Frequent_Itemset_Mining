# Chapter 3: both applications use the team's original negFIN Julia implementation.
# No Python application code and no third-party FIM library.
module Chapter3

using Random
using Statistics
using Printf
using Downloads

const ROOT = normpath(joinpath(@__DIR__, ".."))

# Keep Chapters 1 and 2 unchanged. Import their source only; do not reimplement FIM.
include(joinpath(ROOT, "src", "utils.jl"))
include(joinpath(ROOT, "src", "structures.jl"))
include(joinpath(ROOT, "src", "algorithm", "negfin_baseline.jl"))
include(joinpath(ROOT, "src", "algorithm", "negfin_optimized.jl"))

include("common.jl")
include("market_basket.jl")
include("visual_words.jl")

export mine_itemsets, association_rules, encode_baskets, load_baskets,
       run_market_basket, read_digits, dense_descriptors, learn_codebook,
       visual_transactions, run_visual_words
end

"""
Module `Applications`: Tích hợp trực tiếp thuật toán `negFIN` tự viết của nhóm (Chương 1)
cho hai ứng dụng thực tế thuần Julia:
1. Phân tích giỏ hàng (Market Basket Analysis — `market_basket.jl`).
2. Khai thác mẫu trực quan trên hình ảnh (Bag of Visual Words — `visual_words.jl`).
"""
module Applications

using Downloads: download
using Printf: @printf, @sprintf
using Random: MersenneTwister, randperm, shuffle!
using Statistics: mean, std

const ROOT = normpath(joinpath(@__DIR__, "..", ".."))

# Nạp trực tiếp mã nguồn negFIN Chương 1 (không viết lại thuật toán FIM)
include(joinpath(ROOT, "src", "utils.jl"))
include(joinpath(ROOT, "src", "structures.jl"))
include(joinpath(ROOT, "src", "algorithm", "negfin_baseline.jl"))
include(joinpath(ROOT, "src", "algorithm", "negfin_optimized.jl"))

include("app_utils.jl")
include("market_basket.jl")
include("visual_words.jl")

export mine_itemsets,
    association_rules,
    encode_baskets,
    load_baskets,
    run_market_basket,
    read_digits,
    dense_descriptors,
    learn_codebook,
    visual_transactions,
    run_visual_words,
    print_top_rules_table,
    print_accuracy_table,
    print_enrichment_table

end

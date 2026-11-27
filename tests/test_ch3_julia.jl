# Independent tests for Chapter 3 (without external datasets or Python).
# Run: julia --project=. tests/test_ch3_julia.jl
using Test
include(joinpath(@__DIR__, "..", "src", "applications", "applications.jl"))
using .Applications

@testset "Chapter 3 Julia applications" begin
    @testset "negFIN integration and support" begin
        txs = [[1,2], [1,2], [1,3], [2,3]]
        frequent = mine_itemsets(txs, 0.5)
        @test frequent[(1,)] == 3
        @test frequent[(2,)] == 3
        @test frequent[(3,)] == 2
        @test frequent[(1,2)] == 2
        @test !haskey(frequent, (1,2,3))
        @test Applications.validate_support(txs, frequent)
        @test mine_itemsets(txs, 0.5; algo=:optimized) == frequent
    end

    @testset "association rules and lift" begin
        txs = [[1,2], [1,2], [1,3], [2,3]]
        frequent = mine_itemsets(txs, 0.5)
        rules = association_rules(frequent, 4; minconf=0.6, minsup=0.5)
        rule = only([r for r in rules if r.lhs == [1] && r.rhs == [2]])
        @test rule.count == 2
        @test isapprox(rule.confidence, 2/3)
        @test isapprox(rule.lift, 8/9)
    end

    @testset "market input, output and naming" begin
        mktempdir() do dir
            source = joinpath(dir, "baskets.csv")
            open(source, "w") do io
                println(io, "apple,milk,")
                println(io, "milk,apple,")
                println(io, "apple,bread,")
                println(io, "milk,bread,")
            end
            baskets = load_baskets(source)
            txs, names = encode_baskets(baskets)
            @test length(txs) == 4
            @test names == ["apple", "bread", "milk"]
            summary = run_market_basket(; csv_path=source, minsup=0.5,
                minconf=0.3, output_dir=joinpath(dir, "market"),
                download_if_missing=false)
            @test summary.transactions == 4
            @test isfile(joinpath(dir, "market", "top10_lift.csv"))
            @test isfile(joinpath(dir, "market", "frequent_itemsets.spmf"))
        end
    end

    @testset "repeatable visual descriptors and k-means" begin
        img1 = zeros(8, 8)
        img2 = zeros(8, 8); img2[:, 3:5] .= 15.0
        features = Applications.collect_descriptors([img1, img2, img1, img2])
        @test size(features) == (36, 6)
        @test Applications.dense_descriptors(img1) == Applications.dense_descriptors(img1)
        codebook_a = learn_codebook(features; words=3, seed=42, max_iter=10)
        codebook_b = learn_codebook(features; words=3, seed=42, max_iter=10)
        @test codebook_a == codebook_b
        transactions = visual_transactions([img1, img2], codebook_a)
        @test length(transactions) == 2
        @test all(tx -> all(x -> 1 <= x <= 3, tx), transactions)
    end

    @testset "visual pipeline on real Digits subset" begin
        data = joinpath(Applications.ROOT, "data", "chapter3", "digits8x8.csv")
        imgs, labels = read_digits(data)
        @test length(imgs) > 500
        @test Set(labels) == Set([0,1,3,8])
        mktempdir() do dir
            run = run_visual_words(; data_path=data, minsup=0.25, words=6,
                max_per_class=12, output_dir=dir)
            @test run.train > 0 && run.test > 0
            @test 0 <= run.base_accuracy <= 1
            @test 0 <= run.pattern_accuracy <= 1
            @test isfile(joinpath(dir, "test_accuracy_comparison.csv"))
            @test isfile(joinpath(dir, "train_frequent_itemsets.spmf"))
        end
    end
end

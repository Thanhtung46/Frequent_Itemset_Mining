# Kiểm tra độc lập negFIN bằng brute-force trên CSDL nhỏ.
# Chạy: julia --project=. tests/test_ch3_julia.jl

using Test
include(joinpath(@__DIR__, "..", "src", "application_mining.jl"))

function brute_counts(txs::Vector{Vector{Int}}, threshold::Int)
    universe = sort(unique(vcat(txs...)))
    result = Dict{Tuple{Vararg{Int}}, Int}()
    for mask in 1:(2^length(universe) - 1)
        candidate = [universe[i] for i in eachindex(universe) if (mask & (1 << (i - 1))) != 0]
        count = sum(all(item in tx for item in candidate) for tx in txs)
        if count >= threshold
            result[Tuple(candidate)] = count
        end
    end
    return result
end

@testset "Chuong 3: negFIN nho + CLI" begin
    fixtures = [
        [[1, 2], [2, 3], [1, 2, 3], [1]],
        [[1, 1, 3], [1, 3], [1, 3]],
        [[2], [3], [4], [2, 3, 4]],
        [[1, 2, 3], [1, 2, 3], [1, 2, 3]],
        [[1, 4], [2, 4], [1, 2, 4], [2, 3]],
    ]
    for txs in fixtures
        minsup = 0.5
        threshold = ceil(Int, length(txs) * minsup)
        target = brute_counts(txs, threshold)
        actual = Dict(Tuple(sort(unique(items))) => sup for (items, sup) in negfin_baseline(txs, minsup))
        @test actual == target
    end
    @test resolve_min_sup_count(9, 0.3) == 3
    @test resolve_min_sup_count(9, 3.0) == 3

    mktempdir() do directory
        input_file = joinpath(directory, "transaction.spmf")
        output_file = joinpath(directory, "out.spmf")
        open(input_file, "w") do io
            println(io, "1 2")
            println(io, "2 3")
            println(io, "1 2 3")
            println(io, "1")
        end
        main(["--input", input_file, "--output", output_file, "--minsup", "0.5"])
        @test isfile(output_file)
        @test occursin("#SUP:", read(output_file, String))
    end
end

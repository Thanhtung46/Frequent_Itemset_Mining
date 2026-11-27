# Kiểm thử hiệu năng và bộ nhớ (Baseline vs. Optimized) sau bước warm-up JIT.

using Printf: @printf
using Random: MersenneTwister
using Test: @test, @testset

"""
    _make_bench_db(n_tx, n_items, avg_len, seed) -> Vector{Vector{Int}}

Sinh dữ liệu tổng hợp phân bố lệch (zipf-like) gần với dữ liệu thực tế để đo tốc độ
và bộ nhớ giữa `negfin_baseline` và `negfin_optimized`.
"""
function _make_bench_db(
    n_tx::Int,
    n_items::Int,
    avg_len::Int,
    seed::Int,
)::Vector{Vector{Int}}
    rng = MersenneTwister(seed)
    db = Vector{Vector{Int}}(undef, n_tx)
    for t in 1:n_tx
        len = clamp(round(Int, avg_len + 3 * randn(rng)), 2, n_items)
        chosen = Set{Int}()
        while length(chosen) < len
            # Phân bố lệch: item nhỏ xuất hiện thường xuyên hơn
            u = rand(rng)^2
            item = clamp(floor(Int, u * n_items) + 1, 1, n_items)
            push!(chosen, item)
        end
        db[t] = collect(chosen)
    end
    return db
end

@testset "Benchmark Tests (Baseline vs. Optimized)" begin
    cases = [
        ("Dense-64 (UInt64)", _make_bench_db(2000, 60, 18, 42), 0.15),
        ("Dense-120 (UInt128)", _make_bench_db(2000, 115, 20, 43), 0.10),
        ("Sparse-400 (Vector{UInt64})", _make_bench_db(3000, 400, 15, 44), 0.05),
    ]

    println("\n--- ĐỐI CHỨNG HIỆU NĂNG: BASELINE vs. OPTIMIZED ---")
    @printf(
        "%-28s | %9s | %9s | %7s | %10s | %10s\n",
        "Dataset",
        "Base (ms)",
        "Opt (ms)",
        "Speedup",
        "Base (MB)",
        "Opt (MB)",
    )
    println("-"^86)

    for (name, db, min_sup) in cases
        # Warm-up JIT trước khi đo
        r_base_warm = negfin_baseline(db, min_sup)
        r_opt_warm = negfin_optimized(db, min_sup)
        @test compare_results(r_base_warm, r_opt_warm)[1]

        GC.gc()
        t0 = time_ns()
        bytes_base = @allocated negfin_baseline(db, min_sup)
        ms_base = (time_ns() - t0) / 1e6

        GC.gc()
        t1 = time_ns()
        bytes_opt = @allocated negfin_optimized(db, min_sup)
        ms_opt = (time_ns() - t1) / 1e6

        speedup = ms_base / max(ms_opt, 1e-6)
        @printf(
            "%-28s | %9.2f | %9.2f | %6.2fx | %10.2f | %10.2f\n",
            name,
            ms_base,
            ms_opt,
            speedup,
            bytes_base / 1048576.0,
            bytes_opt / 1048576.0,
        )
        @test ms_opt <= ms_base * 1.5
    end
    println("-"^86)
end

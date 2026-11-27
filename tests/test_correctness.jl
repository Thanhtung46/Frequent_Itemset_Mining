# Kiểm thử tính đúng đắn (Correctness) trên >= 7 CSDL khác nhau (bao gồm các trường hợp biên,
# kiểm thử đa nhánh Multiple Dispatch và đối chiếu 100% với Ground Truth / `spmf.jar`).

using Random: MersenneTwister
using Test: @test, @testset

"""
    _brute_force_fim(transactions, min_sup) -> Dict{Vector{Int}, Int}

Thuật toán vét cạn (chỉ dùng cho CSDL nhỏ <= 15 item trong unit test) để tạo Ground Truth
độc lập 100% dùng kiểm chứng cả `negfin_baseline` lẫn `negfin_optimized`.
"""
function _brute_force_fim(
    transactions::Vector{Vector{Int}},
    min_sup::Real,
)::Dict{Vector{Int}, Int}
    n_tx = length(transactions)
    gt = Dict{Vector{Int}, Int}()
    if n_tx == 0
        return gt
    end
    min_sup_count = resolve_min_sup_count(n_tx, min_sup)
    tx_sets = [Set(tx) for tx in transactions]
    all_items = sort!(collect(union(Set{Int}(), tx_sets...)))
    n_items = length(all_items)

    for mask in 1:((1 << n_items) - 1)
        cand = Int[]
        for bit in 0:(n_items - 1)
            if (mask & (1 << bit)) != 0
                push!(cand, all_items[bit + 1])
            end
        end
        sup = 0
        for s in tx_sets
            if all(item -> item in s, cand)
                sup += 1
            end
        end
        if sup >= min_sup_count
            gt[cand] = sup
        end
    end
    return gt
end

"""
    _generate_synthetic_db(n_tx, n_items, avg_len, seed) -> Vector{Vector{Int}}

Sinh CSDL giao dịch tổng hợp có tính tái lập bằng `MersenneTwister(seed)`.
"""
function _generate_synthetic_db(
    n_tx::Int,
    n_items::Int,
    avg_len::Int,
    seed::Int,
)::Vector{Vector{Int}}
    rng = MersenneTwister(seed)
    db = Vector{Vector{Int}}(undef, n_tx)
    for t in 1:n_tx
        len = clamp(round(Int, avg_len + 2 * randn(rng)), 1, n_items)
        # Lấy mẫu không hoàn lại các item trong 1..n_items
        chosen = Set{Int}()
        while length(chosen) < len
            push!(chosen, rand(rng, 1:n_items))
        end
        db[t] = collect(chosen)
    end
    return db
end

@testset "Correctness Tests" begin
    # ------------------------------------------------------------------
    # CSDL 1: Ví dụ Table 1 trong bài báo Aryabarzan et al. (2018)
    # a=1, b=2, c=3, d=4, e=5, f=6, g=7, h=8, i=9; min_sup = 0.4 (count = 2)
    # ------------------------------------------------------------------
    @testset "1. Paper Example 1 (Table 1, minsup=0.4)" begin
        sample_path = joinpath(@__DIR__, "..", "data", "toy", "paper_example1.txt")
        db = read_spmf_database(sample_path)
        @test length(db) == 5

        gt = _brute_force_fim(db, 0.4)
        res_base = negfin_baseline(db, 0.4)
        res_opt = negfin_optimized(db, 0.4)

        ok_base, msg_base = compare_results(res_base, gt)
        ok_opt, msg_opt = compare_results(res_opt, gt)
        @test ok_base
        @test ok_opt
        @test compare_results(res_base, res_opt)[1]
    end

    # ------------------------------------------------------------------
    # CSDL 2: Trường hợp biên — CSDL rỗng & minsup quá cao (0 itemsets)
    # ------------------------------------------------------------------
    @testset "2. Edge Cases: Empty DB & Too-High MinSup" begin
        empty_db = Vector{Vector{Int}}()
        @test isempty(negfin_baseline(empty_db, 0.5))
        @test isempty(negfin_optimized(empty_db, 0.5))

        disjoint_db = [[1, 2], [3, 4], [5, 6]]
        @test isempty(negfin_baseline(disjoint_db, 0.9))
        @test isempty(negfin_optimized(disjoint_db, 0.9))
        @test isempty(negfin_baseline(disjoint_db, 4))
        @test isempty(negfin_optimized(disjoint_db, 4))
    end

    # ------------------------------------------------------------------
    # CSDL 3: MinSup cực thấp & Promotion mạnh (mọi giao dịch giống nhau)
    # ------------------------------------------------------------------
    @testset "3. Extreme Promotion & Very Low MinSup" begin
        # 8 item giống hệt nhau trong cả 5 giao dịch => 2^8 - 1 = 255 itemsets (support = 5)
        identical_db = [collect(1:8) for _ in 1:5]
        gt = _brute_force_fim(identical_db, 0.2)
        res_base = negfin_baseline(identical_db, 0.2)
        res_opt = negfin_optimized(identical_db, 0.2)

        @test length(gt) == 255
        @test compare_results(res_base, gt)[1]
        @test compare_results(res_opt, gt)[1]
    end

    # ------------------------------------------------------------------
    # CSDL 4: Giao dịch trùng lặp & item trùng trong cùng một giao dịch
    # ------------------------------------------------------------------
    @testset "4. Duplicate Transactions & Duplicate Items in Transaction" begin
        dup_db = [
            [1, 2, 2, 3, 1],
            [1, 2, 3],
            [2, 3, 4, 4],
            [2, 3, 4],
            [1, 4, 4, 4],
        ]
        gt = _brute_force_fim(dup_db, 0.4)
        res_base = negfin_baseline(dup_db, 0.4)
        res_opt = negfin_optimized(dup_db, 0.4)

        @test compare_results(res_base, gt)[1]
        @test compare_results(res_opt, gt)[1]
    end

    # ------------------------------------------------------------------
    # CSDL 5: Mã item không liên tục, lộn xộn và giá trị rất lớn
    # ------------------------------------------------------------------
    @testset "5. Non-Contiguous & Large Item IDs" begin
        sparse_id_db = [
            [100001, 7, 999999, 42],
            [42, 100001, 500],
            [7, 42, 999999],
            [100001, 42, 7, 500],
            [999999, 7, 500],
            [42, 7, 100001, 999999],
        ]
        gt = _brute_force_fim(sparse_id_db, 0.35)
        res_base = negfin_baseline(sparse_id_db, 0.35)
        res_opt = negfin_optimized(sparse_id_db, 0.35)

        @test compare_results(res_base, gt)[1]
        @test compare_results(res_opt, gt)[1]
    end

    # ------------------------------------------------------------------
    # CSDL 6: Kiểm thử toàn bộ các nhánh Multiple Dispatch (UInt64..Vector{UInt64})
    # ------------------------------------------------------------------
    @testset "6. Multi-Width Bitmap Dispatch (nf = 40, 80, 150, 220, 300)" begin
        for (idx, n_items) in enumerate([40, 80, 150, 220, 300])
            db = _generate_synthetic_db(120, n_items, 12, 100 + idx)
            min_sup = 0.08
            res_base = negfin_baseline(db, min_sup)
            res_opt = negfin_optimized(db, min_sup)
            ok, msg = compare_results(res_base, res_opt)
            @test ok
        end
    end

    # ------------------------------------------------------------------
    # CSDL 7: Kiểm thử I/O chuẩn SPMF & vòng khép kín đọc/ghi
    # ------------------------------------------------------------------
    @testset "7. SPMF I/O Round-Trip" begin
        db = _generate_synthetic_db(50, 12, 5, 2026)
        res_opt = negfin_optimized(db, 0.25)
        tmp_file = tempname() * ".txt"
        try
            write_spmf_results(tmp_file, res_opt)
            parsed = read_spmf_results(tmp_file)
            @test compare_results(res_opt, parsed)[1]
        finally
            isfile(tmp_file) && rm(tmp_file)
        end
    end

    # ------------------------------------------------------------------
    # CSDL 8: Đối chiếu trực tiếp 100% với `spmf/spmf.jar` trên 5 CSDL khác nhau
    # ------------------------------------------------------------------
    function _find_java_for_spmf(jar_path::AbstractString)
        candidates = [
            "/opt/homebrew/opt/openjdk/bin/java",
            "/opt/homebrew/opt/openjdk@25/bin/java",
            "/opt/homebrew/opt/openjdk@21/bin/java",
            "/opt/homebrew/opt/openjdk@17/bin/java",
            "/usr/local/opt/openjdk/bin/java",
            "java",
        ]
        for bin in candidates
            if bin != "java" && !isfile(bin)
                continue
            end
            try
                p_err = IOBuffer()
                cmd = `$bin -jar $jar_path test_check`
                proc = run(pipeline(cmd; stdout=devnull, stderr=p_err); wait=false)
                wait(proc)
                msg = String(take!(p_err))
                if !occursin("UnsupportedClassVersionError", msg) &&
                   !occursin("Unable to locate a Java Runtime", msg)
                    return bin
                end
            catch
            end
        end
        return nothing
    end

    spmf_jar = joinpath(@__DIR__, "..", "spmf", "spmf.jar")
    java_bin = isfile(spmf_jar) ? _find_java_for_spmf(spmf_jar) : nothing
    if isfile(spmf_jar) && java_bin !== nothing
        @testset "8. Cross-Check 100% with SPMF (spmf.jar) on 5 Datasets" begin
            ex1_path = joinpath(@__DIR__, "..", "data", "toy", "paper_example1.txt")
            spmf_cases = [
                ("Paper Example 1", read_spmf_database(ex1_path), 0.4),
                ("Identical-Promo (8 items)", [collect(1:8) for _ in 1:6], 0.5),
                ("Non-Contiguous IDs", [
                    [1001, 7, 9999, 42],
                    [42, 1001, 500],
                    [7, 42, 9999],
                    [1001, 42, 7, 500],
                    [9999, 7, 500],
                    [42, 7, 1001, 9999],
                ], 0.35),
                ("Synthetic Dense-40", _generate_synthetic_db(150, 40, 12, 301), 0.15),
                ("Synthetic Sparse-120", _generate_synthetic_db(200, 120, 10, 302), 0.08),
            ]

            println("\n--- ĐỐI CHIẾU 100% VỚI SPMF (spmf.jar / negFIN) ---")
            for (label, db, min_sup) in spmf_cases
                in_tmp = tempname() * "_in.txt"
                out_spmf = tempname() * "_spmf.txt"
                try
                    open(in_tmp, "w") do io
                        for tx in db
                            println(io, join(sort(unique(tx)), " "))
                        end
                    end
                    pct_str = string(round(min_sup * 100; digits=4), "%")
                    spmf_cmd = Cmd([
                        java_bin, "-jar", spmf_jar, "run", "negFIN",
                        in_tmp, out_spmf, pct_str,
                    ])
                    run(pipeline(spmf_cmd; stdout=devnull, stderr=devnull))
                    spmf_dict = read_spmf_results(out_spmf)
                    res_b = negfin_baseline(db, min_sup)
                    res_o = negfin_optimized(db, min_sup)
                    ok_base, msg_base = compare_results(res_b, spmf_dict)
                    ok_opt, msg_opt = compare_results(res_o, spmf_dict)
                    println("  [SPMF] $label ($pct_str): Base=$msg_base | Opt=$msg_opt")
                    @test ok_base
                    @test ok_opt
                finally
                    isfile(in_tmp) && rm(in_tmp)
                    isfile(out_spmf) && rm(out_spmf)
                end
            end
        end
    else
        @info "Bỏ qua đối chiếu trực tiếp SPMF (thiếu $spmf_jar hoặc Java Runtime)"
    end
end

"""
Script thực nghiệm Chương 2 — Đánh giá thuật toán `negFIN` trên 5 bộ dữ liệu benchmark
(Chess, Mushroom, Accidents, Retail, T10I4D100K) và dữ liệu tổng hợp.

Thực thi đủ 6 thực nghiệm bắt buộc:
  1. Correctness (đối chiếu 100% Baseline vs. Optimized và SPMF nếu có JVM tương thích)
  2. Runtime theo `minsup` (6 mốc/CSDL, trung vị 3 lần chạy sau warm-up JIT)
  3. Output Size (số lượng frequent itemsets theo `minsup`)
  4. Peak Memory / Heap Allocated (Baseline vs. Optimized ở mức `minsup` trung bình)
  5. Scalability (10%, 25%, 50%, 75%, 100% giao dịch trên Retail và Accidents)
  6. Ảnh hưởng của độ dài giao dịch trung bình (CSDL tổng hợp, `Random.seed!(42)`)

Kết quả CSV được xuất vào `results/logs/`.
"""

using Printf: @printf, @sprintf
using Random: MersenneTwister
using Statistics: median

include(joinpath(@__DIR__, "..", "src", "utils.jl"))
include(joinpath(@__DIR__, "..", "src", "structures.jl"))
include(joinpath(@__DIR__, "..", "src", "negfin_baseline.jl"))
include(joinpath(@__DIR__, "..", "src", "negfin_optimized.jl"))

const ROOT_DIR = normpath(joinpath(@__DIR__, ".."))
const BENCH_DIR = joinpath(ROOT_DIR, "data", "benchmark")
const LOGS_DIR = joinpath(ROOT_DIR, "results", "logs")
const SPMF_JAR = joinpath(ROOT_DIR, "spmf", "spmf.jar")

# Cấu hình 5 bộ benchmark chuẩn theo Table 2 (Aryabarzan et al., 2018)
const BENCHMARK_CONFIGS = [
    (
        name="chess",
        file="chess.txt",
        kind="dense",
        minsups=[0.90, 0.85, 0.80, 0.75, 0.70, 0.65],
        med_minsup=0.75,
        corr_minsup=0.80,
    ),
    (
        name="mushroom",
        file="mushroom.txt",
        kind="dense",
        minsups=[0.40, 0.35, 0.30, 0.25, 0.20, 0.15],
        med_minsup=0.25,
        corr_minsup=0.30,
    ),
    (
        name="accidents",
        file="accidents.txt",
        kind="dense",
        minsups=[0.75, 0.70, 0.65, 0.60, 0.55, 0.50],
        med_minsup=0.60,
        corr_minsup=0.70,
    ),
    (
        name="retail",
        file="retail.txt",
        kind="sparse",
        minsups=[0.05, 0.03, 0.02, 0.01, 0.005, 0.003],
        med_minsup=0.01,
        corr_minsup=0.02,
    ),
    (
        name="T10I4D100K",
        file="T10I4D100K.txt",
        kind="sparse",
        minsups=[0.04, 0.03, 0.02, 0.015, 0.01, 0.007],
        med_minsup=0.015,
        corr_minsup=0.02,
    ),
]

"""
    find_compatible_java(jar_path) -> Union{String, Nothing}

Tìm binary `java` tương thích với `spmf.jar` (không lỗi `UnsupportedClassVersionError`).
"""
function find_compatible_java(jar_path::AbstractString)
    if !isfile(jar_path)
        return nothing
    end
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
            proc = run(
                pipeline(`$bin -jar $jar_path test_check`; stdout=devnull, stderr=p_err);
                wait=false,
            )
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

"""
    run_spmf_negfin(java_bin, input_path, min_sup) -> Tuple{Float64, Dict{Vector{Int}, Int}}

Chạy `spmf.jar` (thuật toán `negFIN`) và trả về `(runtime_sec, result_dict)`.
"""
function run_spmf_negfin(java_bin::String, input_path::String, min_sup::Float64)
    out_tmp = tempname() * "_spmf.txt"
    pct_str = string(round(min_sup * 100; digits=4), "%")
    try
        t0 = time_ns()
        run(
            pipeline(
                `$java_bin -jar $SPMF_JAR run negFIN $input_path $out_tmp $pct_str`;
                stdout=devnull,
                stderr=devnull,
            ),
        )
        elapsed = (time_ns() - t0) / 1e9
        res = read_spmf_results(out_tmp)
        return (elapsed, res)
    finally
        isfile(out_tmp) && rm(out_tmp)
    end
end

"""
    measure_median_runtime(fn, db, min_sup; repeats=3) -> Tuple{Float64, Int, Float64}

Đo thời gian chạy trung vị (giây), số lượng itemsets và bộ nhớ cấp phát (MB) sau warm-up JIT.
"""
function measure_median_runtime(
    fn::F,
    db::Vector{Vector{Int}},
    min_sup::Float64;
    repeats::Int=3,
) where {F}
    # Warm-up 1 lần để loại bỏ thời gian biên dịch JIT
    res = fn(db, min_sup)
    n_itemsets = length(res)
    res = nothing

    times = Vector{Float64}(undef, repeats)
    alloc_mb = 0.0
    for r in 1:repeats
        GC.gc()
        t0 = time_ns()
        bytes = @allocated fn(db, min_sup)
        times[r] = (time_ns() - t0) / 1e9
        if r == 1
            alloc_mb = bytes / 1048576.0
        end
    end
    return (median(times), n_itemsets, alloc_mb)
end

"""
    measure_peak_rss_mb(input_path, min_sup, algo) -> Float64

Đo Peak RSS (MB) thực tế của tiến trình Julia con bằng `/usr/bin/time -l` (macOS)
hoặc `/usr/bin/time -v` (Linux).
"""
function measure_peak_rss_mb(input_path::String, min_sup::Float64, algo::String)::Float64
    julia_bin = Base.julia_cmd().exec[1]
    main_jl = joinpath(ROOT_DIR, "src", "main.jl")
    out_tmp = tempname() * "_rss.txt"
    err_buf = IOBuffer()
    try
        if Sys.isapple()
            cmd = `/usr/bin/time -l $julia_bin --project=$ROOT_DIR $main_jl --input $input_path --output $out_tmp --minsup $min_sup --algo $algo`
            run(pipeline(cmd; stdout=devnull, stderr=err_buf))
            txt = String(take!(err_buf))
            m = match(r"(\d+)\s+maximum resident set size", txt)
            return m === nothing ? NaN : parse(Float64, m.captures[1]) / 1048576.0
        elseif Sys.islinux()
            cmd = `/usr/bin/time -v $julia_bin --project=$ROOT_DIR $main_jl --input $input_path --output $out_tmp --minsup $min_sup --algo $algo`
            run(pipeline(cmd; stdout=devnull, stderr=err_buf))
            txt = String(take!(err_buf))
            m = match(r"Maximum resident set size \(kbytes\):\s+(\d+)", txt)
            return m === nothing ? NaN : parse(Float64, m.captures[1]) / 1024.0
        else
            return NaN
        end
    finally
        isfile(out_tmp) && rm(out_tmp)
    end
end

"""
    count_bmc_tree_nodes(transactions, min_sup) -> Tuple{Int, Int}

Đếm tổng số nút trên cây BMC-tree và số lượng frequent 1-itemsets `nf` (phục vụ
phân tích lý thuyết ở Thực nghiệm 6).
"""
function count_bmc_tree_nodes(
    transactions::Vector{Vector{Int}},
    min_sup::Float64,
)::Tuple{Int, Int}
    min_sup_count = resolve_min_sup_count(length(transactions), min_sup)
    root, l1_items, _ = _build_bmc_tree_baseline(transactions, min_sup_count)
    n_f = length(l1_items)
    if n_f == 0
        return (0, 0)
    end
    node_count = 0
    stack = copy(root.children)
    while !isempty(stack)
        n = pop!(stack)
        node_count += 1
        append!(stack, n.children)
    end
    return (node_count, n_f)
end

"""
    generate_synthetic_txlen_db(n_tx, n_items, avg_len, seed) -> Vector{Vector{Int}}

Sinh CSDL tổng hợp có độ dài giao dịch trung bình `avg_len` (cố định `seed`).
"""
function generate_synthetic_txlen_db(
    n_tx::Int,
    n_items::Int,
    avg_len::Int,
    seed::Int,
)::Vector{Vector{Int}}
    rng = MersenneTwister(seed)
    db = Vector{Vector{Int}}(undef, n_tx)
    for t in 1:n_tx
        len = clamp(round(Int, avg_len + 2 * randn(rng)), 2, n_items)
        chosen = Set{Int}()
        while length(chosen) < len
            u = rand(rng)^1.6
            item = clamp(floor(Int, u * n_items) + 1, 1, n_items)
            push!(chosen, item)
        end
        db[t] = collect(chosen)
    end
    return db
end

function run_all_experiments()
    mkpath(LOGS_DIR)
    java_bin = find_compatible_java(SPMF_JAR)
    if java_bin === nothing
        println("[Info] Không tìm thấy JVM tương thích spmf.jar — bỏ qua đường cong SPMF.")
    else
        println("[Info] Đã phát hiện JVM tương thích SPMF: $java_bin")
    end

    # Tải sẵn 5 CSDL vào RAM để tái sử dụng giữa các thực nghiệm
    datasets = Dict{String, Vector{Vector{Int}}}()
    for cfg in BENCHMARK_CONFIGS
        fpath = joinpath(BENCH_DIR, cfg.file)
        if !isfile(fpath)
            error("Thiếu file benchmark: $fpath")
        end
        println("Đang nạp $(cfg.name) từ $fpath ...")
        datasets[cfg.name] = read_spmf_database(fpath)
    end

    # ==========================================================================
    # THỰC NGHIỆM 1: TÍNH ĐÚNG ĐẮN (CORRECTNESS) TRÊN 5 BỘ BENCHMARK
    # ==========================================================================
    println("\n=== THỰC NGHIỆM 1: CORRECTNESS (5 BENCHMARKS) ===")
    open(joinpath(LOGS_DIR, "exp1_correctness.csv"), "w") do io
        println(io, "dataset,minsup,n_tx,itemsets_base,itemsets_opt,base_vs_opt_match,spmf_match")
        for cfg in BENCHMARK_CONFIGS
            db = datasets[cfg.name]
            res_base = negfin_baseline(db, cfg.corr_minsup)
            res_opt = negfin_optimized(db, cfg.corr_minsup)
            ok_bo, msg_bo = compare_results(res_base, res_opt)

            spmf_status = "SKIPPED_JVM"
            if java_bin !== nothing
                _, spmf_dict = run_spmf_negfin(
                    java_bin, joinpath(BENCH_DIR, cfg.file), cfg.corr_minsup
                )
                ok_spmf, _ = compare_results(res_opt, spmf_dict)
                spmf_status = ok_spmf ? "MATCH_100%" : "MISMATCH"
            end

            println(
                io,
                "$(cfg.name),$(cfg.corr_minsup),$(length(db)),$(length(res_base))," *
                "$(length(res_opt)),$(ok_bo ? "MATCH_100%" : "MISMATCH"),$spmf_status",
            )
            @printf(
                "  %-12s (minsup=%.3f): %s | SPMF=%s\n",
                cfg.name,
                cfg.corr_minsup,
                msg_bo,
                spmf_status,
            )
        end
    end

    # ==========================================================================
    # THỰC NGHIỆM 2 & 3: RUNTIME & OUTPUT SIZE THEO MINSUP
    # ==========================================================================
    println("\n=== THỰC NGHIỆM 2 & 3: RUNTIME & OUTPUT SIZE THEO MINSUP ===")
    open(joinpath(LOGS_DIR, "exp2_3_runtime_output.csv"), "w") do io
        println(
            io,
            "dataset,kind,minsup,n_itemsets,time_base_s,time_opt_s,speedup,alloc_base_mb,alloc_opt_mb,time_spmf_s",
        )
        for cfg in BENCHMARK_CONFIGS
            db = datasets[cfg.name]
            fpath = joinpath(BENCH_DIR, cfg.file)
            println("  Đang chạy $(cfg.name) ($(length(db)) tx)...")
            for ms in cfg.minsups
                t_base, n_is_b, mb_base = measure_median_runtime(
                    negfin_baseline, db, ms; repeats=3
                )
                t_opt, n_is_o, mb_opt = measure_median_runtime(
                    negfin_optimized, db, ms; repeats=3
                )
                @assert n_is_b == n_is_o "Lệch số itemsets trên $(cfg.name) ở minsup=$ms"

                t_spmf = NaN
                if java_bin !== nothing
                    t_spmf, _ = run_spmf_negfin(java_bin, fpath, ms)
                end

                speedup = t_base / max(t_opt, 1e-9)
                @printf(
                    "    minsup=%-6.3f | itemsets=%8d | base=%7.4fs | opt=%7.4fs | speedup=%5.2fx\n",
                    ms,
                    n_is_o,
                    t_base,
                    t_opt,
                    speedup,
                )
                spmf_str = isnan(t_spmf) ? "" : @sprintf("%.6f", t_spmf)
                @printf(
                    io,
                    "%s,%s,%.4f,%d,%.6f,%.6f,%.3f,%.3f,%.3f,%s\n",
                    cfg.name,
                    cfg.kind,
                    ms,
                    n_is_o,
                    t_base,
                    t_opt,
                    speedup,
                    mb_base,
                    mb_opt,
                    spmf_str,
                )
            end
        end
    end

    # ==========================================================================
    # THỰC NGHIỆM 4: PEAK MEMORY (RSS) & ALLOCATED RAM (BASELINE vs. OPTIMIZED)
    # ==========================================================================
    println("\n=== THỰC NGHIỆM 4: PEAK MEMORY (BASELINE vs. OPTIMIZED) ===")
    open(joinpath(LOGS_DIR, "exp4_memory.csv"), "w") do io
        println(
            io,
            "dataset,minsup,alloc_base_mb,alloc_opt_mb,alloc_reduction_pct,peak_rss_base_mb,peak_rss_opt_mb",
        )
        for cfg in BENCHMARK_CONFIGS
            db = datasets[cfg.name]
            fpath = joinpath(BENCH_DIR, cfg.file)
            ms = cfg.med_minsup
            _, _, mb_base = measure_median_runtime(negfin_baseline, db, ms; repeats=1)
            _, _, mb_opt = measure_median_runtime(negfin_optimized, db, ms; repeats=1)
            rss_base = measure_peak_rss_mb(fpath, ms, "baseline")
            rss_opt = measure_peak_rss_mb(fpath, ms, "optimized")
            red_pct = (1.0 - mb_opt / max(mb_base, 1e-9)) * 100.0
            @printf(
                "  %-12s (minsup=%.3f): Alloc %.2f -> %.2f MB (-%.1f%%) | Peak RSS %.1f -> %.1f MB\n",
                cfg.name,
                ms,
                mb_base,
                mb_opt,
                red_pct,
                rss_base,
                rss_opt,
            )
            @printf(
                io,
                "%s,%.4f,%.3f,%.3f,%.2f,%.2f,%.2f\n",
                cfg.name,
                ms,
                mb_base,
                mb_opt,
                red_pct,
                rss_base,
                rss_opt,
            )
        end
    end

    # ==========================================================================
    # THỰC NGHIỆM 5: KHẢ NĂNG MỞ RỘNG (SCALABILITY 10% -> 100%)
    # ==========================================================================
    println("\n=== THỰC NGHIỆM 5: SCALABILITY (10%, 25%, 50%, 75%, 100%) ===")
    scalability_targets = [
        ("retail", 0.005),
        ("accidents", 0.55),
    ]
    fractions = [0.10, 0.25, 0.50, 0.75, 1.00]
    open(joinpath(LOGS_DIR, "exp5_scalability.csv"), "w") do io
        println(io, "dataset,minsup,fraction,n_tx,n_itemsets,time_base_s,time_opt_s,alloc_opt_mb")
        for (dname, ms) in scalability_targets
            full_db = datasets[dname]
            n_total = length(full_db)
            for frac in fractions
                n_sub = max(1, round(Int, n_total * frac))
                sub_db = full_db[1:n_sub]
                t_base, _, _ = measure_median_runtime(negfin_baseline, sub_db, ms; repeats=3)
                t_opt, n_is, mb_opt = measure_median_runtime(
                    negfin_optimized, sub_db, ms; repeats=3
                )
                @printf(
                    "  %-10s %3d%% (%6d tx): base=%7.4fs | opt=%7.4fs | itemsets=%d\n",
                    dname,
                    round(Int, frac * 100),
                    n_sub,
                    t_base,
                    t_opt,
                    n_is,
                )
                @printf(
                    io,
                    "%s,%.4f,%.2f,%d,%d,%.6f,%.6f,%.3f\n",
                    dname,
                    ms,
                    frac,
                    n_sub,
                    n_is,
                    t_base,
                    t_opt,
                    mb_opt,
                )
            end
        end
    end

    # ==========================================================================
    # THỰC NGHIỆM 6: ẢNH HƯỞNG ĐỘ DÀI GIAO DỊCH TRUNG BÌNH (SYNTHETIC)
    # ==========================================================================
    println("\n=== THỰC NGHIỆM 6: ẢNH HƯỞNG ĐỘ DÀI GIAO DỊCH TRUNG BÌNH ===")
    avg_lengths = [10, 14, 18, 22, 26, 30]
    n_tx_syn = 10_000
    n_items_syn = 80
    ms_syn = 0.20
    open(joinpath(LOGS_DIR, "exp6_tx_length.csv"), "w") do io
        println(
            io,
            "avg_len,n_tx,n_items,minsup,nf,bmc_nodes,n_itemsets,time_base_s,time_opt_s,alloc_base_mb,alloc_opt_mb",
        )
        for (i, alen) in enumerate(avg_lengths)
            syn_db = generate_synthetic_txlen_db(n_tx_syn, n_items_syn, alen, 42 + i)
            bmc_nodes, n_f = count_bmc_tree_nodes(syn_db, ms_syn)
            t_base, _, mb_base = measure_median_runtime(
                negfin_baseline, syn_db, ms_syn; repeats=3
            )
            t_opt, n_is, mb_opt = measure_median_runtime(
                negfin_optimized, syn_db, ms_syn; repeats=3
            )
            @printf(
                "  avg_len=%2d | nf=%2d | bmc_nodes=%6d | itemsets=%6d | base=%7.4fs | opt=%7.4fs\n",
                alen,
                n_f,
                bmc_nodes,
                n_is,
                t_base,
                t_opt,
            )
            @printf(
                io,
                "%d,%d,%d,%.4f,%d,%d,%d,%.6f,%.6f,%.3f,%.3f\n",
                alen,
                n_tx_syn,
                n_items_syn,
                ms_syn,
                n_f,
                bmc_nodes,
                n_is,
                t_base,
                t_opt,
                mb_base,
                mb_opt,
            )
        end
    end

    println("\n[DONE] Toàn bộ 6 thực nghiệm đã hoàn tất! CSV lưu tại: $LOGS_DIR")
end

if abspath(PROGRAM_FILE) == @__FILE__
    run_all_experiments()
end

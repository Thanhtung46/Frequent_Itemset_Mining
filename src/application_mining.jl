# Cầu nối ứng dụng Chương 3 với negFIN chính thức của nhóm (Chương 1).
#
# Chạy từ thư mục gốc repository:
# julia --project=. src/application_mining.jl --input data.txt --output out.txt --minsup 0.01
#
# Đọc và ghi theo format SPMF.
# Không dùng thư viện frequent-itemset mining khác.
# Giữ nguyên code gốc tại src/algorithm/ của nhóm.
include(joinpath(@__DIR__, "utils.jl"))
include(joinpath(@__DIR__, "structures.jl"))
include(joinpath(@__DIR__, "algorithm", "negfin_baseline.jl"))

function parse_args(args::Vector{String})
    ops = Dict{String, String}()
    i = 1
    while i <= length(args)
        key = args[i]
        key in ("--input", "--output", "--minsup") || error("Tham số không hợp lệ: $key")
        i < length(args) || error("Thiếu giá trị của $key")
        options[key] = args[i + 1]
        i += 2
    end
    all(haskey(options, k) for k in ("--input", "--output", "--minsup")) ||
        error("Cú pháp: julia src/application_mining.jl --input FILE --output FILE --minsup VALUE")
    return options
end

function main(args::Vector{String})
    options = parse_args(args)
    transactions = read_spmf_database(options["--input"])
    isempty(transactions) && error("Không tìm thấy giao dịch hợp lệ")
    minsup = parse(Float64, options["--minsup"])
    (isfinite(minsup) && minsup > 0) || error("MinSup phải là số hữu hạn > 0")
    (minsup <= 1 || isinteger(minsup)) || error("MinSup > 1 phải là số giao dịch nguyên")
    threshold = resolve_min_sup_count(length(transactions), minsup)

    started = time()
    raw = negfin_baseline(transactions, minsup)
    normalized = Dict{Tuple{Vararg{Int}}, Int}()
    for (items, support) in raw
        key = Tuple(sort(unique(items)))
        isempty(key) && continue
        support >= threshold || error("Support dưới ngưỡng: $key")
        if haskey(normalized, key)
            error("negFIN xuất itemset trùng: $key")
        end
        normalized[key] = support
    end
    ordered = collect(normalized)
    sort!(ordered; by=kv -> (length(kv.first), kv.first))
    result = [(collect(kv.first), kv.second) for kv in ordered]
    mkpath(dirname(abspath(options["--output"])))
    write_spmf_results(options["--output"], result)
    println("CH3_NEGFIN transactions=", length(transactions),
            " minsup_count=", threshold,
            " itemsets=", length(result),
            " elapsed_sec=", round(time() - started, digits=4))
end

if abspath(PROGRAM_FILE) == @__FILE__
    main(ARGS)
end

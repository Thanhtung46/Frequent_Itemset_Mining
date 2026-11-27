"""
Các hàm tiện ích dùng chung cho Chương 3: chuẩn hóa giao dịch, cầu nối gọi trực tiếp
`negFIN` của nhóm, kiểm chứng support và xuất kết quả SPMF/CSV/SVG thuần Julia.
"""

const ItemsetSupport = Dict{Tuple{Vararg{Int}}, Int}

"""
    save_transactions(path::AbstractString, txs::Vector{Vector{Int}}) -> AbstractString

Ghi danh sách giao dịch đã chuẩn hóa (sắp xếp tăng dần, không trùng lặp, mã nguyên dương)
ra file `.spmf`.
"""
function save_transactions(path::AbstractString, txs::Vector{Vector{Int}})
    mkpath(dirname(path))
    open(path, "w") do io
        for tx in txs
            isempty(tx) && error("Empty transactions are not supported")
            items = sort!(unique(tx))
            all(>(0), items) || error("Transaction items must be positive integers")
            println(io, join(items, ' '))
        end
    end
    return path
end

"""
    mine_itemsets(txs, minsup; algo=:baseline, output=nothing) -> ItemsetSupport

Cầu nối gọi trực tiếp `negfin_baseline` hoặc `negfin_optimized` của nhóm trên tập
giao dịch `txs`, kiểm tra tính hợp lệ của kết quả và tùy chọn ghi ra file chuẩn SPMF.

# Arguments
- `txs`: Danh sách giao dịch `Vector{Vector{Int}}`.
- `minsup`: Ngưỡng hỗ trợ tối thiểu (tỷ lệ trong `(0, 1]` hoặc số đếm nguyên).
- `algo`: `:baseline` hoặc `:optimized`.
- `output`: Đường dẫn file SPMF đầu ra (nếu khác `nothing`).
"""
function mine_itemsets(
    txs::Vector{Vector{Int}},
    minsup::Real;
    algo::Symbol=:baseline,
    output::Union{Nothing, String}=nothing,
)::ItemsetSupport
    isempty(txs) && error("Cannot mine an empty transaction database")
    isfinite(minsup) && minsup > 0 || error("minsup must be finite and > 0")
    (minsup <= 1 || isinteger(minsup)) || error("Absolute minsup must be an integer")
    algo in (:baseline, :optimized) || error("algo must be :baseline or :optimized")

    clean = [sort!(unique(copy(tx))) for tx in txs]
    all(tx -> !isempty(tx) && all(>(0), tx), clean) || error("Invalid transaction")

    raw = if algo == :baseline
        negfin_baseline(clean, minsup)
    else
        negfin_optimized(clean, minsup)
    end
    threshold = resolve_min_sup_count(length(clean), minsup)

    result = ItemsetSupport()
    for (items, support) in raw
        key = Tuple(sort!(unique(copy(items))))
        isempty(key) && error("negFIN emitted an empty itemset")
        support >= threshold || error("negFIN support below threshold for $key")
        haskey(result, key) && error("negFIN emitted duplicate itemset $key")
        result[key] = support
    end

    if output !== nothing
        mkpath(dirname(output))
        sorted_items = sort!(
            collect(result); by=entry -> (length(entry.first), entry.first)
        )
        write_spmf_results(output, [(collect(k), v) for (k, v) in sorted_items])
    end
    return result
end

"""
    validate_support(txs::Vector{Vector{Int}}, itemsets::ItemsetSupport) -> Bool

Đối chiếu độc lập `support` của mọi tập phổ biến bằng cách đếm trực tiếp trên `txs`.
Báo lỗi ngay nếu có bất kỳ sai lệch nào.
"""
function validate_support(txs::Vector{Vector{Int}}, itemsets::ItemsetSupport)
    sets = [Set(tx) for tx in txs]
    for (items, expected) in itemsets
        observed = count(tx -> all(in(tx), items), sets)
        if observed != expected
            error("Wrong support for $items: got $expected, expected $observed")
        end
    end
    return true
end

function csv_field(value)::String
    s = string(value)
    if occursin(',', s) || occursin('"', s) || occursin('\n', s)
        return "\"" * replace(s, "\"" => "\"\"") * "\""
    end
    return s
end

function write_csv(path::AbstractString, headers::Vector{String}, rows)
    mkpath(dirname(path))
    open(path, "w") do io
        println(io, join(csv_field.(headers), ','))
        for row in rows
            println(io, join(csv_field.(collect(row)), ','))
        end
    end
    return path
end

function svg_escape(s)::String
    return replace(
        string(s), '&' => "&amp;", '<' => "&lt;", '>' => "&gt;", '"' => "&quot;"
    )
end

"""
    save_horizontal_bars_svg(path, labels, vals, title; xlabel="Value")

Xuất biểu đồ cột ngang chuẩn SVG thuần Julia không phụ thuộc thư viện đồ họa ngoài.
"""
function save_horizontal_bars_svg(
    path::AbstractString,
    labels::Vector{String},
    vals::Vector{Float64},
    title::String;
    xlabel::String="Value",
)
    length(labels) == length(vals) || error("Labels and values mismatch")
    n = length(vals)
    width, left, barwidth, rowheight = 760, 340, 340, 30
    height = max(180, 92 + n * rowheight)
    maximum_val = isempty(vals) ? 1.0 : max(maximum(vals), eps())
    mkpath(dirname(path))

    open(path, "w") do io
        println(
            io,
            "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"$width\" " *
            "height=\"$height\" viewBox=\"0 0 $width $height\" " *
            "style=\"max-width:100%;height:auto;\">",
        )
        println(io, "<rect width=\"100%\" height=\"100%\" fill=\"white\"/>")
        println(
            io,
            "<text x=\"18\" y=\"28\" font-family=\"Arial\" font-size=\"17\" " *
            "font-weight=\"bold\">$(svg_escape(title))</text>",
        )
        for i in 1:n
            y = 50 + (i - 1) * rowheight
            bar_w = round(Int, vals[i] / maximum_val * barwidth)
            lbl = svg_escape(labels[i])
            val_str = @sprintf("%.3f", vals[i])
            println(
                io,
                "<text x=\"$(left - 8)\" y=\"$(y + 15)\" text-anchor=\"end\" " *
                "font-family=\"Arial\" font-size=\"11.5\">$lbl</text>",
            )
            println(
                io,
                "<rect x=\"$left\" y=\"$y\" height=\"20\" width=\"$bar_w\" " *
                "rx=\"3\" fill=\"#3366a6\"/>",
            )
            println(
                io,
                "<text x=\"$(left + bar_w + 6)\" y=\"$(y + 15)\" " *
                "font-family=\"Arial\" font-size=\"11.5\">$val_str</text>",
            )
        end
        println(
            io,
            "<text x=\"$left\" y=\"$(height - 12)\" font-family=\"Arial\" " *
            "font-size=\"12\">$(svg_escape(xlabel))</text>",
        )
        println(io, "</svg>")
    end
    return path
end

function parse_kv_args(args::Vector{String}, defaults::Dict{String, String})
    options = copy(defaults)
    i = 1
    while i <= length(args)
        key = args[i]
        if !haskey(options, key)
            allowed = join(sort!(collect(keys(options))), ", ")
            error("Unknown argument $key; expected $allowed")
        end
        i < length(args) || error("Missing value for $key")
        options[key] = args[i + 1]
        i += 2
    end
    return options
end

"""
    print_top_rules_table(csv_path::AbstractString; limit::Int=10)

In bảng Top-`limit` luật kết hợp từ file CSV theo định dạng căn cột dễ đọc.
"""
function print_top_rules_table(csv_path::AbstractString; limit::Int=10)
    lines = readlines(csv_path)
    length(lines) <= 1 && (println("(Không có luật nào)"); return nothing)
    rows = [split(line, ",") for line in lines[2:min(end, limit + 1)]]
    rule_strs = ["$(r[1]) => $(r[2])" for r in rows]
    w = max(24, maximum(length, rule_strs))
    sep = "-"^(w + 43)
    println(sep)
    println(
        rpad("#", 3),
        " | ",
        rpad("Luật kết hợp (A => B)", w),
        " | ",
        lpad("Count", 5),
        " | ",
        lpad("Supp", 6),
        " | ",
        lpad("Conf", 6),
        " | ",
        lpad("Lift", 4),
        " | ",
        lpad("Lev", 6),
    )
    println(sep)
    for (i, r) in enumerate(rows)
        cnt = parse(Int, r[3])
        sup = 100.0 * parse(Float64, r[4])
        conf = 100.0 * parse(Float64, r[5])
        lift = parse(Float64, r[6])
        lev = parse(Float64, r[7])
        @printf(
            "%2d  | %s | %5d | %5.2f%% | %5.2f%% | %4.2f | %6.4f\n",
            i,
            rpad(rule_strs[i], w),
            cnt,
            sup,
            conf,
            lift,
            lev,
        )
    end
    println(sep)
    return nothing
end

"""
    print_accuracy_table(csv_path::AbstractString)

In bảng so sánh độ chính xác phân loại Nearest-Centroid theo định dạng căn cột.
"""
function print_accuracy_table(csv_path::AbstractString)
    lines = readlines(csv_path)
    length(lines) <= 1 && return nothing
    sep = "-"^56
    println(sep)
    println(
        rpad("Representation", 28),
        " | ",
        lpad("Features", 8),
        " | ",
        lpad("Test Accuracy", 13),
    )
    println(sep)
    for line in lines[2:end]
        r = split(line, ",")
        n_feat = parse(Int, r[2])
        acc = 100.0 * parse(Float64, r[3])
        @printf("%-28s | %8d | %12.2f%%\n", r[1], n_feat, acc)
    end
    println(sep)
    return nothing
end

"""
    print_enrichment_table(csv_path::AbstractString; limit::Int=10)

In bảng Top-`limit` pattern ảnh đặc trưng theo chỉ số `Enrichment` căn cột dễ đọc.
"""
function print_enrichment_table(csv_path::AbstractString; limit::Int=10)
    lines = readlines(csv_path)
    length(lines) <= 1 && return nothing
    rows = [split(line, ",") for line in lines[2:min(end, limit + 1)]]
    w = max(14, maximum(r -> length(r[1]), rows))
    sep = "-"^(w + 54)
    println(sep)
    println(
        rpad("#", 3),
        " | ",
        lpad("Digit", 5),
        " | ",
        rpad("Visual Pattern", w),
        " | ",
        lpad("Count", 5),
        " | ",
        lpad("Global", 6),
        " | ",
        lpad("Class", 6),
        " | ",
        lpad("Enrich", 6),
    )
    println(sep)
    for (i, r) in enumerate(rows)
        digit = parse(Int, r[2])
        cnt = parse(Int, r[3])
        gsup = 100.0 * parse(Float64, r[4])
        csup = 100.0 * parse(Float64, r[5])
        enr = parse(Float64, r[6])
        @printf(
            "%2d  | %5d | %s | %5d | %5.1f%% | %5.1f%% | %5.2fx\n",
            i,
            digit,
            rpad(r[1], w),
            cnt,
            gsup,
            csup,
            enr,
        )
    end
    println(sep)
    return nothing
end

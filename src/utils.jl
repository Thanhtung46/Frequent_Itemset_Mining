# Đọc/ghi dữ liệu theo định dạng chuẩn SPMF và các hàm tiện ích hỗ trợ `negFIN`.

const SPMF_SUP_TAG = "#SUP:"

"""
    resolve_min_sup_count(n_transactions::Int, min_sup::Real) -> Int

Quy đổi ngưỡng hỗ trợ tối thiểu `min_sup` sang số giao dịch tuyệt đối.
- Nếu `min_sup` là số thực trong `(0, 1]`: tính `ceil(Int, min_sup * n_transactions)`
  (khớp với quy ước `Math.ceil(minsup * databaseSize)` của SPMF).
- Nếu `min_sup` là số nguyên (`Integer`) hoặc `> 1`: dùng trực tiếp làm ngưỡng tuyệt đối.

# Arguments
- `n_transactions`: Tổng số giao dịch trong CSDL.
- `min_sup`: Ngưỡng hỗ trợ tối thiểu (tương đối hoặc tuyệt đối).

# Returns
- `Int`: Ngưỡng số lượng giao dịch tối thiểu (>= 1 nếu `min_sup > 0`).
"""
function resolve_min_sup_count(n_transactions::Int, min_sup::Real)::Int
    if n_transactions <= 0
        return 1
    end
    if min_sup isa AbstractFloat && 0.0 < min_sup <= 1.0
        # Khử sai số dấu phẩy động kiểu 0.14 * 100 = 14.000000000000002
        scaled = round(min_sup * n_transactions; digits=12)
        return max(1, ceil(Int, scaled))
    elseif min_sup <= 0
        return 1
    else
        return ceil(Int, min_sup)
    end
end

"""
    read_spmf_database(filepath::AbstractString) -> Vector{Vector{Int}}

Đọc cơ sở dữ liệu giao dịch (transaction database) theo định dạng chuẩn SPMF.
Mỗi dòng hợp lệ gồm các mã item kiểu `Int` phân tách bởi khoảng trắng.

# Arguments
- `filepath`: Đường dẫn tới file `.txt` chuẩn SPMF.

# Returns
- `Vector{Vector{Int}}`: Danh sách các giao dịch; bỏ qua dòng trống và dòng metadata
  (`@`, `#`, `%`).
"""
function read_spmf_database(filepath::AbstractString)::Vector{Vector{Int}}
    transactions = Vector{Vector{Int}}()
    open(filepath, "r") do io
        for line in eachline(io)
            stripped = strip(line)
            if isempty(stripped) ||
               startswith(stripped, '@') ||
               startswith(stripped, '#') ||
               startswith(stripped, '%')
                continue
            end
            items = [parse(Int, token) for token in split(stripped)]
            if !isempty(items)
                push!(transactions, items)
            end
        end
    end
    return transactions
end

"""
    write_spmf_results(filepath::AbstractString, results::Vector{Tuple{Vector{Int}, Int}})

Ghi danh sách tập phổ biến (frequent itemsets) ra file theo định dạng chuẩn SPMF:
`item1 item2 ... #SUP: support`, với các item trong từng tập được sắp xếp tăng dần.

# Arguments
- `filepath`: Đường dẫn file đầu ra.
- `results`: Danh sách các cặp `(itemset, support_count)`.
"""
function write_spmf_results(
    filepath::AbstractString,
    results::Vector{Tuple{Vector{Int}, Int}},
)
    open(filepath, "w") do io
        for (itemset, sup) in results
            sorted_items = sort(itemset)
            println(io, join(sorted_items, " "), " ", SPMF_SUP_TAG, " ", sup)
        end
    end
    return nothing
end

"""
    read_spmf_results(filepath::AbstractString) -> Dict{Vector{Int}, Int}

Đọc file kết quả tập phổ biến theo định dạng chuẩn SPMF (`item1 item2 #SUP: count`)
thành bảng tra cứu `Dict{Vector{Int}, Int}` (các item đã sắp tăng dần) để đối chiếu.

# Arguments
- `filepath`: Đường dẫn file kết quả SPMF.

# Returns
- `Dict{Vector{Int}, Int}`: Ánh xạ từ tập item đã sắp xếp tới giá trị `support`.
"""
function read_spmf_results(filepath::AbstractString)::Dict{Vector{Int}, Int}
    result_map = Dict{Vector{Int}, Int}()
    open(filepath, "r") do io
        for line in eachline(io)
            stripped = strip(line)
            if isempty(stripped)
                continue
            end
            parts = split(stripped, SPMF_SUP_TAG)
            if length(parts) != 2
                continue
            end
            items = sort!([parse(Int, tok) for tok in split(strip(parts[1]))])
            sup = parse(Int, strip(parts[2]))
            result_map[items] = sup
        end
    end
    return result_map
end

"""
    results_to_dict(results::Vector{Tuple{Vector{Int}, Int}}) -> Dict{Vector{Int}, Int}

Chuẩn hóa danh sách kết quả `(itemset, sup)` thành `Dict{Vector{Int}, Int}` với itemset
được sắp xếp tăng dần. Báo lỗi nếu phát hiện itemset trùng lặp.
"""
function results_to_dict(
    results::Vector{Tuple{Vector{Int}, Int}},
)::Dict{Vector{Int}, Int}
    result_map = Dict{Vector{Int}, Int}()
    sizehint!(result_map, length(results))
    for (itemset, sup) in results
        key = sort(itemset)
        if haskey(result_map, key)
            error("Phát hiện itemset trùng lặp trong kết quả: $key")
        end
        result_map[key] = sup
    end
    return result_map
end

"""
    compare_results(res_a, res_b) -> Tuple{Bool, String}

So sánh hai tập kết quả frequent itemsets (có thể là `Vector{Tuple{Vector{Int}, Int}}`
hoặc `Dict{Vector{Int}, Int}`). Trả về `(true, "MATCH 100%")` nếu khớp hoàn toàn cả
số lượng lẫn `support` của từng tập.
"""
function compare_results(
    res_a::Union{Vector{Tuple{Vector{Int}, Int}}, Dict{Vector{Int}, Int}},
    res_b::Union{Vector{Tuple{Vector{Int}, Int}}, Dict{Vector{Int}, Int}},
)::Tuple{Bool, String}
    dict_a = res_a isa Dict ? res_a : results_to_dict(res_a)
    dict_b = res_b isa Dict ? res_b : results_to_dict(res_b)

    if length(dict_a) != length(dict_b)
        only_a = setdiff(keys(dict_a), keys(dict_b))
        only_b = setdiff(keys(dict_b), keys(dict_a))
        msg = "Khác số lượng itemsets: A=$(length(dict_a)), B=$(length(dict_b)); " *
              "chỉ có ở A=$(length(only_a)), chỉ có ở B=$(length(only_b))"
        return (false, msg)
    end

    for (k, v) in dict_a
        if !haskey(dict_b, k)
            return (false, "Thiếu itemset $k trong kết quả B")
        elseif dict_b[k] != v
            return (false, "Sai support cho $k: A=$v vs B=$(dict_b[k])")
        end
    end
    return (true, "MATCH 100% ($(length(dict_a)) itemsets)")
end

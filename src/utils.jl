"""
Đọc/ghi dữ liệu theo định dạng chuẩn SPMF và các hàm tiện ích hỗ trợ `negFIN`.
"""

const SPMF_SUP_TAG = "#SUP:"

"""
    read_spmf_database(filepath::AbstractString) -> Vector{Vector{Int}}

Đọc cơ sở dữ liệu giao dịch (transaction database) theo định dạng chuẩn SPMF.
Mỗi dòng hợp lệ gồm các mã item kiểu `Int` phân tách bởi khoảng trắng.

# Arguments
- `filepath`: Đường dẫn tới file `.txt` chuẩn SPMF.

# Returns
- `Vector{Vector{Int}}`: Danh sách các giao dịch; bỏ qua dòng trống và dòng metadata (`@`, `#`, `%`).
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

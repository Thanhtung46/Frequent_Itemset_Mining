# src/io.jl

"""
Đọc cơ sở dữ liệu giao dịch theo định dạng chuẩn SPMF.
Trả về danh sách các giao dịch (Vector{Vector{Int}}).
"""
function read_spmf_database(filepath::String)::Vector{Vector{Int}}
    transactions = Vector{Vector{Int}}()
    open(filepath, "r") do io
        for line in eachline(io)
            s = strip(line)
            # Bỏ qua dòng trống hoặc dòng metadata của SPMF (@CONVERTED_FROM_TEXT, #...)
            if isempty(s) || startswith(s, '@') || startswith(s, '#') || startswith(s, '%')
                continue
            end
            # Tách các item theo khoảng trắng và chuyển sang Int
            items = [parse(Int, token) for token in split(s)]
            push!(transactions, items)
        end
    end
    return transactions
end

"""
Ghi danh sách tập phổ biến ra file theo định dạng chuẩn SPMF:
item1 item2 ... #SUP: support
"""
function write_spmf_results(filepath::String, results::Vector{Tuple{Vector{Int}, Int}})
    open(filepath, "w") do io
        for (itemset, sup) in results
            println(io, join(itemset, " "), " #SUP: ", sup)
        end
    end
end
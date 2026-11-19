"""
Phiên bản cài đặt cơ bản (Baseline) của thuật toán `negFIN` (Aryabarzan et al., 2018),
bám sát giả mã Algorithm 1–4 trong bài báo gốc bằng `BitVector`.
"""

"""
    _build_bmc_tree_baseline(transactions, min_sup_count)

Cài đặt Algorithm 1 (`constructing_BMC_tree`) trong bài báo gốc:
1. Quét CSDL tìm tập frequent 1-itemsets `F1`.
2. Sắp xếp `L1` theo thứ tự support tăng dần (Definition 2).
3. Chèn từng giao dịch (đã lọc infrequent items và sắp theo thứ tự ngược `L1`) vào BMC-tree.

# Returns
- `(root, l1_items, l1_supports)`: Nút gốc BMC-tree, vector mã item `L1` và support tương ứng.
"""
function _build_bmc_tree_baseline(
    transactions::Vector{Vector{Int}},
    min_sup_count::Int,
)
    # Bước 1: Quét CSDL tìm F1 (loại bỏ item trùng lặp trong cùng một giao dịch)
    item_counts = Dict{Int, Int}()
    seen = Set{Int}()
    for tx in transactions
        empty!(seen)
        for item in tx
            if !(item in seen)
                push!(seen, item)
                item_counts[item] = get(item_counts, item, 0) + 1
            end
        end
    end

    # Lọc các item phổ biến F1
    freq_pairs = [(item, cnt) for (item, cnt) in item_counts if cnt >= min_sup_count]
    if isempty(freq_pairs)
        empty_root = BMCNodeBaseline(0, 0, falses(0), BMCNodeBaseline[])
        return (empty_root, Int[], Int[])
    end

    # Definition 2: L1 sắp xếp theo thứ tự support tăng dần (phá hòa theo item_id)
    sort!(freq_pairs; by=p -> (p[2], p[1]))
    n_f = length(freq_pairs)
    l1_items = [p[1] for p in freq_pairs]
    l1_supports = [p[2] for p in freq_pairs]

    # Ánh xạ item_id -> vị trí 1-based trong L1 (tương ứng bit_index = pos - 1)
    item_to_pos = Dict{Int, Int}()
    sizehint!(item_to_pos, n_f)
    for (pos, item) in enumerate(l1_items)
        item_to_pos[item] = pos
    end

    # Property 3: Tất cả các bit trong bitmap_code của nút gốc đều bằng 0
    root = BMCNodeBaseline(0, 0, falses(n_f), BMCNodeBaseline[])

    # Chèn từng giao dịch vào BMC-tree theo thứ tự ngược L1 (support giảm dần)
    tx_positions = Int[]
    for tx in transactions
        empty!(tx_positions)
        empty!(seen)
        for item in tx
            pos = get(item_to_pos, item, 0)
            if pos != 0 && !(pos in seen)
                push!(seen, pos)
                push!(tx_positions, pos)
            end
        end
        if isempty(tx_positions)
            continue
        end
        # Sắp xếp giảm dần theo vị trí trong L1 (tức thứ tự L1^reverse)
        sort!(tx_positions; rev=true)

        current = root
        for pos in tx_positions
            found = nothing
            for child in current.children
                if child.item_pos == pos
                    found = child
                    break
                end
            end
            if found === nothing
                # Property 4: N.bitmap_code = father.bitmap_code | 2^index(i)
                new_bitmap = copy(current.bitmap_code)
                new_bitmap[pos] = true
                new_node = BMCNodeBaseline(pos, 1, new_bitmap, BMCNodeBaseline[])
                push!(current.children, new_node)
                current = new_node
            else
                found.count += 1
                current = found
            end
        end
    end

    return (root, l1_items, l1_supports)
end

"""
    _extract_nodesets_baseline!(nodesets, node)

Duyệt BMC-tree (Algorithm 3, dòng 4–6) để trích xuất `Nodeset` cho mọi 1-itemset phổ biến.
"""
function _extract_nodesets_baseline!(
    nodesets::Vector{Vector{NInfoBaseline}},
    node::BMCNodeBaseline,
)
    for child in node.children
        push!(nodesets[child.item_pos], NInfoBaseline(child.bitmap_code, child.count))
        _extract_nodesets_baseline!(nodesets, child)
    end
    return nothing
end

"""
    _generate_fis_subsets(item_id, equivalent_items, fis_parent)

Cài đặt trực tiếp Algorithm 4 (dòng 39–45): sinh tập `FIS_N` từ `item_id`,
tập các phần tử tương đương `equivalent_items` (Property 9) và `fis_parent`.
"""
function _generate_fis_subsets(
    item_id::Int,
    equivalent_items::Vector{Int},
    fis_parent::Vector{Vector{Int}},
)::Vector{Vector{Int}}
    # Tạo tất cả tập con của equivalent_items ghép với {item_id} (PSet)
    p_set = Vector{Vector{Int}}()
    push!(p_set, [item_id])
    for eq_item in equivalent_items
        current_len = length(p_set)
        for idx in 1:current_len
            new_subset = copy(p_set[idx])
            push!(new_subset, eq_item)
            push!(p_set, new_subset)
        end
    end

    if isempty(fis_parent)
        return p_set
    end

    fis_n = Vector{Vector{Int}}()
    sizehint!(fis_n, length(p_set) * length(fis_parent))
    for p1 in p_set
        for p2 in fis_parent
            merged = Vector{Int}(undef, length(p1) + length(p2))
            copyto!(merged, 1, p2, 1, length(p2))
            copyto!(merged, length(p2) + 1, p1, 1, length(p1))
            push!(fis_n, merged)
        end
    end
    return fis_n
end

"""
    _construct_frequent_itemset_tree_baseline!(...)

Cài đặt đệ quy Algorithm 4 (`constructing_frequent_itemset_tree`) cho các tầng `k >= 2`.
"""
function _construct_frequent_itemset_tree_baseline!(
    results::Vector{Tuple{Vector{Int}, Int}},
    l1_items::Vector{Int},
    min_sup_count::Int,
    node_item_pos::Int,
    node_support::Int,
    siblings::Vector{ItemsetNodeBaseline},
    sibling_idx::Int,
    fis_parent::Vector{Vector{Int}},
)
    children = ItemsetNodeBaseline[]
    equivalent_items = Int[]

    # Chỉ cần duyệt các nút anh em bên phải (i > node_item_pos) ở cùng mức cha
    for right_idx in (sibling_idx + 1):length(siblings)
        right_sib = siblings[right_idx]
        cand_pos = right_sib.item_pos

        # Property 7 (Algorithm 4, dòng 16–23):
        # Trích NegNodeset(R = ijX) từ NegNodeset(Q = iX) với bit của j bằng 1
        r_neg_nodeset = NInfoBaseline[]
        r_neg_support = 0
        for ni in right_sib.neg_nodeset
            if ni.bitmap_code[node_item_pos]
                push!(r_neg_nodeset, ni)
                r_neg_support += ni.count
            end
        end

        # Property 6 & Property 8: support(R) = support(P) - support(R')
        r_support = node_support - r_neg_support

        if r_support == node_support
            # Property 9 (Superset Equivalence / Promotion)
            push!(equivalent_items, l1_items[cand_pos])
        elseif r_support >= min_sup_count
            push!(children, ItemsetNodeBaseline(cand_pos, r_support, r_neg_nodeset))
        end
    end

    # Algorithm 4 (dòng 39–46): Sinh toàn bộ frequent itemsets tại nút hiện tại
    fis_n = _generate_fis_subsets(l1_items[node_item_pos], equivalent_items, fis_parent)
    for itemset in fis_n
        push!(results, (itemset, node_support))
    end

    # Đệ quy mở rộng sang các nút con
    for child_idx in eachindex(children)
        child = children[child_idx]
        _construct_frequent_itemset_tree_baseline!(
            results,
            l1_items,
            min_sup_count,
            child.item_pos,
            child.support,
            children,
            child_idx,
            fis_n,
        )
    end
    return nothing
end

"""
    negfin_baseline(transactions::Vector{Vector{Int}}, min_sup::Real) -> Vector{Tuple{Vector{Int}, Int}}

Khai thác toàn bộ tập phổ biến (frequent itemsets) bằng thuật toán `negFIN` phiên bản cơ bản
(bám sát Algorithm 1–4 của Aryabarzan et al., 2018).

# Arguments
- `transactions`: Cơ sở dữ liệu giao dịch.
- `min_sup`: Ngưỡng hỗ trợ tối thiểu (tỷ lệ trong `(0, 1]` hoặc số giao dịch nguyên).

# Returns
- `Vector{Tuple{Vector{Int}, Int}}`: Danh sách tất cả `(itemset, support_count)` phổ biến.
"""
function negfin_baseline(
    transactions::Vector{Vector{Int}},
    min_sup::Real,
)::Vector{Tuple{Vector{Int}, Int}}
    results = Vector{Tuple{Vector{Int}, Int}}()
    n_tx = length(transactions)
    if n_tx == 0
        return results
    end

    min_sup_count = resolve_min_sup_count(n_tx, min_sup)

    # Bước 1 (Algorithm 1 & Algorithm 3 dòng 2–6): Xây BMC-tree và trích Nodesets
    root, l1_items, l1_supports = _build_bmc_tree_baseline(transactions, min_sup_count)
    n_f = length(l1_items)
    if n_f == 0
        return results
    end

    nodesets = [NInfoBaseline[] for _ in 1:n_f]
    _extract_nodesets_baseline!(nodesets, root)
    # BMC-tree không còn cần thiết sau khi trích Nodesets của 1-itemsets
    root = nothing

    # Bước 2 & 3 (Algorithm 3 dòng 12–19 & Algorithm 4):
    # Duyệt từng nút ở tầng 1 của cây liệt kê tập phổ biến
    empty_parent = Vector{Vector{Int}}()
    for pos in 1:n_f
        p_support = l1_supports[pos]
        p_nodeset = nodesets[pos]
        children = ItemsetNodeBaseline[]
        equivalent_items = Int[]

        # Tầng 2 (Definition 10, Algorithm 4 dòng 8–14):
        # Trích NegNodeset(iP) từ Nodeset(P) với bit của item i bằng 0
        for cand_pos in (pos + 1):n_f
            r_neg_nodeset = NInfoBaseline[]
            r_neg_support = 0
            for ni in p_nodeset
                if !ni.bitmap_code[cand_pos]
                    push!(r_neg_nodeset, ni)
                    r_neg_support += ni.count
                end
            end

            r_support = p_support - r_neg_support
            if r_support == p_support
                # Property 9: Promotion
                push!(equivalent_items, l1_items[cand_pos])
            elseif r_support >= min_sup_count
                push!(children, ItemsetNodeBaseline(cand_pos, r_support, r_neg_nodeset))
            end
        end

        fis_n = _generate_fis_subsets(l1_items[pos], equivalent_items, empty_parent)
        for itemset in fis_n
            push!(results, (itemset, p_support))
        end

        for child_idx in eachindex(children)
            child = children[child_idx]
            _construct_frequent_itemset_tree_baseline!(
                results,
                l1_items,
                min_sup_count,
                child.item_pos,
                child.support,
                children,
                child_idx,
                fis_n,
            )
        end
    end

    return results
end

# Phiên bản tối ưu hóa (Optimized) của thuật toán `negFIN` (Aryabarzan et al., 2018),
# tận dụng các đặc trưng hiệu năng của Julia:
# 1. Multiple Dispatch theo số lượng frequent 1-itemsets `nf`:
#    `UInt64` (<=64), `UInt128` (<=128), `NTuple{3,UInt64}` (<=192),
#    `NTuple{4,UInt64}` (<=256), `Vector{UInt64}` (>256).
# 2. Cây BMC-tree biểu diễn LCRS (`BMCNodeOpt{B}`) giảm cấp phát nút lá.
# 3. Cấu trúc `NodeSetOpt{B}` dạng SoA (Structure-of-Arrays) + `@inbounds`.
# 4. Cắt sớm (Early-Abort) ngay khi `neg_support` vượt quá `parent_support - min_sup_count`.
# 5. Xuất tập phổ biến không cấp phát `FIS_parent` bằng hai stack phẳng `prefix`
#    và `equiv_stack`.

"""
    _build_bmc_tree_opt(::Type{B}, transactions, l1_items, item_to_pos, n_words)

Xây dựng cây BMC-tree tối ưu (Algorithm 1) sử dụng kiểu bitmap cụ thể `B`
và biểu diễn Left-Child Right-Sibling (`BMCNodeOpt{B}`).
"""
function _build_bmc_tree_opt(
    ::Type{B},
    transactions::Vector{Vector{Int}},
    item_to_pos::Dict{Int, Int32},
    n_f::Int,
    n_words::Int,
) where {B}
    # Property 3: Nút gốc có toàn bộ bit bằng 0
    root_bitmap = make_zero_bitmap(B, n_words)
    root = BMCNodeOpt{B}(Int32(0), Int32(0), root_bitmap, nothing, nothing)

    # Bộ đệm tái sử dụng cho từng giao dịch để loại bỏ cấp phát trong vòng lặp
    tx_positions = Int32[]
    sizehint!(tx_positions, min(n_f, 128))
    seen_stamp = zeros(Int32, n_f)
    current_stamp = Int32(0)

    for tx in transactions
        current_stamp += Int32(1)
        empty!(tx_positions)

        @inbounds for item in tx
            pos = get(item_to_pos, item, Int32(0))
            if pos != Int32(0) && seen_stamp[pos] != current_stamp
                seen_stamp[pos] = current_stamp
                push!(tx_positions, pos)
            end
        end

        n_len = length(tx_positions)
        if n_len == 0
            continue
        end
        if n_len > 1
            # Sắp xếp giảm dần theo vị trí trong L1 (thứ tự L1^reverse)
            sort!(tx_positions; rev=true)
        end

        current = root
        @inbounds for idx in 1:n_len
            pos = tx_positions[idx]
            child = current.first_child
            found = nothing
            while child !== nothing
                if child.item_pos == pos
                    found = child
                    break
                end
                child = child.next_sibling
            end

            if found === nothing
                # Property 4: N.bitmap_code = father.bitmap_code | 2^index(i)
                new_bitmap = set_bit(current.bitmap, Int(pos))
                new_node = BMCNodeOpt{B}(
                    pos, Int32(1), new_bitmap, nothing, current.first_child
                )
                current.first_child = new_node
                current = new_node
            else
                found.count += Int32(1)
                current = found
            end
        end
    end

    return root
end

"""
    _extract_nodesets_opt!(nodesets, root)

Duyệt BMC-tree không đệ quy bằng stack (Algorithm 3, dòng 4–6) để trích `Nodeset`
cho từng 1-itemset phổ biến, tránh tràn stack khi cây sâu.
"""
function _extract_nodesets_opt!(
    nodesets::Vector{NodeSetOpt{B}},
    root::BMCNodeOpt{B},
) where {B}
    stack = BMCNodeOpt{B}[]
    child = root.first_child
    while child !== nothing
        push!(stack, child)
        child = child.next_sibling
    end

    while !isempty(stack)
        node = pop!(stack)
        ns = @inbounds nodesets[node.item_pos]
        push!(ns.bitmaps, node.bitmap)
        push!(ns.counts, node.count)

        c = node.first_child
        while c !== nothing
            push!(stack, c)
            c = c.next_sibling
        end
    end
    return nothing
end

"""
    _emit_promoted_itemsets!(emit_fn, prefix, equiv_stack, start_idx, support)

Sinh và xuất toàn bộ tổ hợp `prefix ∪ S` với mọi `S ⊆ equiv_stack` có cùng `support`
(theo Property 9: Superset Equivalence), không cần cấp phát ma trận `FIS_parent`.
"""
function _emit_promoted_itemsets!(
    emit_fn::F,
    prefix::Vector{Int},
    equiv_stack::Vector{Int},
    start_idx::Int,
    support::Int,
) where {F}
    emit_fn(prefix, support)
    n_eq = length(equiv_stack)
    @inbounds for idx in start_idx:n_eq
        push!(prefix, equiv_stack[idx])
        _emit_promoted_itemsets!(emit_fn, prefix, equiv_stack, idx + 1, support)
        pop!(prefix)
    end
    return nothing
end

"""
    _mine_level_k_opt!(...)

Duyệt đệ quy các tầng `k >= 2` của cây tìm kiếm tập phổ biến (Algorithm 4) với:
- SoA `NodeSetOpt{B}` và bộ định vị bit tính sẵn ngoài vòng lặp.
- Early-abort khi `neg_support > max_neg_sup`.
- Không cấp phát `FIS_parent` nhờ duy trì `prefix` và `equiv_stack`.
"""
function _mine_level_k_opt!(
    emit_fn::F,
    ::Type{B},
    l1_items::Vector{Int},
    min_sup_count::Int32,
    node_item_pos::Int32,
    node_support::Int32,
    siblings::Vector{FTreeChildOpt{B}},
    sibling_idx::Int,
    prefix::Vector{Int},
    equiv_stack::Vector{Int},
) where {F, B}
    n_sibs = length(siblings)
    children = FTreeChildOpt{B}[]
    prev_eq_len = length(equiv_stack)
    max_neg_sup = node_support - min_sup_count

    # Tính sẵn locator của bit j = node_item_pos một lần duy nhất ngoài vòng lặp
    j_loc = bit_locator(B, Int(node_item_pos))

    @inbounds for right_idx in (sibling_idx + 1):n_sibs
        right_sib = siblings[right_idx]
        q_ns = right_sib.neg_nodeset
        q_bitmaps = q_ns.bitmaps
        q_counts = q_ns.counts
        q_len = length(q_counts)

        # Property 7: Trích NegNodeset(ijX) từ NegNodeset(iX) với bit j == 1
        # Kết hợp Early-Abort: dừng ngay khi neg_sup > max_neg_sup
        neg_sup = Int32(0)
        aborted = false
        r_bitmaps = Vector{B}()
        r_counts = Vector{Int32}()

        for k in 1:q_len
            bm = q_bitmaps[k]
            if is_bit_one(bm, j_loc)
                cnt = q_counts[k]
                neg_sup += cnt
                if neg_sup > max_neg_sup
                    aborted = true
                    break
                end
                push!(r_bitmaps, bm)
                push!(r_counts, cnt)
            end
        end

        if aborted
            continue
        end

        # Property 8: support(R) = support(P) - neg_sup
        if neg_sup == Int32(0)
            # Property 9 (Promotion): R.support == P.support
            push!(equiv_stack, l1_items[right_sib.item_pos])
        else
            r_support = node_support - neg_sup
            push!(
                children,
                FTreeChildOpt{B}(
                    right_sib.item_pos,
                    r_support,
                    NodeSetOpt{B}(r_bitmaps, r_counts),
                ),
            )
        end
    end

    # Xuất tất cả các frequent itemsets thuộc nút hiện tại (cùng support = node_support)
    _emit_promoted_itemsets!(emit_fn, prefix, equiv_stack, 1, Int(node_support))

    # Đệ quy sang các nút con
    n_children = length(children)
    @inbounds for c_idx in 1:n_children
        child = children[c_idx]
        push!(prefix, l1_items[child.item_pos])
        _mine_level_k_opt!(
            emit_fn,
            B,
            l1_items,
            min_sup_count,
            child.item_pos,
            child.support,
            children,
            c_idx,
            prefix,
            equiv_stack,
        )
        pop!(prefix)
    end

    # Khôi phục equiv_stack về trạng thái của nút cha
    resize!(equiv_stack, prev_eq_len)
    return nothing
end

"""
    _run_negfin_typed!(emit_fn, ::Type{B}, transactions, l1_items, l1_supports,
                       item_to_pos, min_sup_count)

Hàm lõi chuyên biệt hóa theo kiểu bitmap `B` (function barrier giúp Julia biên dịch
mã máy tối ưu không có dynamic dispatch).
"""
function _run_negfin_typed!(
    emit_fn::F,
    ::Type{B},
    transactions::Vector{Vector{Int}},
    l1_items::Vector{Int},
    l1_supports::Vector{Int32},
    item_to_pos::Dict{Int, Int32},
    min_sup_count::Int32,
) where {F, B}
    n_f = length(l1_items)
    n_words = cld(n_f, 64)

    # Bước 1: Xây BMC-tree và trích Nodesets của các 1-itemsets
    root = _build_bmc_tree_opt(B, transactions, item_to_pos, n_f, n_words)
    nodesets = [NodeSetOpt{B}() for _ in 1:n_f]
    _extract_nodesets_opt!(nodesets, root)
    root = nothing

    # Tính sẵn toàn bộ bit locators cho 1..n_f
    locators = [bit_locator(B, pos) for pos in 1:n_f]

    prefix = Int[]
    equiv_stack = Int[]
    sizehint!(prefix, min(n_f, 64))
    sizehint!(equiv_stack, min(n_f, 64))

    # Bước 2 & 3: Duyệt tầng 1 của cây liệt kê tập phổ biến
    @inbounds for pos in 1:n_f
        p_support = l1_supports[pos]
        p_ns = nodesets[pos]
        p_bitmaps = p_ns.bitmaps
        p_counts = p_ns.counts
        p_len = length(p_counts)
        max_neg_sup = p_support - min_sup_count

        children = FTreeChildOpt{B}[]
        empty!(equiv_stack)

        # Tầng 2 (Definition 10): Trích NegNodeset(iP) từ Nodeset(P) với bit i == 0
        for cand_pos in (pos + 1):n_f
            c_loc = locators[cand_pos]
            neg_sup = Int32(0)
            aborted = false
            r_bitmaps = Vector{B}()
            r_counts = Vector{Int32}()

            for k in 1:p_len
                bm = p_bitmaps[k]
                if is_bit_zero(bm, c_loc)
                    cnt = p_counts[k]
                    neg_sup += cnt
                    if neg_sup > max_neg_sup
                        aborted = true
                        break
                    end
                    push!(r_bitmaps, bm)
                    push!(r_counts, cnt)
                end
            end

            if aborted
                continue
            end

            if neg_sup == Int32(0)
                # Property 9: Promotion
                push!(equiv_stack, l1_items[cand_pos])
            else
                r_support = p_support - neg_sup
                push!(
                    children,
                    FTreeChildOpt{B}(
                        Int32(cand_pos),
                        r_support,
                        NodeSetOpt{B}(r_bitmaps, r_counts),
                    ),
                )
            end
        end

        # Xuất các itemset thuộc nút tầng 1 này
        push!(prefix, l1_items[pos])
        _emit_promoted_itemsets!(emit_fn, prefix, equiv_stack, 1, Int(p_support))

        # Đệ quy sang tầng >= 3
        n_children = length(children)
        for c_idx in 1:n_children
            child = children[c_idx]
            push!(prefix, l1_items[child.item_pos])
            _mine_level_k_opt!(
                emit_fn,
                B,
                l1_items,
                min_sup_count,
                child.item_pos,
                child.support,
                children,
                c_idx,
                prefix,
                equiv_stack,
            )
            pop!(prefix)
        end
        pop!(prefix)

        # Giải phóng sớm Nodeset đã duyệt xong để giảm Peak RAM
        nodesets[pos] = NodeSetOpt{B}()
    end

    return nothing
end

"""
    negfin_optimized(emit_fn::Function, transactions::Vector{Vector{Int}}, min_sup::Real)

Chạy thuật toán `negFIN` bản tối ưu ở chế độ streaming: gọi `emit_fn(itemset, sup)`
cho mỗi tập phổ biến tìm được (lưu ý: `itemset` là buffer tái sử dụng, cần `copy(itemset)`
nếu lưu lại).
"""
function negfin_optimized(
    emit_fn::F,
    transactions::Vector{Vector{Int}},
    min_sup::Real,
) where {F}
    n_tx = length(transactions)
    if n_tx == 0
        return nothing
    end

    min_sup_count = Int32(resolve_min_sup_count(n_tx, min_sup))

    # Quét CSDL đếm support 1-itemsets (loại bỏ trùng lặp trong cùng giao dịch)
    item_counts = Dict{Int, Int32}()
    seen = Set{Int}()
    for tx in transactions
        empty!(seen)
        for item in tx
            if !(item in seen)
                push!(seen, item)
                item_counts[item] = get(item_counts, item, Int32(0)) + Int32(1)
            end
        end
    end

    freq_pairs = [(item, cnt) for (item, cnt) in item_counts if cnt >= min_sup_count]
    if isempty(freq_pairs)
        return nothing
    end

    # Definition 2: L1 sắp xếp theo thứ tự support tăng dần (phá hòa theo item_id)
    sort!(freq_pairs; by=p -> (p[2], p[1]))
    n_f = length(freq_pairs)
    l1_items = [p[1] for p in freq_pairs]
    l1_supports = [p[2] for p in freq_pairs]

    item_to_pos = Dict{Int, Int32}()
    sizehint!(item_to_pos, n_f)
    for (pos, item) in enumerate(l1_items)
        item_to_pos[item] = Int32(pos)
    end

    # Function barrier: chọn kiểu bitmap tối ưu theo số lượng frequent 1-itemsets nf
    if n_f <= 64
        _run_negfin_typed!(
            emit_fn, UInt64, transactions, l1_items, l1_supports, item_to_pos, min_sup_count
        )
    elseif n_f <= 128
        _run_negfin_typed!(
            emit_fn,
            UInt128,
            transactions,
            l1_items,
            l1_supports,
            item_to_pos,
            min_sup_count,
        )
    elseif n_f <= 192
        _run_negfin_typed!(
            emit_fn,
            NTuple{3, UInt64},
            transactions,
            l1_items,
            l1_supports,
            item_to_pos,
            min_sup_count,
        )
    elseif n_f <= 256
        _run_negfin_typed!(
            emit_fn,
            NTuple{4, UInt64},
            transactions,
            l1_items,
            l1_supports,
            item_to_pos,
            min_sup_count,
        )
    else
        _run_negfin_typed!(
            emit_fn,
            Vector{UInt64},
            transactions,
            l1_items,
            l1_supports,
            item_to_pos,
            min_sup_count,
        )
    end

    return nothing
end

"""
    negfin_optimized(transactions::Vector{Vector{Int}}, min_sup::Real)

Khai thác toàn bộ tập phổ biến bằng thuật toán `negFIN` bản tối ưu và trả về danh sách
các cặp `(itemset, support_count)`.
"""
function negfin_optimized(
    transactions::Vector{Vector{Int}},
    min_sup::Real,
)::Vector{Tuple{Vector{Int}, Int}}
    results = Vector{Tuple{Vector{Int}, Int}}()
    negfin_optimized(transactions, min_sup) do itemset, sup
        push!(results, (copy(itemset), sup))
    end
    return results
end

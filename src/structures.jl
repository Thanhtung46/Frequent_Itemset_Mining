"""
Cấu trúc dữ liệu cốt lõi cho thuật toán `negFIN` (Aryabarzan et al., 2018):
BMC-tree (BitMap Coding tree), N-info, Nodeset và NegNodeset định kiểu cụ thể.
"""

# ==============================================================================
# 1. CẤU TRÚC CHO PHIÊN BẢN CƠ BẢN (BASELINE) — SỬ DỤNG BitVector
# ==============================================================================

"""
    BMCNodeBaseline

Nút trên cây BMC-tree (Definition 6, Aryabarzan et al., 2018) cho bản cơ bản.
- `item_pos`: Vị trí 1-based của item trong vector `L1` (`0` đối với nút gốc).
- `count`: Số giao dịch đi qua đường đi `node-path` tới nút này.
- `bitmap_code`: Mã hóa nhị phân `BMC(node-path)` kích thước `nf = |F1|`.
- `children`: Danh sách nút con.
"""
mutable struct BMCNodeBaseline
    item_pos::Int
    count::Int
    bitmap_code::BitVector
    children::Vector{BMCNodeBaseline}
end

"""
    NInfoBaseline

Cặp thông tin `N-info = (bitmap_code, count)` của một nút trên BMC-tree
(Definition 8, Aryabarzan et al., 2018).
"""
struct NInfoBaseline
    bitmap_code::BitVector
    count::Int
end

"""
    ItemsetNodeBaseline

Nút trên cây liệt kê tập phổ biến (Set-Enumeration / Frequent Itemset Tree,
Definition 11) cho bản cơ bản.
"""
struct ItemsetNodeBaseline
    item_pos::Int
    support::Int
    neg_nodeset::Vector{NInfoBaseline}
end

# ==============================================================================
# 2. CẤU TRÚC CHO PHIÊN BẢN TỐI ƯU (OPTIMIZED) — BIT-PACKING + MULTIPLE DISPATCH
# ==============================================================================

"""
    

Nút trên cây BMC-tree cho bản tối ưu, sử dụng biểu diễn Left-Child Right-Sibling
(LCRS) để tránh cấp phát `Vector` rỗng cho hàng triệu nút lá trên dữ liệu thưa.
Kiểu bitmap `B` được chuyên biệt hóa bằng Multiple Dispatch (`UInt64`, `UInt128`,
`NTuple{N, UInt64}`, hoặc `Vector{UInt64}`).
"""
mutable struct BMCNodeOpt{B}
    item_pos::Int32
    count::Int32
    bitmap::B
    first_child::Union{Nothing, BMCNodeOpt{B}}
    next_sibling::Union{Nothing, BMCNodeOpt{B}}
end

"""
    NodeSetOpt{B}

Biểu diễn `Nodeset` hoặc `NegNodeset` theo bố cục Structure-of-Arrays (SoA):
tách rời mảng `bitmaps::Vector{B}` và `counts::Vector{Int32}` để tăng tính cục bộ
bộ nhớ đệm (CPU cache locality) khi quét tuyến tính.
"""
struct NodeSetOpt{B}
    bitmaps::Vector{B}
    counts::Vector{Int32}
end

NodeSetOpt{B}() where {B} = NodeSetOpt{B}(Vector{B}(), Vector{Int32}())

Base.length(ns::NodeSetOpt) = length(ns.counts)
Base.isempty(ns::NodeSetOpt) = isempty(ns.counts)

"""
    FTreeChildOpt{B}

Thông tin rút gọn của một nút con trong cây tìm kiếm tập phổ biến cho bản tối ưu.
"""
struct FTreeChildOpt{B}
    item_pos::Int32
    support::Int32
    neg_nodeset::NodeSetOpt{B}
end

# ==============================================================================
# 3. MULTIPLE DISPATCH CHO THAO TÁC BIT-PACKING (PROPERTY 3 & PROPERTY 4)
# ==============================================================================

"""
    make_zero_bitmap(::Type{B}, n_words::Int) -> B

Khởi tạo mã bitmap toàn bit 0 cho nút gốc BMC-tree (Property 3).
"""
@inline make_zero_bitmap(::Type{UInt64}, ::Int) = UInt64(0)
@inline make_zero_bitmap(::Type{UInt128}, ::Int) = UInt128(0)
@inline function make_zero_bitmap(::Type{NTuple{N, UInt64}}, ::Int) where {N}
    return ntuple(_ -> UInt64(0), Val(N))
end
@inline make_zero_bitmap(::Type{Vector{UInt64}}, n_words::Int) = zeros(UInt64, n_words)

"""
    set_bit(b::B, pos::Int) -> B

Bật bit ứng với item ở vị trí 1-based `pos` (bit thứ `pos - 1` theo chỉ số 0-based).
Cài đặt Property 4: `N.bitmap_code = father.bitmap_code | 2^index(i)`.
"""
@inline set_bit(b::UInt64, pos::Int) = b | (UInt64(1) << (pos - 1))
@inline set_bit(b::UInt128, pos::Int) = b | (UInt128(1) << (pos - 1))

@inline function set_bit(b::NTuple{N, UInt64}, pos::Int) where {N}
    zero_idx = pos - 1
    target_word = (zero_idx >> 6) + 1
    mask = UInt64(1) << (zero_idx & 63)
    return ntuple(
        w -> w == target_word ? (@inbounds b[w] | mask) : (@inbounds b[w]),
        Val(N),
    )
end

@inline function set_bit(b::Vector{UInt64}, pos::Int)
    out = copy(b)
    zero_idx = pos - 1
    word_idx = (zero_idx >> 6) + 1
    mask = UInt64(1) << (zero_idx & 63)
    @inbounds out[word_idx] |= mask
    return out
end

"""
    bit_locator(::Type{B}, pos::Int)

Tính sẵn mặt nạ bit (và chỉ số word nếu cần) ngoài vòng lặp nóng để kiểm tra bit
trong `O(1)` không tốn phép dịch bit lặp lại.
"""
@inline bit_locator(::Type{UInt64}, pos::Int) = UInt64(1) << (pos - 1)
@inline bit_locator(::Type{UInt128}, pos::Int) = UInt128(1) << (pos - 1)

@inline function bit_locator(::Type{NTuple{N, UInt64}}, pos::Int) where {N}
    zero_idx = pos - 1
    return ((zero_idx >> 6) + 1, UInt64(1) << (zero_idx & 63))
end

@inline function bit_locator(::Type{Vector{UInt64}}, pos::Int)
    zero_idx = pos - 1
    return ((zero_idx >> 6) + 1, UInt64(1) << (zero_idx & 63))
end

"""
    is_bit_zero(b::B, loc) -> Bool

Kiểm tra bit tại vị trí `loc` có bằng `0` hay không (dùng cho Definition 10 ở tầng 2).
"""
@inline is_bit_zero(b::UInt64, mask::UInt64) = (b & mask) == UInt64(0)
@inline is_bit_zero(b::UInt128, mask::UInt128) = (b & mask) == UInt128(0)
@inline function is_bit_zero(b::NTuple{N, UInt64}, loc::Tuple{Int, UInt64}) where {N}
    return (@inbounds b[loc[1]] & loc[2]) == UInt64(0)
end
@inline function is_bit_zero(b::Vector{UInt64}, loc::Tuple{Int, UInt64})
    return (@inbounds b[loc[1]] & loc[2]) == UInt64(0)
end

"""
    is_bit_one(b::B, loc) -> Bool

Kiểm tra bit tại vị trí `loc` có bằng `1` hay không (dùng cho Property 7 ở tầng >= 3).
"""
@inline is_bit_one(b::UInt64, mask::UInt64) = (b & mask) != UInt64(0)
@inline is_bit_one(b::UInt128, mask::UInt128) = (b & mask) != UInt128(0)
@inline function is_bit_one(b::NTuple{N, UInt64}, loc::Tuple{Int, UInt64}) where {N}
    return (@inbounds b[loc[1]] & loc[2]) != UInt64(0)
end
@inline function is_bit_one(b::Vector{UInt64}, loc::Tuple{Int, UInt64})
    return (@inbounds b[loc[1]] & loc[2]) != UInt64(0)
end

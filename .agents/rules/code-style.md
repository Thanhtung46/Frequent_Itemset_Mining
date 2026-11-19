---
trigger: always_on
---

# Quy Chuẩn Style Code Julia — Đồ Án FIM (`negFIN`)

File rule này quy định phong cách viết mã, tiêu chuẩn hiệu năng Julia và quy ước tài liệu cho toàn bộ mã nguồn trong dự án `Frequent_Itemset_Mining`.

---

## 1. Phong Cách Code (Julia BlueStyle)

- **Thụt lề & Độ dài dòng:** Dùng **4 dấu cách** (không dùng Tab). Giới hạn mỗi dòng tối đa **92 ký tự**.
- **Quy ước đặt tên (tiếng Anh):**
  - `PascalCase` (`CamelCase`): `struct`, `abstract type`, `module` (ví dụ: `BMCNode`, `NegNodeset`, `NInfo`).
  - `snake_case`: tên hàm, biến cục bộ, tên file `.jl` (ví dụ: `build_bmc_tree`, `min_sup_count`, `negfin_optimized.jl`).
  - `UPPER_SNAKE_CASE`: hằng số `const` (ví dụ: `DEFAULT_SEED`, `SPMF_SUP_TAG`).
  - Hàm làm thay đổi đối số tại chỗ (mutating function) **bắt buộc kết thúc bằng `!`** và đặt đối số bị sửa lên đầu (ví dụ: `insert_transaction!(root, tx, item_index)`).
  - Hàm kiểm tra điều kiện (predicate) bắt đầu bằng `is_` hoặc `has_` (ví dụ: `is_bit_set`, `has_children`).
- **Tổ chức file & module:**
  - Khai báo `using` / `import` ở đầu file; ưu tiên import tường minh (`using Test: @test, @testset`).
  - Tách biệt rõ: cấu trúc dữ liệu (`src/structures.jl`), bản cơ bản (`src/negfin_baseline.jl`), bản tối ưu (`src/negfin_optimized.jl`), I/O & tiện ích (`src/utils.jl`), CLI (`src/main.jl`).
  - Không viết Julia theo tư duy OOP của Java/Python (tránh nhét method vào trong struct hoặc tạo class wrapper rườm rà).

---

## 2. Hiệu Năng Julia-Native (Bắt Buộc Cho Bản Optimized)

- **Định kiểu cụ thể (Concrete Types):** Mọi trường trong `struct` phải có kiểu cụ thể hoặc tham số kiểu `T`; **tuyệt đối không** dùng `Any`, `AbstractVector`, hay kiểu trừu tượng trong `struct` và trong hot loop.
  ```julia
  # Tốt: tham số hóa concrete type
  struct NInfo{B}
      bitmap::B
      count::Int32
  end

  # Tránh: abstract type gây heap allocation & dynamic dispatch
  struct BadNInfo
      bitmap::Any
      count::Integer
  end
  ```
- **Không dùng biến toàn cục không `const`:** Mọi trạng thái chạy thuật toán (cây, kết quả, bộ đếm) phải truyền qua tham số hàm hoặc đóng gói trong `struct`.
- **Type Stability:** Giá trị trả về của hàm chỉ nên phụ thuộc vào kiểu của đầu vào, không phụ thuộc vào giá trị đầu vào. Kiểm tra các hàm lõi bằng `@code_warntype`.
- **Multiple Dispatch cho Bit-Packing:** Tận dụng Multiple Dispatch thay vì `if/else` theo kiểu trong vòng lặp nóng (ví dụ: chuyên biệt hóa thao tác bit cho `UInt64` khi $n_f \le 64$, `UInt128` khi $n_f \le 128$, và `Vector{UInt64}` / tuple word khi $n_f > 128$).
- **Tối ưu vòng lặp & Bộ nhớ:**
  - Chỉ dùng `@inbounds` khi đã đảm bảo chắc chắn chỉ số nằm trong biên; kết hợp `@simd` cho các vòng lặp cộng dồn/quét mảng độc lập dữ liệu.
  - Ưu tiên tái sử dụng buffer (`empty!(buf)`), Structure-of-Arrays (SoA) và ghi/xử lý dạng streaming để hạn chế cấp phát bộ nhớ và giảm áp lực Garbage Collector (GC).
  - Trong `negfin_optimized.jl`, áp dụng cắt sớm (early-abort) ngay khi cộng dồn `neg_support` vượt ngưỡng `parent_support - min_sup_count`.
- **Đo hiệu năng chuẩn xác:** Luôn chạy **warm-up** (1 lần chạy nháp để bỏ thời gian biên dịch JIT) trước khi bấm giờ hoặc đo `@allocated`.

---

## 3. Ngôn Ngữ Comment, Docstring & Ánh Xạ Bài Báo `negFIN`

- **Tên định danh:** 100% tiếng Anh rõ nghĩa, bám sát thuật ngữ gốc (`bmc_tree`, `nodeset`, `neg_nodeset`, `equivalent_items`, `min_sup`).
- **Docstring & Comment:** Viết bằng **tiếng Việt**, giữ nguyên thuật ngữ chuyên ngành tiếng Anh ở lần xuất hiện đầu tiên.
- **Docstring chuẩn Julia (`"""..."""`):** Bắt buộc có cho mọi hàm public và `struct` chính, gồm: mô tả ngắn, tham số (`Arguments`), giá trị trả về (`Returns`), và tham chiếu tới bài báo gốc.
- **Ánh xạ lý thuyết bài báo (Aryabarzan et al., 2018):** Với các bước lõi của `negFIN`, luôn ghi chú rõ đang cài đặt phần nào để phục vụ kiểm tra và vấn đáp:
  - Ví dụ: `# Theo Property 4: N.bitmap_code = father.bitmap_code | 2^index(i)`
  - Ví dụ: `# Theo Property 7 (Algorithm 4, dòng 16-23): trích NegNodeset(ijX) từ NegNodeset(iX)`
  - Ví dụ: `# Theo Property 9 (Superset Equivalence / Promotion): đẩy item tương đương vào equivalent_items`
- **Không comment thừa:** Giải thích *tại sao* (ý nghĩa toán học / lý do tối ưu), không diễn giải lại những dòng code hiển nhiên.

---

## 4. Reproducibility, I/O Chuẩn SPMF & Kiểm Thử

- **Tính tái lập (Reproducibility):** Mọi thao tác sinh dữ liệu tổng hợp, xáo trộn hoặc lấy mẫu phải nhận `seed::Int` tường minh và cố định qua `Random.MersenneTwister(seed)` hoặc `Random.seed!(seed)`.
- **Định dạng SPMF:**
  - Đầu vào: mỗi dòng là các số nguyên (`Int`) cách nhau bởi khoảng trắng; bỏ qua dòng trống và xử lý an toàn trường hợp trùng item trong cùng 1 giao dịch.
  - Đầu ra: mỗi dòng có dạng `item1 item2 ... #SUP: count`, với các item trong từng itemset được sắp xếp tăng dần để đối chiếu nhất quán 100% với `spmf.jar`.
- **Kiểm thử tự động (`tests/`):**
  - Mọi thay đổi trên thuật toán lõi phải chạy qua `julia --project=. tests/runtests.jl` và đạt **100% pass**.
  - Cả `negfin_baseline.jl` và `negfin_optimized.jl` phải cho kết quả khớp nhau tuyệt đối (100% số lượng itemset và `support` từng tập) và khớp 100% với `spmf.jar`.
- **Liêm chính học thuật:** 100% mã nguồn tự viết, không sao chép trực tiếp từ SPMF hay kho mã nguồn ngoài; mọi tối ưu đều phải đo đạc chứng minh được bằng số liệu thực nghiệm.

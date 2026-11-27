# Đồ Án Khai Thác Tập Phổ Biến (Frequent Itemset Mining) — `negFIN` (Julia)

Cài đặt, tối ưu hóa và đánh giá thực nghiệm thuật toán **negFIN** (*Aryabarzan, Minaei-Bidgoli & Teshnehlab, 2018 — Expert Systems With Applications, 105, 129–143*) hoàn toàn bằng ngôn ngữ **Julia ($\ge 1.9$)**.

---

## 1. Thông tin nhóm (2 thành viên)

| STT | Họ và tên | MSSV | Vai trò / Phụ trách chính |
| :---: | :--- | :---: | :--- |
| 1 | `[Họ và tên thành viên 1]` | `[MSSV 1]` | Cài đặt thuật toán `negFIN` (Baseline & Optimized), Unit Tests, CLI |
| 2 | `[Họ và tên thành viên 2]` | `[MSSV 2]` | Thực nghiệm Chương 2, Ứng dụng thực tế Chương 3, Báo cáo IEEE |

---

## 2. Liên kết Colab & Tài nguyên

| Tài nguyên | Liên kết | Ghi chú |
| :--- | :--- | :--- |
| **Google Colab (Chương 2)** | [![Open In Colab](https://colab.research.google.com/assets/colab-badge.svg)](https://colab.research.google.com/github/Thanhtung46/Frequent_Itemset_Mining/blob/main/notebooks/ch2_experiments.ipynb) | Chạy bằng **Julia Runtime**, tự động tải 5 bộ benchmark từ Hugging Face |
| **Google Colab (Demo Tổng hợp)** | `[Cập nhật link notebooks/demo.ipynb — Anyone with the link]` | Gộp Chương 2 + 2 Ứng dụng Chương 3 |
| **Bộ dữ liệu Benchmark (Hugging Face)** | https://huggingface.co/datasets/stephent9/Lab1_Frequent_Itemset_Mining | 5 bộ chuẩn SPMF: `chess`, `mushroom`, `accidents`, `retail`, `T10I4D100K` |
| **Bài báo gốc (`negFIN`)** | [DOI: 10.1016/j.eswa.2018.03.041](https://doi.org/10.1016/j.eswa.2018.03.041) | Aryabarzan et al. (2018), *negFIN: An efficient algorithm for fast mining frequent itemsets* |
| **Thư viện đối chiếu (`SPMF`)** | https://www.philippe-fournier-viger.com/spmf/ | Dùng `spmf.jar` làm chuẩn đối chiếu Ground Truth |

---

## 3. Cấu trúc thư mục dự án

```text
Frequent_Itemset_Mining/
├── README.md                     # Thông tin nhóm, hướng dẫn chạy, kết quả test, link Colab & Dataset
├── Project.toml                  # Khai báo môi trường & dependencies Julia
├── .agents/rules/
│   └── code-style.md             # Quy chuẩn style code Julia (BlueStyle + hiệu năng)
├── src/
│   ├── algorithm/                # Cài đặt chính thuật toán negFIN
│   │   ├── negfin_baseline.jl    # Phiên bản cơ bản bám sát giả mã Algorithm 1–4 (BitVector)
│   │   └── negfin_optimized.jl   # Phiên bản tối ưu (UInt64/UInt128/NTuple, Early-Abort, zero-alloc)
│   ├── main.jl                   # Entry-point xử lý CLI (--input, --output, --minsup, --algo, --stats)
│   ├── structures.jl             # Cấu trúc BMC-tree (LCRS), NodeSet (SoA), Multiple Dispatch bit-packing
│   └── utils.jl                  # Đọc/ghi chuẩn SPMF, đối chiếu kết quả 100%
├── scripts/
│   └── run_benchmarks.jl         # Script chạy tự động 6 thực nghiệm Chương 2, xuất CSV
├── tests/
│   ├── runtests.jl               # File chạy chính cho `julia --project=. tests/runtests.jl`
│   ├── test_correctness.jl       # Kiểm thử đúng đắn trên >= 7 CSDL & đối chiếu SPMF
│   └── test_benchmark.jl         # Đối chứng tốc độ & bộ nhớ Baseline vs. Optimized
├── data/
│   ├── toy/                      # Dữ liệu mẫu kiểm thử nhanh (`paper_example1.txt` — Table 1 bài báo)
│   ├── benchmark/                # 5 bộ dữ liệu chuẩn tải từ Hugging Face (bỏ qua trong .gitignore)
│   └── synthetic/                # Dữ liệu tổng hợp kiểm thử độ dài giao dịch & scalability
├── notebooks/
│   └── ch2_experiments.ipynb     # Notebook Pure Julia chạy thực nghiệm & vẽ 5 biểu đồ 300 DPI
├── results/
│   ├── logs/                     # Bảng số liệu CSV của 6 thực nghiệm Chương 2
│   └── figures/                  # Biểu đồ độ phân giải cao (PNG 300 DPI) chèn báo cáo IEEE
├── spmf/                         # Đặt `spmf.jar` tại đây khi chạy đối chiếu SPMF ở local
└── docs/                         # Báo cáo chuẩn IEEE (`Report.pdf`)
```

---

## 4. Hướng dẫn cài đặt & chạy

### Yêu cầu môi trường
- **Julia $\ge 1.9$** (khuyến nghị Julia 1.11 LTS hoặc mới hơn).
- *(Tùy chọn)* **Java Runtime (JDK 21/25)** và file `spmf/spmf.jar` nếu muốn chạy đối chiếu trực tiếp với SPMF ở local.

### Bước 1: Clone repository & khởi tạo môi trường
```bash
git clone https://github.com/Thanhtung46/Frequent_Itemset_Mining.git
cd Frequent_Itemset_Mining
julia --project=. -e 'using Pkg; Pkg.instantiate()'
```

### Bước 2: Chạy bộ kiểm thử tự động (Unit Tests)
```bash
julia --project=. tests/runtests.jl
```

### Bước 3: Chạy thuật toán `negFIN` qua dòng lệnh (CLI)
```bash
# Chạy bản tối ưu (mặc định) và in thống kê thời gian chạy
julia --project=. src/main.jl \
    --input data/toy/paper_example1.txt \
    --output results/out.txt \
    --minsup 0.4 \
    --algo optimized \
    --stats

# Chạy bản cơ bản (Baseline) để đối chiếu
julia --project=. src/main.jl \
    --input data/toy/paper_example1.txt \
    --output results/out_base.txt \
    --minsup 0.4 \
    --algo baseline \
    --stats
```

### Bước 4: Chạy toàn bộ 6 thực nghiệm Chương 2
- **Cách 1 (Khuyên dùng — Google Colab / Jupyter Julia Kernel):** Mở [notebooks/ch2_experiments.ipynb](notebooks/ch2_experiments.ipynb) và chọn **Run All** (tự động tải 5 bộ dữ liệu từ Hugging Face, chạy benchmark và vẽ toàn bộ biểu đồ).
- **Cách 2 (Chạy CLI trên máy local sau khi đã có 5 file trong `data/benchmark/`):**
```bash
julia --project=. scripts/run_benchmarks.jl
```

---

## 5. Kết quả chạy Unit Test gần nhất

```text
$ julia --project=. tests/runtests.jl

--- ĐỐI CHỨNG HIỆU NĂNG: BASELINE vs. OPTIMIZED ---
Dataset                      | Base (ms) |  Opt (ms) | Speedup |  Base (MB) |   Opt (MB)
--------------------------------------------------------------------------------------
Dense-64 (UInt64)            |     11.44 |      3.30 |   3.47x |      33.61 |      11.35
Dense-120 (UInt128)          |     24.60 |      4.31 |   5.71x |      86.00 |      24.89
Sparse-400 (Vector{UInt64})  |      3.70 |      2.32 |   1.59x |      13.33 |       3.39
--------------------------------------------------------------------------------------
Test Summary:     | Pass  Total  Time
NegFIN Test Suite |   29     29  3.8s
```


---

## 6. Chương 3 – Hai ứng dụng thuần Julia

**Không cần cài Python / pandas / scikit-learn / OpenCV để chạy Chương 3.** Hai ứng dụng gọi trực tiếp thuật toán negFIN trong `src/algorithm/` (code nhóm giữ nguyên). Dữ liệu ảnh Digits CSV nằm sẵn trong repo; dữ liệu Groceries tự tải khi chạy lần đầu.

### Chạy trên Windows PowerShell hoặc terminal của VS Code (tại repo root)

```powershell
julia --version
julia --project=. tests/test_ch3_julia.jl
julia --project=. applications/run_market.jl
julia --project=. applications/run_visual.jl
```

- Đổi ngưỡng / cách chạy: `julia --project=. applications/run_market.jl --minsup 0.01 --minconf 0.15 --algo baseline`
- Đổi số visual words: `julia --project=. applications/run_visual.jl --minsup 0.12 --words 16 --seed 42`
- Đối chứng bản tối ưu: thêm `--algo optimized` cho từng ứng dụng.
- Kết quả thực nghiệm tạo tại `results/chapter3/` dưới dạng CSV, SPMF, SVG và summary. Mở SVG bằng trình duyệt để xem biểu đồ.

### Demo trên Google Colab

[**Mở demo Chương 3 trên Colab**](https://colab.research.google.com/github/Thanhtung46/Frequent_Itemset_Mining/blob/main/notebooks/demo.ipynb) — **chỉ hoạt động sau khi nhóm push các file mới lên GitHub** và đặt quyền truy cập công khai. Notebook dùng kernel Python của Colab nhưng chỉ chạy các lệnh shell để cài và gọi Julia, không có thuật toán Python.

### Nội dung để báo cáo / vấn đáp

Xem [docs/Chapter3_notes.md](docs/Chapter3_notes.md) để giải thích dữ liệu, quy trình, lý do chọn thuật toán và giới hạn. Ứng dụng thị giác dùng local **dense gradient descriptors** + Julia K-means tự cài, **không phải SIFT**. Kết quả phải được kiểm chứng khi chạy thực tế; nhóm cần tự ghi output kiểm thử và hai ứng dụng vào README trước khi nộp.

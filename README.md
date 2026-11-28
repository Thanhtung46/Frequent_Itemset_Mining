# Đồ Án Khai Thác Tập Phổ Biến (Frequent Itemset Mining) — `negFIN`

Cài đặt, tối ưu hóa, đánh giá thực nghiệm và xây dựng hai ứng dụng thực tế cho thuật toán **negFIN** (*Aryabarzan, Minaei-Bidgoli & Teshnehlab, 2018 — Expert Systems With Applications, 105, 129–143*) **bằng ngôn ngữ Julia**.

---

## 1. Thông tin nhóm

| STT | Họ và tên | MSSV | Vai trò / Phụ trách chính |
| :---: | :--- | :---: | :--- |
| 1 | `Nguyễn Thanh Tùng` | `24127583` | Cài đặt thuật toán `negFIN` (Baseline & Optimized), Unit Tests, CLI, Thực nghiệm Chương 2 |
| 2 | `Nguyễn Tuấn Khanh` | `24127415` | Ứng dụng thực tế Chương 3, Báo cáo |

---

## 2. Liên kết Google Colab & Tài nguyên

Toàn bộ notebook trong `notebooks/colab/` đều chạy trực tiếp bằng **Google Colab Julia Runtime** (*Runtime $\rightarrow$ Change runtime type $\rightarrow$ `Julia`*).

| Tài nguyên | Liên kết | Ghi chú |
| :--- | :--- | :--- |
| **Colab — Chương 2 (6 Thực nghiệm)** | [![Open In Colab](https://colab.research.google.com/assets/colab-badge.svg)](https://colab.research.google.com/drive/1-dBP14MTu5VC3g5ecyyPokXDAO3sRoe1?usp=sharing) | Tự động tải 5 bộ benchmark từ Hugging Face, chạy benchmark & vẽ 6 biểu đồ |
| **Colab — Chương 3 (Ứng dụng 1: Market Basket)** | [![Open In Colab](https://colab.research.google.com/assets/colab-badge.svg)](https://colab.research.google.com/drive/11A0g25vqiupDo2DAzdnVjGf4Z3aqIXFG?usp=sharing) | Phân tích giỏ hàng `Groceries` + Top-10 luật theo `Lift` + biểu đồ SVG |
| **Colab — Chương 3 (Ứng dụng 2: Visual Words)** | [![Open In Colab](https://colab.research.google.com/assets/colab-badge.svg)](https://colab.research.google.com/github/Thanhtung46/18/blob/main/notebooks/colab/03_ch3_app2_visual_words.ipynb) | Bag of Visual Words trên `UCI Digits 8×8` + đánh giá *Nearest-Centroid* |
| **Colab — Chương 3 (Demo gộp cả 2 ứng dụng)** | [![Open In Colab](https://colab.research.google.com/assets/colab-badge.svg)](https://colab.research.google.com/drive/1Ci1hyDFa5AJnIjzlHDYl0wQaxaKnRkv9?usp=sharing) | Chạy kiểm thử + đầy đủ 2 ứng dụng Chương 3 trong 1 notebook duy nhất |
| **Bộ dữ liệu Benchmark & Chương 3 (Hugging Face)** | https://huggingface.co/datasets/stephent9/Lab1_Frequent_Itemset_Mining | 5 bộ Ch.2 (`chess`, `mushroom`, `accidents`, `retail`, `T10I4D100K`) + 2 bộ Ch.3 (`groceries.csv`, `digits8x8.csv`) |
| **Bài báo gốc (`negFIN`)** | [DOI: 10.1016/j.eswa.2018.03.041](https://www.philippe-fournier-viger.com/spmf/NEGFINarticle.pdf) | Aryabarzan et al. (2018), *negFIN: An efficient algorithm for fast mining frequent itemsets* |
| **Thư viện đối chiếu (`SPMF`)** | https://www.philippe-fournier-viger.com/spmf/ | Dùng `spmf.jar` (`NegFIN`) làm Ground Truth kiểm chứng 100% |

> **Ghi chú về nguồn gốc dữ liệu (*Data Provenance & Mirror*):** Toàn bộ 7 bộ dữ liệu thực nghiệm được thu thập nguyên vẹn từ các nguồn học thuật công khai chuẩn:
> - **Chương 2 (5 bộ benchmark):** [SPMF / FIMI Public Datasets](https://www.philippe-fournier-viger.com/spmf/index.php?link=datasets.php) (`chess`, `mushroom`, `accidents`, `retail`, `T10I4D100K`).
> - **Chương 3 — `Groceries`:** gói R [`arules` (Hahsler et al., 2006)](https://michael.hahsler.net/arules/reference/Groceries.html).
> - **Chương 3 — `Digits 8×8`:** [UCI Machine Learning Repository — Optical Recognition of Handwritten Digits](https://archive.ics.uci.edu/dataset/80/optical+recognition+of+handwritten+digits) (xuất qua [`sklearn.datasets.load_digits`](https://scikit-learn.org/stable/modules/generated/sklearn.datasets.load_digits.html)).
> - **Bản sao lưu công khai (*Public Mirror*):** Toàn bộ 7 tệp nguyên bản được lưu trữ tại [Hugging Face (`stephent9/Lab1_Frequent_Itemset_Mining`)](https://huggingface.co/datasets/stephent9/Lab1_Frequent_Itemset_Mining) nhằm đảm bảo tốc độ tải ổn định và khả năng tái lập (*reproducibility*) 100% khi chạy trên Google Colab.

---

## 3. Cấu trúc thư mục dự án

| Thư mục / Tệp | Phạm vi | Vai trò chính |
| :--- | :---: | :--- |
| `src/algorithm/`, `structures.jl`, `utils.jl`, `main.jl` | Chương 1 | Lõi thuật toán `negFIN` (Baseline & Optimized), BMC-tree, CLI |
| `scripts/`, `notebooks/*/01_*` | Chương 2 | Chạy 6 thực nghiệm benchmark trên 5 CSDL chuẩn & sinh biểu đồ |
| `src/applications/`, `notebooks/*/02..04_*` | Chương 3 | 2 ứng dụng thực tế: Market Basket Analysis & Visual Words |
| `tests/` | Kiểm thử | Bộ test tự động **66/66 PASS** (Chương 1, SPMF & Chương 3) |
| `data/` | Dữ liệu | Tập toy, 5 benchmark FIMI/SPMF và dữ liệu ứng dụng Chương 3 |
| `results/` | Kết quả | File CSV thực nghiệm, **9 biểu đồ** báo cáo & đầu ra Chương 3 |
| `docs/` | Báo cáo | Mã nguồn LaTeX (`Report.tex`), PDF (`Report.pdf`) & hình ảnh |
| `spmf/` | Đối chiếu | Nơi đặt `spmf.jar` khi chạy kiểm chứng chéo `SPMF NegFIN` ở local |

```text
18/
├── README.md                      # Tổng quan, hướng dẫn cài đặt & kết quả kiểm thử
├── Project.toml                   # Khai báo môi trường & thư viện Julia (theo nhóm)
│
├── src/                           # Mã nguồn thuần Julia của dự án
│   ├── structures.jl              # BMC-tree (LCRS), NodeSet (SoA), bit-packing
│   ├── utils.jl                   # Đọc/ghi chuẩn SPMF & hàm đối chiếu compare_results
│   ├── main.jl                    # CLI Chương 1 (--input, --output, --minsup, --algo)
│   ├── algorithm/                 # Lõi thuật toán negFIN (Chương 1)
│   │   ├── negfin_baseline.jl     # Bản cơ bản bám sát giả mã Algorithm 1–4
│   │   └── negfin_optimized.jl    # Bản tối ưu (UInt64/128/NTuple, Early-Abort)
│   └── applications/              # 2 ứng dụng thực tế thuần Julia (Chương 3)
│       ├── applications.jl        # Module Applications nạp trực tiếp negFIN
│       ├── app_utils.jl           # Cầu nối negFIN, validate_support, in bảng, SVG
│       ├── market_basket.jl       # Ứng dụng 1: Phân tích giỏ hàng & luật kết hợp
│       ├── visual_words.jl        # Ứng dụng 2: Gradient, K-means, Bag of Visual Words
│       ├── run_market_basket.jl   # CLI chạy Ứng dụng 1
│       └── run_visual_words.jl    # CLI chạy Ứng dụng 2
│
├── scripts/
│   └── run_benchmarks.jl          # Tự động chạy 6 thực nghiệm Chương 2 & xuất CSV
│
├── tests/
│   ├── runtests.jl                # Bộ test Chương 1 (39/39 PASS, gồm đối chiếu SPMF)
│   ├── test_correctness.jl        # Kiểm thử đúng đắn 7 CSDL/trường hợp biên & SPMF
│   ├── test_benchmark.jl          # Đối chứng tốc độ & bộ nhớ Baseline vs. Optimized
│   └── test_ch3_julia.jl          # Kiểm thử tích hợp 2 ứng dụng Chương 3 (27/27 PASS)
│
├── notebooks/                     # 8 Notebook 100% Pure Julia (Colab & Local)
│   ├── colab/                     # Tự clone repo & tải dữ liệu từ Hugging Face
│   │   ├── 01_ch2_experiments.ipynb
│   │   ├── 02_ch3_app1_market_basket.ipynb
│   │   ├── 03_ch3_app2_visual_words.ipynb
│   │   └── 04_ch3_all_applications.ipynb
│   └── local/                     # Chạy trực tiếp trên máy cá nhân, không cần setup
│       ├── 01_ch2_experiments.ipynb
│       ├── 02_ch3_app1_market_basket.ipynb
│       ├── 03_ch3_app2_visual_words.ipynb
│       └── 04_ch3_all_applications.ipynb
│
├── data/
│   ├── toy/                       # Dữ liệu mẫu kiểm thử nhanh (paper_example1.txt)
│   ├── benchmark/                 # 5 CSDL chuẩn tải từ Hugging Face (.gitignore)
│   └── chapter3/                  # digits8x8.csv, SOURCE.md, groceries.csv (tự tải)
│
├── results/
│   ├── logs/                      # Bảng số liệu CSV 6 thực nghiệm (exp1..exp6.csv)
│   ├── figures/                   # 9 biểu đồ báo cáo (6 PNG Chương 2 + 3 SVG Chương 3)
│   └── chapter3/                  # Đầu ra Chương 3 (summary, CSV, SPMF, SVG)
│
├── docs/
│   ├── Report.tex                 # Mã nguồn báo cáo IEEE hai cột (XeLaTeX)
│   ├── Report.pdf                 # Bản báo cáo PDF hoàn chỉnh (10 trang)
│   └── figures/                   # Bộ hình PNG xuất cho báo cáo LaTeX
│
└── spmf/                          # Đặt spmf.jar tại đây khi đối chiếu SPMF ở local
```

---

## 4. Hướng dẫn cài đặt & chạy

### Yêu cầu môi trường
- **Julia $\ge 1.9$** (khuyến nghị Julia 1.11 LTS hoặc mới hơn).
- *(Tùy chọn)* **Java Runtime (JDK 21+)** và file `spmf/spmf.jar` nếu muốn chạy đối chiếu trực tiếp với `SPMF NegFIN` ở local.

### Bước 1: Clone repository & cài đặt môi trường (chạy 1 lần)
```bash
git clone https://github.com/Thanhtung46/18.git
cd 18
julia --project=. -e 'using Pkg; Pkg.instantiate()'
```
*(Thư viện lõi `negFIN` chỉ dùng Julia stdlib; `CSV`, `DataFrames`, `Plots` trong `Project.toml` chỉ phục vụ đọc bảng số liệu và vẽ biểu đồ Chương 2.)*

### Bước 2: Chạy toàn bộ bộ kiểm thử tự động (66/66 PASS)
```bash
julia --project=. tests/runtests.jl
julia --project=. tests/test_ch3_julia.jl
```

### Bước 3: Chạy thuật toán `negFIN` qua dòng lệnh (Chương 1 — CLI)
```bash
# Bản tối ưu (mặc định) kèm thống kê thời gian & số lượng tập phổ biến
julia --project=. src/main.jl \
    --input data/toy/paper_example1.txt \
    --output results/out.txt \
    --minsup 0.4 \
    --algo optimized \
    --stats

# Bản cơ bản (Baseline) để đối chiếu
julia --project=. src/main.jl \
    --input data/toy/paper_example1.txt \
    --output results/out_base.txt \
    --minsup 0.4 \
    --algo baseline \
    --stats
```

### Bước 4: Chạy 6 thực nghiệm & vẽ 5 biểu đồ (Chương 2)
- **Google Colab:** Mở [notebooks/colab/01_ch2_experiments.ipynb](notebooks/colab/01_ch2_experiments.ipynb) $\rightarrow$ chọn **Julia Runtime** $\rightarrow$ **Run all**.
- **Local Notebook:** Mở [notebooks/local/01_ch2_experiments.ipynb](notebooks/local/01_ch2_experiments.ipynb) bằng **Julia Kernel** $\rightarrow$ **Run All**.
- **Local CLI** *(sau khi đã có 5 file trong `data/benchmark/`)*:
```bash
julia --project=. scripts/run_benchmarks.jl
```

### Bước 5: Chạy 2 ứng dụng thực tế thuần Julia (Chương 3)
- **Google Colab:** Mở [notebooks/colab/04_ch3_all_applications.ipynb](notebooks/colab/04_ch3_all_applications.ipynb) (hoặc từng notebook `02` / `03`) $\rightarrow$ chọn **Julia Runtime** $\rightarrow$ **Run all**.
- **Local Notebook:** Mở [notebooks/local/04_ch3_all_applications.ipynb](notebooks/local/04_ch3_all_applications.ipynb) (hoặc `02` / `03`) bằng **Julia Kernel** $\rightarrow$ **Run All**.
- **Local CLI:**
```bash
# Ứng dụng 1: Phân tích giỏ hàng Groceries (mặc định minsup=0.01, minconf=0.15)
julia --project=. src/applications/run_market_basket.jl --minsup 0.01 --minconf 0.15 --algo optimized

# Ứng dụng 2: Bag of Visual Words trên UCI Digits 8x8 (mặc định minsup=0.12, words=16, seed=42)
julia --project=. src/applications/run_visual_words.jl --minsup 0.12 --words 16 --seed 42 --algo optimized
```
*(Đổi `--algo optimized` thành `--algo baseline` nếu muốn đối chứng hai phiên bản.)*

---

## 5. Kết quả kiểm thử đã xác nhận (66/66 PASS)

### Bộ test lõi `negFIN` + đối chiếu 100% SPMF (`tests/runtests.jl`)
```text
--- ĐỐI CHIẾU 100% VỚI SPMF (spmf.jar / negFIN) ---
  [SPMF] Paper Example 1 (40.0%):        Base=MATCH 100% (12 itemsets)  | Opt=MATCH 100% (12 itemsets)
  [SPMF] Identical-Promo (8 items, 50%): Base=MATCH 100% (255 itemsets) | Opt=MATCH 100% (255 itemsets)
  [SPMF] Non-Contiguous IDs (35.0%):     Base=MATCH 100% (12 itemsets)  | Opt=MATCH 100% (12 itemsets)
  [SPMF] Synthetic Dense-40 (15.0%):     Base=MATCH 100% (43 itemsets)  | Opt=MATCH 100% (43 itemsets)
  [SPMF] Synthetic Sparse-120 (8.0%):    Base=MATCH 100% (77 itemsets)  | Opt=MATCH 100% (77 itemsets)

--- ĐỐI CHỨNG HIỆU NĂNG: BASELINE vs. OPTIMIZED ---
Dataset                      | Base (ms) |  Opt (ms) | Speedup |  Base (MB) |   Opt (MB)
--------------------------------------------------------------------------------------
Dense-64 (UInt64)            |     11.63 |      3.00 |   3.88x |      33.61 |      11.35
Dense-120 (UInt128)          |     48.35 |      4.62 |  10.46x |      86.00 |      24.89
Sparse-400 (Vector{UInt64})  |      3.64 |      2.27 |   1.61x |      13.33 |       3.39
--------------------------------------------------------------------------------------
NegFIN Test Suite            |   39 / 39 PASS
```

### Bộ test ứng dụng Chương 3 (`tests/test_ch3_julia.jl`)
```text
Chapter 3 Julia applications |   27 / 27 PASS
```

---

## 6. Tóm tắt hai ứng dụng Chương 3 (100% Pure Julia)

Cả hai ứng dụng gọi trực tiếp `negfin_optimized` / `negfin_baseline` qua module `Applications` (`src/applications/applications.jl`), **không sử dụng Python hay thư viện FIM bên ngoài**, và kiểm chứng chéo 100% bằng `validate_support`:

| Ứng dụng | Dữ liệu & Pipeline | Kết quả tiêu biểu | Biểu đồ & Log đầu ra |
| :--- | :--- | :--- | :--- |
| **1. Market Basket Analysis** | `Groceries` (9,835 giao dịch, 169 sản phẩm; tự tải vào `data/chapter3/groceries.csv`) $\rightarrow$ `negFIN` (`minsup=0.01`) $\rightarrow$ sinh luật (`minconf=0.15`) & xếp hạng `Lift` | **333** tập phổ biến, **322** luật kết hợp (`support PASS`, ~0.24s). Top Lift: `curd => whole milk + yogurt` (`Lift = 3.37`, `Conf = 18.89%`) | `results/figures/ch3_top10_lift.svg`, `results/chapter3/market_basket/{summary.txt, top10_lift.csv, association_rules.csv}` |
| **2. Bag of Visual Words** | `UCI Digits 8×8` (`data/chapter3/digits8x8.csv`, 448 train / 152 test, 4 lớp `0,1,3,8`) $\rightarrow$ 9 dense gradient patches 6D/ảnh $\rightarrow$ K-means (`K=16`, `seed=42`, chỉ fit trên train) $\rightarrow$ `negFIN` (`minsup=0.12`) $\rightarrow$ Enrichment & *Nearest-Centroid* | **154** tập phổ biến, **60** tổ hợp từ thị giác (`support PASS`); *Enrichment* tối đa **4.00×** (lớp `0`); *Nearest-Centroid* accuracy: **79.61%** (words) vs. **78.95%** (+FIM patterns) | `results/figures/ch3_enriched_patterns.svg`, `results/figures/ch3_digits_samples.svg`, `results/chapter3/visual_words/{summary.txt, patterns_by_class.csv, test_accuracy_comparison.csv}` |

**Lưu ý phương pháp:**
- Chỉ số `Lift > 1` ở Ứng dụng 1 phản ánh **tương quan thống kê dương**, không chứng minh quan hệ nhân quả.
- Ứng dụng 2 sử dụng **dense gradient descriptors tự cài** trên ảnh 8×8 (không phải SIFT/ORB hay tập ảnh độ phân giải cao như Caltech-101/CIFAR).



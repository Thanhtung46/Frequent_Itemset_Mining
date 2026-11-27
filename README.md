# Đồ Án Khai Thác Tập Phổ Biến (Frequent Itemset Mining) — `negFIN` (Julia)

Cài đặt, tối ưu hóa và đánh giá thực nghiệm thuật toán **negFIN** (*Aryabarzan, Minaei-Bidgoli & Teshnehlab, 2018 — Expert Systems With Applications, 105, 129–143*) hoàn toàn bằng ngôn ngữ **Julia ($\ge 1.9$)**.

---

## 1. Thông tin nhóm (2 thành viên)

| STT | Họ và tên | MSSV | Vai trò / Phụ trách chính |
| :---: | :--- | :---: | :--- |
| 1 | `Nguyễn Thanh Tùng` | `24127583` | Cài đặt thuật toán `negFIN` (Baseline & Optimized), Unit Tests, CLI |
| 2 | `Nguyễn Tuấn Khanh` | `24127415` | Thực nghiệm Chương 2, Ứng dụng thực tế Chương 3, Báo cáo IEEE |

---

## 2. Liên kết Colab & Tài nguyên

| Tài nguyên | Liên kết | Ghi chú |
| :--- | :--- | :--- |
| **Google Colab (Chương 2)** | [![Open In Colab](https://colab.research.google.com/assets/colab-badge.svg)](https://colab.research.google.com/github/Thanhtung46/Frequent_Itemset_Mining/blob/main/notebooks/ch2_experiments.ipynb) | Chạy bằng **Julia Runtime**, tự động tải 5 bộ benchmark từ Hugging Face |
| **Google Colab (Demo Chương 3)** | [Mở notebook demo Chương 3](https://colab.research.google.com/github/Thanhtung46/Frequent_Itemset_Mining/blob/main/notebooks/demo.ipynb) | Chạy 2 ứng dụng Julia; **không** tự chạy lại benchmark Chương 2 |
| **Bộ dữ liệu Benchmark (Hugging Face)** | https://huggingface.co/datasets/stephent9/Lab1_Frequent_Itemset_Mining | 5 bộ chuẩn SPMF: `chess`, `mushroom`, `accidents`, `retail`, `T10I4D100K` |
| **Bài báo gốc (`negFIN`)** | [DOI: 10.1016/j.eswa.2018.03.041](https://doi.org/10.1016/j.eswa.2018.03.041) | Aryabarzan et al. (2018), *negFIN: An efficient algorithm for fast mining frequent itemsets* |
| **Thư viện đối chiếu (`SPMF`)** | https://www.philippe-fournier-viger.com/spmf/ | Dùng `spmf.jar` làm chuẩn đối chiếu Ground Truth |

---

## 3. Cấu trúc thư mục dự án

```text
Frequent_Itemset_Mining/
├── README.md                     # Thông tin nhóm, hướng dẫn chạy, kết quả test, link Colab & Dataset
├── Project.toml                  # Khai báo môi trường & dependencies Julia
├── CH3_INTEGRATION.md            # Hướng dẫn Chương 3 Julia, thay hướng dẫn Python cũ
├── CH3_MERGE_GUIDE.md            # Hướng dẫn ghép mã Chương 3
├── .agents/rules/
│   └── code-style.md             # Quy chuẩn style code Julia (BlueStyle + hiệu năng)
├── src/
│   ├── algorithm/                # Cài đặt chính thuật toán negFIN
│   │   ├── negfin_baseline.jl    # Phiên bản cơ bản bám sát giả mã Algorithm 1–4 (BitVector)
│   │   └── negfin_optimized.jl   # Phiên bản tối ưu (UInt64/UInt128/NTuple, Early-Abort, zero-alloc)
│   ├── main.jl                   # Entry-point CLI Chương 1 (--input, --output, --minsup, --algo, --stats)
│   ├── application_mining.jl     # CLI SPMF bổ sung (không phải entry-point 2 ứng dụng Chương 3)
│   ├── structures.jl             # Cấu trúc BMC-tree (LCRS), NodeSet (SoA), Multiple Dispatch bit-packing
│   └── utils.jl                  # Đọc/ghi chuẩn SPMF, đối chiếu kết quả 100%
├── applications/                 # Cả hai ứng dụng Chương 3 thuần Julia
│   ├── Chapter3.jl               # Module, import lại thuật toán negFIN của nhóm
│   ├── common.jl                 # Gọi negFIN, giao dịch, CSV, SPMF, SVG
│   ├── market_basket.jl          # Phân tích giỏ hàng Groceries và luật kết hợp
│   ├── visual_words.jl           # Đặc trưng gradient, K-means, Bag of Visual Words
│   ├── run_market.jl             # CLI ứng dụng giỏ hàng
│   └── run_visual.jl             # CLI ứng dụng ảnh
├── scripts/
│   └── run_benchmarks.jl         # Script chạy tự động 6 thực nghiệm Chương 2, xuất CSV
├── tests/
│   ├── runtests.jl               # File chạy chính cho `julia --project=. tests/runtests.jl`
│   ├── test_correctness.jl       # Kiểm thử đúng đắn trên >= 7 CSDL & đối chiếu SPMF
│   ├── test_benchmark.jl         # Đối chứng tốc độ & bộ nhớ Baseline vs. Optimized
│   └── test_ch3_julia.jl         # Kiểm thử hai ứng dụng Chương 3
├── data/
│   ├── toy/                      # Dữ liệu mẫu kiểm thử nhanh (`paper_example1.txt` — Table 1 bài báo)
│   ├── benchmark/                # 5 bộ dữ liệu chuẩn tải từ Hugging Face (bỏ qua trong .gitignore)
│   ├── synthetic/                # Dữ liệu tổng hợp kiểm thử độ dài giao dịch & scalability
│   └── chapter3/                 # Digits CSV + SOURCE.md, Groceries được tải khi chạy
├── notebooks/
│   ├── ch2_experiments.ipynb     # Notebook Julia của Chương 2
│   ├── demo.ipynb                # Colab demo 2 ứng dụng Chương 3
│   ├── ch3_market_basket.ipynb   # Colab ứng dụng giỏ hàng
│   └── ch3_visual_words.ipynb   # Colab ứng dụng ảnh
├── results/
│   ├── logs/                     # Bảng số liệu CSV của 6 thực nghiệm Chương 2
│   ├── figures/                  # Biểu đồ Chương 2
│   └── chapter3/                 # Kết quả Julia mới được tạo khi chạy (CSV, SVG, TXT)
├── spmf/                         # Đặt `spmf.jar` tại đây khi chạy đối chiếu SPMF ở local
└── docs/                         # Ghi chú Chương 3 và báo cáo nếu nhóm bổ sung
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

Chương 3 sử dụng lại thuật toán **negFIN** trong `src/algorithm/` của nhóm. Hai ứng dụng thuộc `applications/*.jl`, không còn cần các file `.py` hay `requirements-ch3.txt` của bản cũ. Không cần `pip`, `pandas`, `scikit-learn` hay `OpenCV` để chạy ứng dụng trên máy cá nhân.

| Ứng dụng | Thực hiện bằng Julia | Đầu ra chính |
| --- | --- | --- |
| **Market Basket Analysis** | Đọc Groceries → chuẩn hóa giao dịch → negFIN → tự sinh luật Support/Confidence/Lift → top-10 | `results/chapter3/market_basket/summary.txt`, `top10_lift.csv`, `top10_lift.svg` |
| **Bag of Visual Words** | Đọc Digits → trích descriptor gradient 3×3 → K-means tự cài → visual words → negFIN → đánh giá nearest-centroid | `results/chapter3/visual_words/summary.txt`, `patterns_by_class.csv`, `test_accuracy_comparison.csv`, `enriched_patterns.svg` |

**Giới hạn phương pháp:** Ứng dụng ảnh dùng **dense gradient descriptors tự cài**, không phải SIFT/ORB; tập Digits là ảnh chữ viết tay 8×8, không phải Caltech-101 hay CIFAR. Cần nêu rõ khi viết báo cáo.

### Cài đặt và chạy tại thư mục gốc repository (Windows / VS Code)

```powershell
julia --version
julia --project=. -e 'using Pkg; Pkg.instantiate()'
julia --project=. tests/runtests.jl
julia --project=. tests/test_ch3_julia.jl
julia --project=. applications/run_market.jl
julia --project=. applications/run_visual.jl
```

Điều chỉnh tham số, nếu cần:

```powershell
julia --project=. applications/run_market.jl --minsup 0.01 --minconf 0.15 --algo baseline
julia --project=. applications/run_visual.jl --minsup 0.12 --words 16 --seed 42 --algo baseline
```

Để so sánh bản tối ưu của nhóm, đổi `--algo baseline` thành `--algo optimized`. Groceries tự tải từ nguồn công khai khi chạy lần đầu; Digits CSV đã có tại `data/chapter3/digits8x8.csv`. Cả hai ứng dụng xuất CSV, SPMF, SVG và `summary.txt` tại `results/chapter3/`.

### Google Colab: Vì sao metadata vẫn ghi `Python 3`?

[**Mở demo Chương 3 trên Colab**](https://colab.research.google.com/github/Thanhtung46/Frequent_Itemset_Mining/blob/main/notebooks/demo.ipynb) · [Notebook Market Basket](notebooks/ch3_market_basket.ipynb) · [Notebook Visual Words](notebooks/ch3_visual_words.ipynb).

Colab sử dụng **Python 3 kernel mặc định chỉ để chạy `%%bash` và `!julia`** (cài Julia và chạy `.jl`). **Không có thuật toán Python** trong ba notebook. Giữ metadata Python để tương thích với các ô shell hiện có; không tự chuyển kernel sang Julia nếu chưa chuyển cú pháp notebook. Liên kết GitHub chỉ hoạt động sau khi các file được push lên nhánh `main` có thể truy cập.

**Notebook `demo.ipynb` chỉ chạy Chương 3**, không tự chạy Chương 2. Chương 2 có notebook riêng `notebooks/ch2_experiments.ipynb`.

### Tài liệu và xác minh kết quả

- [CH3_INTEGRATION.md](CH3_INTEGRATION.md): tích hợp và hướng dẫn chạy Julia.
- [docs/Chapter3_notes.md](docs/Chapter3_notes.md): quy trình, giả định và giới hạn khi báo cáo/vấn đáp.
- [data/chapter3/SOURCE.md](data/chapter3/SOURCE.md): nguồn bộ dữ liệu.

**Không dùng đầu ra `.png`/`summary.json` còn sót từ phiên bản Python cũ làm kết quả thực nghiệm của Julia.** Phải chạy lại và chỉ sử dụng các tệp đầu ra thật sự do Julia sinh ra (`summary.txt`, `.csv`, `.svg`).

Bản tài liệu được cập nhật theo mã nguồn trong repository. **Chưa xác nhận kiểm thử Julia hoặc đầu ra Chương 3 chạy PASS trong môi trường tạo gói**; nhóm cần chạy và lưu bằng chứng trước khi nộp.

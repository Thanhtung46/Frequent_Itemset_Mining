# Đồ án Khai thác Tập phổ biến (Frequent Itemset Mining) — negFIN

Cài đặt thuật toán **negFIN** từ bài báo gốc, tối ưu hóa bằng **Julia**, đánh giá trên dữ liệu benchmark và triển khai hai ứng dụng thực tế. Repo bao gồm mã nguồn, bộ kiểm thử, Jupyter Notebook và báo cáo IEEE hai cột.

> **Kết quả đã ghi nhận trước khi cập nhật repository:** **66/66 kiểm thử PASS** (39/39 Chương 1–2; 27/27 Chương 3); CSV lưu **30/30 cấu hình đối chiếu SPMF MATCH 100%**. `docs/Report.pdf` gồm 12 trang, có đồ thị thời gian theo MinSup và hình chữ số đủ 4 lớp. Việc sửa notebook và dọn file không thay thế cho một lần chạy lại kiểm thử.

## 1. Thành viên và phân công

| Thành viên | MSSV | Phụ trách chính |
| --- | --- | --- |
| Nguyễn Thanh Tùng | 24127583 | negFIN Baseline/Optimized, CLI, kiểm thử và Chương 2 |
| Nguyễn Tuấn Khanh | 24127415 | Hai ứng dụng Chương 3 và báo cáo |

## 2. Mã nguồn, notebook và dữ liệu

| Tài nguyên | Liên kết / Vị trí |
| --- | --- |
| Repository GitHub | <https://github.com/Thanhtung46/18> |
| Colab Chương 2 — Thực nghiệm | [Mở notebook 01](https://colab.research.google.com/github/Thanhtung46/18/blob/main/notebooks/colab/01_ch2_experiments.ipynb) |
| Colab Chương 3 — Market Basket | [Mở notebook 02](https://colab.research.google.com/github/Thanhtung46/18/blob/main/notebooks/colab/02_ch3_app1_market_basket.ipynb) |
| Colab Chương 3 — Visual Words | [Mở notebook 03](https://colab.research.google.com/github/Thanhtung46/18/blob/main/notebooks/colab/03_ch3_app2_visual_words.ipynb) |
| Colab Chương 3 — Demo hai ứng dụng | [Mở notebook 04](https://colab.research.google.com/github/Thanhtung46/18/blob/main/notebooks/colab/04_ch3_all_applications.ipynb) |
| Dữ liệu benchmark và ứng dụng (bản sao công khai) | <https://huggingface.co/datasets/stephent9/Lab1_Frequent_Itemset_Mining> |
| SPMF (chương trình đối chiếu) | <https://www.philippe-fournier-viger.com/spmf/> |
| Bài báo negFIN | N. Aryabarzan et al., *Expert Systems with Applications*, 2018; xem tài liệu tham khảo trong báo cáo |
| Báo cáo IEEE — bản cập nhật 12 trang | [`docs/Report.pdf`](docs/Report.pdf) |

**Nguồn dữ liệu:** Chương 2 sử dụng Chess, Mushroom, Accidents, Retail và T10I4D100K; Chương 3 sử dụng Groceries (gói R `arules`) và UCI Optical Recognition of Handwritten Digits (ảnh 8×8). Dữ liệu được mirror trên Hugging Face để thuận tiện khi chạy notebook.

## 3. Cấu trúc dự án (đúng với ZIP hiện tại)

```text
datamining/
├── .gitignore
├── Project.toml
├── README.md
├── src/
│   ├── algorithm/
│   │   ├── negfin_baseline.jl
│   │   └── negfin_optimized.jl
│   ├── applications/
│   │   ├── applications.jl
│   │   ├── app_utils.jl
│   │   ├── market_basket.jl
│   │   ├── visual_words.jl
│   │   ├── run_market_basket.jl
│   │   └── run_visual_words.jl
│   ├── main.jl
│   ├── structures.jl
│   └── utils.jl
├── tests/
│   ├── runtests.jl
│   ├── test_correctness.jl
│   ├── test_benchmark.jl
│   └── test_ch3_julia.jl
├── scripts/
│   ├── run_benchmarks.jl
│   └── compare_spmf_cli.jl
├── notebooks/
│   ├── colab/                         # 01, 02, 03, 04 (.ipynb)
│   └── local/                         # 01, 02, 03, 04 (.ipynb)
├── data/
│   ├── toy/
│   │   └── paper_example1.txt
│   └── chapter3/
│       └── digits8x8.csv
├── results/
│   ├── logs/                          # CSV của 6 nhóm thực nghiệm Chương 2
│   ├── figures/                       # Hình Chương 2 và 3 (.png, .svg)
│   ├── spmf_comparison/               # CSV + 6 SVG + môi trường benchmark SPMF
│   └── chapter3/
│       ├── market_basket/             # Bảng, dữ liệu, SVG và kết quả chạy
│       └── visual_words/             # Bảng, dữ liệu, SVG và kết quả chạy
└── docs/
    └── Report.pdf                     # Báo cáo đã biên dịch, 12 trang
```

**Các thành phần không có sẵn trong ZIP:**

- `Manifest.toml`: không có trong repository; Julia có thể tạo sau `Pkg.instantiate()` và hiện được `.gitignore` bỏ qua.
- `data/benchmark/`: chưa đóng gói 5 tập dữ liệu lớn. Cần tải vào thư mục này trước khi chạy `scripts/run_benchmarks.jl`. Script `scripts/compare_spmf_cli.jl` có chức năng tự tải dữ liệu còn thiếu từ Hugging Face.
- `data/chapter3/groceries.csv`: được ứng dụng Market Basket tải tự động khi cần (nếu truy cập mạng thành công).
- `spmf/spmf.jar`: cần tự tạo thư mục `spmf/` và chép JAR tương thích vào khi muốn chạy các phép đối chiếu trực tiếp.
- `docs/Report.tex`, `docs/figures/` và `docs/benchmark_data/`: **không nằm trong ZIP này**. Mã nguồn LaTeX và bộ hình phục vụ biên dịch báo cáo cần được bổ sung riêng nếu giảng viên yêu cầu; hình và CSV dùng để tham khảo đang có ở `results/`.

`compare_spmf_cli.jl` **đã nằm sẵn** trong `scripts/`, không cần chép thêm từ gói benchmark khác.

## 4. Cài đặt và chạy trên máy cá nhân

### Yêu cầu

- **Julia ≥ 1.9**; các lần kiểm thử đã ghi nhận sử dụng Julia 1.13.4 (Windows) và Julia trên Google Colab.
- **Java và `spmf.jar` tương thích** nếu cần đối chiếu trực tiếp với SPMF. **File `spmf.jar` đã kiểm thử yêu cầu Java 25** (class-file version 69); Java 8 hoặc Java 21 không chạy được *file JAR đó*. Một bản JAR khác có thể có yêu cầu Java khác.
- PowerShell/CMD trên Windows hoặc shell macOS/Linux. Không cần Python để chạy lõi negFIN và hai ứng dụng Chương 3.

### Cài Julia packages

```powershell
# Mở terminal tại thư mục gốc project
julia --version
julia --project=. -e "using Pkg; Pkg.instantiate()"
```

Repository chỉ cung cấp `Project.toml` (đã khai báo CSV, DataFrames, Plots và các Julia standard libraries). `Pkg.instantiate()` sẽ cài gói cần thiết và có thể tạo `Manifest.toml` ở máy bạn; file đó không nằm trong ZIP và đang được `.gitignore` bỏ qua. Nếu việc giải quyết dependency gặp lỗi, có thể thử `julia --project=. -e "using Pkg; Pkg.resolve(); Pkg.instantiate()"`.

### Kiểm thử Chương 1–2 và SPMF

1. Tạo thư mục `spmf` nếu chưa tồn tại (`mkdir spmf`), rồi tải `spmf.jar` và đặt tại `spmf/spmf.jar`.
2. Kiểm tra Java đang được ưu tiên trên `PATH` (ví dụ PowerShell):

```powershell
java -version
Test-Path .\spmf\spmf.jar
```

3. Chạy:

```powershell
julia --project=. tests/runtests.jl
```

**Kết quả mong đợi:** `NegFIN Test Suite | 39 | 39` và 5 bộ đối chiếu `MATCH 100%` cho cả Baseline/Optimized. Nếu không có JAR hoặc Java tương thích, **10 kiểm thử SPMF sẽ bị bỏ qua** và có thể chỉ đạt **29/29**; không được coi như đã kiểm tra trực tiếp SPMF.

### Kiểm thử Chương 3

```powershell
julia --project=. tests/test_ch3_julia.jl
```

**Kết quả ghi nhận trước đó trên Colab:** `Chapter 3 Julia applications | 27 | 27` (`ProcessExited(0)` khi chạy bộ test trong tiến trình Julia riêng).

### Chạy CLI negFIN (Chương 1)

```powershell
julia --project=. src/main.jl --input data/toy/paper_example1.txt --output results/out_optimized.txt --minsup 0.4 --algo optimized --stats
julia --project=. src/main.jl --input data/toy/paper_example1.txt --output results/out_baseline.txt --minsup 0.4 --algo baseline --stats
```

### Chạy Chương 2

```powershell
julia --project=. scripts/run_benchmarks.jl
```

**Trước khi chạy trên Windows**, hãy tải đủ 5 file `chess.txt`, `mushroom.txt`, `accidents.txt`, `retail.txt`, `T10I4D100K.txt` từ bộ dữ liệu Hugging Face ở Mục 2 và đặt vào `data/benchmark/` (tạo thư mục nếu cần). Script `run_benchmarks.jl` **không tự tải** dữ liệu; sẽ báo lỗi nếu thiếu file. Notebook Colab Chương 2 có cell tự chuẩn bị dữ liệu. Kết quả được lưu trong `results/logs/` và biểu đồ liên quan trong `results/figures/`.

### Chạy hai ứng dụng Chương 3

```powershell
julia --project=. src/applications/run_market_basket.jl --minsup 0.01 --minconf 0.15 --algo optimized
julia --project=. src/applications/run_visual_words.jl --minsup 0.12 --words 16 --seed 42 --algo optimized
```

Kết quả được tạo tại `results/chapter3/` và `results/figures/`. Có thể dùng `--algo baseline` để đối chiếu với bản Optimized.

## 5. Chạy Google Colab (Julia Runtime)

1. Mở notebook từ liên kết ở Mục 2 và chọn **Runtime → Change runtime type → Julia** (CPU là đủ).
2. Chạy **Runtime → Run all**. Các notebook thiết lập mã nguồn bằng cách clone repository `Thanhtung46/18` từ nhánh `main` và tải dữ liệu cần thiết nếu chưa có.
3. **Các notebook Chương 3 đã đồng nhất cách chạy kiểm thử:** `02`, `03`, `04` trên Colab và `02`, `03`, `04` trên máy local đều chạy test trong tiến trình Julia riêng, tránh xung đột tên khi nạp module; notebook `04` là lựa chọn phù hợp để demo cả hai ứng dụng:

   ```julia
   cd(ROOT_DIR) do
       run(`$(Base.julia_cmd()) --project=. tests/test_ch3_julia.jl`)
   end
   ```

4. Nếu notebook đã mở trên Colab trước khi cập nhật GitHub, hãy làm mới phiên Julia và mở lại notebook từ nhánh `main` để lấy mã mới. Trong cả năm notebook vừa sửa, cell test được giữ trạng thái chưa chạy cho đến khi bạn **Run all**.
5. Kiểm tra đầu ra ứng dụng và ảnh mẫu gồm các lớp `0`, `1`, `3`, `8`; lưu bản sao notebook vào Google Drive khi cần nộp.

Notebook Colab Chương 2 (`01`) và bộ 4 notebook local cũng được cung cấp trong `notebooks/`.

## 6. Kết quả đã kiểm chứng

### Kiểm thử

| Phần | Kết quả | Bằng chứng |
| --- | --- | --- |
| Chương 1–2 (tự động + SPMF) | **39/39 PASS** | PowerShell trên Windows; 5 bộ test SPMF đều MATCH 100% cho Baseline/Optimized |
| Chương 3 (tích hợp) | **27/27 PASS** | Google Colab Julia Runtime |
| **Tổng** | **66/66 PASS** | Hai bộ test độc lập |

### Ứng dụng Chương 3

| Ứng dụng | Dữ liệu/cấu hình | Kết quả |
| --- | --- | --- |
| Market Basket Analysis | Groceries: 9.835 giao dịch, 169 sản phẩm; `minsup=0.01`, `minconf=0.15` | **333** frequent itemsets, **322** association rules, Support cross-check **PASS**, Lift cao nhất khoảng **3,37** |
| Bag of Visual Words | 448 ảnh train, 152 ảnh test; 4 lớp `0,1,3,8`; `K=16`, seed 42, `minsup=0.12` | **154** frequent itemsets, **60** selected patterns, Support cross-check **PASS**, enrichment tối đa **4,00** |

Mô hình phân loại Nearest-Centroid trên tập ảnh test đạt **79,61%** khi chỉ dùng visual words và **78,95%** khi bổ sung 60 FIM patterns. Việc thêm FIM patterns **không cải thiện độ chính xác** trong thực nghiệm này. BoVW dùng dense-gradient descriptors tự cài trên ảnh 8×8, **không phải SIFT/ORB**.

## 7. Đối chứng thời gian SPMF – Baseline – Optimized (Chương 2)

Đã chạy **đầy đủ 30/30 cấu hình** (5 dataset × 6 ngưỡng MinSup), tất cả **MATCH 100%** về frequent itemsets và support. Ba phiên bản đo với cùng dữ liệu và MinSup trên cùng máy Windows (CPU Intel Alder Lake, Julia 1.13.4, OpenJDK 25.0.5.1, 1 luồng Julia).

Phương pháp đo là **CLI end-to-end wall-clock**: mỗi cấu hình có một lần chạy thử và ba lần đo, lấy trung vị. Bao gồm khởi động chương trình/JIT, đọc dữ liệu, khai thác và ghi kết quả; **không** so sánh trực tiếp với thời gian chỉ tính lõi thuật toán trong Chương 2.

| Dataset | Khoảng MinSup | SPMF (s) | Baseline (s) | Optimized (s) | Khớp |
| --- | ---: | ---: | ---: | ---: | --- |
| Chess | 90–65% | 0.734 | 6.847 | 6.966 | 6/6 |
| Mushroom | 40–15% | 0.840 | 9.415 | 9.581 | 6/6 |
| Accidents | 75–50% | 4.449 | 16.444 | 16.601 | 6/6 |
| Retail | 5–0.3% | 1.357 | 11.444 | 11.978 | 6/6 |
| T10I4D100K | 4–0.7% | 3.745 | 12.994 | 11.556 | 6/6 |

*Các thời gian trong bảng là trung vị của sáu giá trị trung vị theo từng mức MinSup*, không phải một cấu hình đại diện. **SPMF nhanh nhất ở 30/30 cấu hình CLI**; bản Optimized nhanh hơn Baseline ở 15/30 trường hợp. Không suy ra tốc độ của phần lõi thuật toán chỉ từ phép đo CLI.

- Dữ liệu gốc: [`results/spmf_comparison/spmf_cli_comparison.csv`](results/spmf_comparison/spmf_cli_comparison.csv) (30 dòng).
- Môi trường đo: [`results/spmf_comparison/benchmark_environment.txt`](results/spmf_comparison/benchmark_environment.txt).
- Biểu đồ tổng hợp: [`results/spmf_comparison/spmf_cli_comparison.svg`](results/spmf_comparison/spmf_cli_comparison.svg).
- Biểu đồ riêng 5 dataset: `results/spmf_comparison/runtime_*.svg`.
- Script thực hiện: [`scripts/compare_spmf_cli.jl`](scripts/compare_spmf_cli.jl) (**đã có trong repository**).

```powershell
# Cần Java và spmf/spmf.jar tương thích; script tự tải 5 dataset nếu thiếu
julia --project=. scripts/compare_spmf_cli.jl --full
```

## 8. Báo cáo IEEE và lưu ý trước khi nộp

- [`docs/Report.pdf`](docs/Report.pdf) là **bản báo cáo đã biên dịch 12 trang**, có bảng và đồ thị so sánh SPMF – Baseline – Optimized theo 6 mức MinSup trên 5 dataset.
- **Hình 10 – Ảnh mẫu UCI Digits:** báo cáo đã sử dụng ảnh minh họa 12 mẫu, mỗi lớp `0`, `1`, `3`, `8` có 3 ảnh. Dữ liệu hình SVG do Julia xuất nằm tại [`results/figures/ch3_digits_samples.svg`](results/figures/ch3_digits_samples.svg); bản xuất theo ứng dụng nằm trong `results/chapter3/visual_words/`.
- Các kết quả và biểu đồ gốc cho Chương 2 nằm tại `results/logs/`, `results/figures/` và `results/spmf_comparison/`. Chúng **không** nằm trong `docs/benchmark_data/` hay `docs/figures/` của ZIP này.
- **ZIP chỉ có `docs/Report.pdf`, chưa có `docs/Report.tex` và thư mục hình LaTeX.** Nếu cần chỉnh sửa hoặc biên dịch lại báo cáo, phải đưa nguồn `.tex` và các hình phụ thuộc vào repository từ bản tài liệu riêng; không thể biên dịch lại chỉ từ ZIP này.
- Xác nhận yêu cầu số trang của giảng viên theo **số trang nội dung chính**, vì tổng 12 trang PDF có thể bao gồm tài liệu tham khảo.
- Đã loại bỏ 6 file PNG/JSON đầu ra từ pipeline cũ không còn được code Julia sử dụng (`top10_lift.png`, `top_products.png`, `item_mapping.json`, `summary.json`, `enriched_patterns.png`, `sample_digits.png` trong `results/chapter3/`). Biểu đồ SVG, CSV và kết quả hiện tại vẫn được giữ lại.
- Bản ZIP nộp **không chứa `.git/`**. Nếu cập nhật repository đang làm việc, giữ nguyên thư mục `.git/` trên máy và chỉ thay các file mã nguồn/tài liệu; xem thay đổi bằng `git status` trước khi commit.
- `.gitignore` **không còn bỏ qua `docs/`**, vì vậy có thể thêm `docs/Report.tex` và ảnh báo cáo vào Git khi có nguồn; chỉ các file LaTeX biên dịch tạm như `.aux`, `.log`, `.synctex.gz` bị bỏ qua. `Manifest.toml` vẫn bị bỏ qua theo cấu hình dự án.

## 9. Tài liệu tham khảo

1. N. Aryabarzan, B. Minaei-Bidgoli, M. Teshnehlab, “negFIN: An efficient algorithm for fast mining frequent itemsets,” *Expert Systems with Applications*, vol. 105, pp. 129–143, 2018.
2. P. Fournier-Viger et al., SPMF Open-Source Data Mining Library, <https://www.philippe-fournier-viger.com/spmf/>.
3. M. Hahsler et al., Groceries dataset (R `arules`), <https://michael.hahsler.net/arules/reference/Groceries.html>.
4. UCI Machine Learning Repository, Optical Recognition of Handwritten Digits, <https://archive.ics.uci.edu/dataset/80/optical+recognition+of+handwritten+digits>.

Chi tiết trích dẫn học thuật xem trong `docs/Report.pdf`.

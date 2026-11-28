# Đồ án Khai thác Tập phổ biến (Frequent Itemset Mining) — negFIN

Cài đặt thuật toán **negFIN** từ bài báo gốc, tối ưu hóa bằng **Julia**, đánh giá trên dữ liệu benchmark và triển khai hai ứng dụng thực tế. Repo bao gồm mã nguồn, bộ kiểm thử, Jupyter Notebook và báo cáo IEEE hai cột.

> **Kết quả đã xác nhận:** **66/66 bài kiểm thử PASS** (39/39 Chương 1–2, 27/27 Chương 3); **30/30 cấu hình benchmark CLI khớp SPMF 100%**. Báo cáo IEEE đã bổ sung các đường thời gian theo MinSup và hình minh họa đủ 4 lớp chữ số. Các số liệu được tái lập theo môi trường và tham số ghi bên dưới.

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

## 3. Cấu trúc dự án

```text
datamining/                         # Có thể mang tên 18/ khi clone từ GitHub
├── Project.toml
├── Manifest.toml
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
│   ├── runtests.jl                 # Chương 1–2 + đối chiếu SPMF
│   ├── test_correctness.jl
│   ├── test_benchmark.jl
│   └── test_ch3_julia.jl          # Chương 3
├── scripts/
│   ├── run_benchmarks.jl          # 6 nhóm thực nghiệm Chương 2
│   └── compare_spmf_cli.jl       # Script benchmark CLI riêng; cần ghép vào repo trước khi chạy
├── notebooks/
│   ├── colab/                     # 01, 02, 03, 04
│   └── local/                     # 01, 02, 03, 04
├── data/
│   ├── toy/
│   ├── benchmark/                 # Dữ liệu lớn: tải khi cần
│   └── chapter3/                  # groceries.csv, digits8x8.csv
├── results/
│   ├── logs/
│   ├── figures/
│   └── chapter3/
├── docs/
│   ├── Report.tex                 # Khi đã ghép thư mục docs nguồn LaTeX
│   ├── Report.pdf
│   ├── figures/
│   └── benchmark_data/           # CSV + mô tả môi trường so sánh SPMF
└── spmf/
    └── spmf.jar                  # Tải riêng; không bắt buộc có trong GitHub
```

**Lưu ý khi ghép bản mới:** `docs/benchmark_data/`, `docs/figures/runtime_*.svg` và `docs/Report.tex` nằm trong gói tài liệu đã cập nhật. Script `scripts/compare_spmf_cli.jl` được cung cấp ở gói benchmark riêng, **không nằm trong gói chỉ chứa `docs/` và README**. Chỉ dùng lệnh benchmark ở Mục 7 sau khi đã sao chép script vào đúng vị trí. `spmf/spmf.jar` cần tải riêng theo hướng dẫn.

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

Nếu `Project.toml` và `Manifest.toml` không đồng bộ (ví dụ thiếu `CSV`), chạy `julia --project=. -e "using Pkg; Pkg.resolve()"` rồi `instantiate()` lại. Kiểm tra thay đổi ở `Manifest.toml` trước khi commit.

### Kiểm thử Chương 1–2 và SPMF

1. Tải `spmf.jar` và đặt tại `spmf/spmf.jar`.
2. Kiểm tra Java đang được ưu tiên trên `PATH`:

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

**Kết quả đã xác nhận trên Colab:** `Chapter 3 Julia applications | 27 | 27` (`ProcessExited(0)` khi chạy bộ test trong tiến trình Julia riêng).

### Chạy CLI negFIN (Chương 1)

```powershell
julia --project=. src/main.jl --input data/toy/paper_example1.txt --output results/out_optimized.txt --minsup 0.4 --algo optimized --stats
julia --project=. src/main.jl --input data/toy/paper_example1.txt --output results/out_baseline.txt --minsup 0.4 --algo baseline --stats
```

### Chạy Chương 2

```powershell
julia --project=. scripts/run_benchmarks.jl
```

Cần có 5 dataset trong `data/benchmark/` hoặc chạy notebook Colab Chương 2 để thiết lập dữ liệu. Kết quả thực nghiệm được lưu trong `results/logs/` và `results/figures/`.

### Chạy hai ứng dụng Chương 3

```powershell
julia --project=. src/applications/run_market_basket.jl --minsup 0.01 --minconf 0.15 --algo optimized
julia --project=. src/applications/run_visual_words.jl --minsup 0.12 --words 16 --seed 42 --algo optimized
```

Kết quả được tạo tại `results/chapter3/` và `results/figures/`. Có thể dùng `--algo baseline` để đối chiếu với bản Optimized.

## 5. Chạy Google Colab (Julia Runtime)

1. Mở notebook từ các liên kết ở Mục 2. Chọn **Runtime → Change runtime type → Julia** (CPU là đủ).
2. Nếu Colab tự chuyển về Python 3 khi mở từ GitHub, tạo bản sao vào Drive và chọn lại Julia; xác nhận runtime hiện `Julia` trước khi chạy.
3. Chọn **Runtime → Run all**. Với notebook demo Chương 3, cell chạy kiểm thử nên gọi Julia trong tiến trình riêng để tránh nhập trùng tên hàm vào `Main`:

   ```julia
   cd(ROOT_DIR) do
       run(`$(Base.julia_cmd()) --project=. tests/test_ch3_julia.jl`)
   end
   ```

4. Kiểm tra `27/27 PASS`, hai ứng dụng xuất bảng và biểu đồ (gồm ảnh mẫu `0`, `1`, `3`, `8`), sau đó **Save a copy in Drive** và chia sẻ quyền xem khi nộp.

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

- Dữ liệu gốc: `docs/benchmark_data/spmf_cli_comparison.csv` (30 dòng).
- Thông số môi trường: `docs/benchmark_data/benchmark_environment.txt`.
- Biểu đồ riêng cho 5 dataset: `docs/figures/runtime_*.svg` (và `.pdf` cho LaTeX).
- Script thực hiện: `scripts/compare_spmf_cli.jl` (lấy từ gói benchmark riêng và ghép vào repository nếu muốn chạy lại).

```powershell
# Chỉ chạy lệnh này khi scripts/compare_spmf_cli.jl đã tồn tại
julia --project=. scripts/compare_spmf_cli.jl --full
```

## 8. Báo cáo IEEE và lưu ý trước khi nộp

- Bản `docs/Report.pdf` trong gói cập nhật có **12 trang PDF** (bao gồm tài liệu tham khảo), đã tích hợp so sánh thời gian CLI trên **30 cấu hình**. Khi ghép vào repository, thay đồng bộ PDF, LaTeX và các hình minh họa.
- Đã bổ sung phần đối chứng CLI với SPMF vào **Mục III.H – So sánh với SPMF (Java)**: 6 mức MinSup cho mỗi dataset, tổng 30 cấu hình, tất cả MATCH 100%. Biểu đồ thời gian nằm ở **Hình 7–8** của báo cáo mới.
- **Hình 10 – Ảnh mẫu UCI Digits đã sửa:** `docs/figures/ch3_digits_samples.png` hiện minh họa **12 ảnh, gồm 3 ảnh của mỗi lớp `0`, `1`, `3`, `8`**. Hình đã được thay vào `docs/Report.tex` và biên dịch vào `docs/Report.pdf`; các chỉ số K-means/negFIN và biểu đồ enrichment không thay đổi. (Do đã thêm các hình benchmark SPMF, ảnh mẫu được đánh số **Hình 10**, không còn là Hình 8.)
- Kiểm tra phần nội dung chính đáp ứng quy định số trang của giảng viên **không tính tài liệu tham khảo/phụ lục**; số trang PDF tổng cộng không đồng nghĩa với số trang nội dung chính.
- Đối chiếu ảnh mẫu và bảng số liệu sau khi **Run all** notebook Colab; nếu notebook còn dùng bản mã cũ, cập nhật các file trên `main` rồi chạy lại trong runtime mới.
- Không commit thư mục `.git` từ file ZIP hoặc các kết quả thử nghiệm tạm thời ngoài phạm vi bản nộp.

## 9. Tài liệu tham khảo

1. N. Aryabarzan, B. Minaei-Bidgoli, M. Teshnehlab, “negFIN: An efficient algorithm for fast mining frequent itemsets,” *Expert Systems with Applications*, vol. 105, pp. 129–143, 2018.
2. P. Fournier-Viger et al., SPMF Open-Source Data Mining Library, <https://www.philippe-fournier-viger.com/spmf/>.
3. M. Hahsler et al., Groceries dataset (R `arules`), <https://michael.hahsler.net/arules/reference/Groceries.html>.
4. UCI Machine Learning Repository, Optical Recognition of Handwritten Digits, <https://archive.ics.uci.edu/dataset/80/optical+recognition+of+handwritten+digits>.

Chi tiết trích dẫn học thuật xem trong `docs/Report.pdf`.

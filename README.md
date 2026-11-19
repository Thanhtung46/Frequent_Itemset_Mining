# Frequent Itemset Mining — `negFIN` (Julia)

Cài đặt và đánh giá thực nghiệm thuật toán **negFIN** (Aryabarzan et al., 2018 — *negFIN: An efficient algorithm for fast mining frequent itemsets*, Expert Systems With Applications) bằng ngôn ngữ **Julia ($\ge 1.9$)**.

## Cấu trúc thư mục

```text
Frequent_Itemset_Mining/
├── README.md                 # Thông tin dự án, hướng dẫn chạy, kết quả kiểm thử
├── Project.toml              # Khai báo môi trường & dependencies Julia
├── .agents/rules/
│   └── code-style.md         # Quy chuẩn style code Julia cho dự án
├── src/
│   ├── main.jl               # Entry-point xử lý CLI (--input, --output, --minsup)
│   ├── structures.jl         # Cấu trúc BMC-tree, NegNodeset định kiểu chặt chẽ
│   ├── negfin_baseline.jl    # Phiên bản cài đặt cơ bản (Baseline)
│   ├── negfin_optimized.jl   # Phiên bản tối ưu (Bit-packing, Multiple Dispatch, @inbounds/@simd)
│   └── utils.jl              # Đọc/ghi chuẩn SPMF, sinh luật kết hợp (Association Rules)
├── tests/
│   ├── runtests.jl           # Entry-point kiểm thử tự động (`julia --project=. tests/runtests.jl`)
│   ├── test_correctness.jl   # Đối chiếu 100% với SPMF trên >= 5 CSDL
│   └── test_benchmark.jl     # Kiểm thử hiệu năng & bộ nhớ (Baseline vs. Optimized)
├── data/
│   ├── toy/                  # Các CSDL nhỏ để kiểm thử nhanh
│   ├── benchmark/            # Dữ liệu benchmark (Chess, Mushroom, Accidents, Retail, T10I4D100K)
│   └── synthetic/            # Dữ liệu tổng hợp kiểm thử độ dài giao dịch & scalability
├── notebooks/                # Notebook thực nghiệm & demo chạy trên Google Colab
├── results/
│   ├── logs/                 # Bảng số liệu CSV (runtime, peak RAM, output size)
│   └── figures/              # Biểu đồ độ phân giải cao (PNG/PDF)
├── spmf/                     # Chứa `spmf.jar` làm chuẩn đối chiếu Ground Truth
└── docs/                     # Báo cáo chuẩn IEEE (`Report.pdf`)
```

## Hướng dẫn chạy nhanh

```bash
# 1. Cài đặt môi trường Julia
julia --project=. -e 'using Pkg; Pkg.instantiate()'

# 2. Chạy bộ kiểm thử tự động
julia --project=. tests/runtests.jl

# 3. Chạy thuật toán qua CLI
julia --project=. src/main.jl --input data/toy/sample.txt --output out.txt --minsup 0.4
```

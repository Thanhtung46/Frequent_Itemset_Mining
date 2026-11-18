# Frequent_Itemset_Mining
Frequent_Itemset_Mining/
├── data/
│   ├── raw/                  # 4-5 tập benchmark (Chess, Mushroom, Retail, Accidents, T10I4D100K)
│   └── synthetic/            # Dữ liệu tổng hợp cho bài test độ dài giao dịch & scalability
├── spmf/
│   └── spmf.jar              # File tham chiếu chuẩn để xuất Ground Truth & đo runtime
├── src/
│   ├── io.jl                 # Đọc/ghi file định dạng SPMF (.txt)
│   ├── negfin_base.jl        # Phiên bản 1: Cài đặt cơ bản (dùng Vector/Set)
│   ├── negfin_opt.jl         # Phiên bản 2: Cài đặt tối ưu (dùng BitArray/UInt64 + tỉa nhánh)
│   └── cli.jl                # Entry-point nhận tham số dòng lệnh (input, output, minsup)
├── test/
│   └── runtests.jl           # Unit test tự động đối chiếu 100% kết quả với spmf.jar
├── notebooks/
│   └── ch2_experiments.ipynb # Chạy thực nghiệm Chương 2, xuất log và vẽ biểu đồ
└── results/
    ├── logs/                 # File CSV lưu thời gian chạy, Peak RAM, số lượng itemsets
    └── figures/              # Biểu đồ độ phân giải cao (PNG/PDF) chèn vào báo cáo
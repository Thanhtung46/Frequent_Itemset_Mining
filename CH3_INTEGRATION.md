# Hướng dẫn tích hợp Chương 3 (Julia) vào repository FIM

Tài liệu này mô tả **phiên bản Chương 3 viết bằng Julia** đang nằm trong repository. Hướng dẫn Python của bản Chương 3 trước đây đã hết hiệu lực. Không dùng mã nguồn `applications/*.py`, `tests/test_ch3.py` hay `requirements-ch3.txt`.

## 1. Phạm vi và nguyên tắc

- Chương 1–2 giữ nguyên thuật toán `src/algorithm/negfin_baseline.jl`, `negfin_optimized.jl`, các script và kiểm thử của nhóm.
- Chương 3 khai thác itemset bằng cách gọi trực tiếp **negFIN Julia của nhóm**, không dùng thư viện frequent-itemset mining khác.
- Hai ứng dụng, gồm **Market Basket Analysis** và **Bag of Visual Words**, thực hiện việc chuẩn bị dữ liệu, trích descriptor, K-means, sinh luật, đánh giá và xuất biểu đồ bằng Julia.
- **Không cần Python để chạy Chương 3 trên máy cá nhân.** Google Colab sử dụng *Python 3 kernel* chỉ để chạy các lệnh shell (`%%bash`, `!julia`); không có thuật toán Python trong notebook.

## 2. Các tệp cần dùng

| Đường dẫn | Chức năng |
| --- | --- |
| `applications/Chapter3.jl` | Module và điểm tích hợp với negFIN có sẵn |
| `applications/common.jl` | Chuẩn hóa giao dịch, gọi negFIN, xuất SPMF/CSV/SVG |
| `applications/market_basket.jl` | Phân tích giỏ hàng Groceries, sinh và xếp hạng luật kết hợp |
| `applications/visual_words.jl` | Descriptor gradient, Julia K-means, visual words, phân tích mẫu ảnh |
| `applications/run_market.jl` | Lệnh khởi chạy ứng dụng giỏ hàng |
| `applications/run_visual.jl` | Lệnh khởi chạy ứng dụng ảnh |
| `tests/test_ch3_julia.jl` | Kiểm thử tích hợp và chức năng Chương 3 |
| `data/chapter3/digits8x8.csv` | Dữ liệu ảnh Digits đã đóng gói |
| `data/chapter3/SOURCE.md` | Ghi chú nguồn dữ liệu Groceries/Digits |
| `notebooks/demo.ipynb` | Notebook Colab chạy cả hai ứng dụng Chương 3 |
| `notebooks/ch3_market_basket.ipynb` | Notebook Colab riêng cho ứng dụng giỏ hàng |
| `notebooks/ch3_visual_words.ipynb` | Notebook Colab riêng cho ứng dụng ảnh |
| `docs/Chapter3_notes.md` | Phương pháp, giới hạn và hướng dẫn báo cáo/vấn đáp |

`src/application_mining.jl` là một CLI Julia hỗ trợ định dạng SPMF ở bản tích hợp trước; **hai ứng dụng hiện tại gọi negFIN trực tiếp trong `applications/Chapter3.jl`**, không phụ thuộc vào CLI này.

## 3. Thiết lập và chạy trên Windows (PowerShell hoặc CMD)

Mở terminal **ở thư mục gốc repository** (nơi có `Project.toml`). Cần Julia **từ 1.9 trở lên** trong PATH. Không cần `pip install`.

```powershell
julia --version
julia --project=. -e 'using Pkg; Pkg.instantiate()'
```

Kiểm thử Chương 1–2 và Chương 3:

```powershell
julia --project=. tests/runtests.jl
julia --project=. tests/test_ch3_julia.jl
```

Chạy 2 ứng dụng:

```powershell
julia --project=. applications/run_market.jl
julia --project=. applications/run_visual.jl
```

Tham số tùy chọn:

```powershell
julia --project=. applications/run_market.jl --minsup 0.01 --minconf 0.15 --algo baseline
julia --project=. applications/run_visual.jl --minsup 0.12 --words 16 --seed 42 --algo baseline
```

Có thể thay `--algo baseline` bằng `--algo optimized` để đối chứng. Lưu ý `minsup` là tỷ lệ khi thuộc `(0, 1]`, hoặc số đếm nguyên khi lớn hơn 1 (áp dụng ở bộ gọi negFIN). Phần sinh luật giỏ hàng hiện nhận `minsup` tỷ lệ trong `(0, 1]`.

### Dữ liệu

- Groceries: lần chạy đầu, Julia tự tải CSV từ URL trong `applications/market_basket.jl` vào `data/chapter3/groceries.csv`. Nếu máy không có mạng, tải file theo `data/chapter3/SOURCE.md` rồi đặt đúng vị trí này.
- Digits 8×8: `data/chapter3/digits8x8.csv` **có sẵn**, không cần tải hoặc cài scikit-learn/Python. Nhắc đến scikit-learn trong tài liệu chỉ để **trích dẫn nguồn phân phối dữ liệu**, không phải thư viện thực thi.

### Đầu ra Julia

| Ứng dụng | Đường dẫn | Tệp cần xem |
| --- | --- | --- |
| Giỏ hàng | `results/chapter3/market_basket/` | `summary.txt`, `frequent_itemsets.spmf`, `association_rules.csv`, `top10_lift.csv`, `top10_lift.svg` |
| Ảnh | `results/chapter3/visual_words/` | `summary.txt`, `train_frequent_itemsets.spmf`, `patterns_by_class.csv`, `test_accuracy_comparison.csv`, `enriched_patterns.svg`, `digits_samples.svg` |

Các tệp cũ như `summary.json`, `top10_lift.png`, `enriched_patterns.png` từng có trong repository là **đầu ra của bản Python cũ**; không được sử dụng làm minh chứng cho lần chạy Julia mới. Hãy chạy lại, trích các file `summary.txt`/CSV/SVG mới để báo cáo.

## 4. Google Colab

1. Push đủ các tệp mới lên repository GitHub có thể truy cập; notebook hiện dùng đường dẫn repo `Thanhtung46/Frequent_Itemset_Mining`.
2. Mở một trong các notebook ở `notebooks/` bằng Colab và chọn **Python 3** runtime mặc định.
3. Chọn **Runtime → Run all**. Các ô `%%bash` cài Julia, clone/pull repository, chạy kiểm thử rồi gọi các script `.jl`.
4. Đọc kết quả sinh thật trong `results/chapter3/`. Đừng điền số liệu minh họa giả vào báo cáo.
5. Notebook Chương 2 `notebooks/ch2_experiments.ipynb` là phần riêng; notebook demo Chương 3 **không tự chạy benchmark Chương 2**.

Nếu sửa code đã push nhưng Colab còn checkout cũ, hãy chạy lại ô clone/cập nhật repository hoặc khởi tạo runtime mới.

## 5. Ghi chú để báo cáo trung thực

- Market Basket: diễn giải support/confidence/lift cùng ví dụ sản phẩm; lift chỉ phản ánh liên hệ thống kê, **không chứng minh quan hệ nhân quả**.
- Visual Words: tự triển khai **dense gradient descriptors**, **không phải SIFT/ORB**. Codebook K-means học từ tập train; frequent patterns khai thác bằng negFIN; đánh giá nearest-centroid trên test.
- Dữ liệu Digits là ảnh 8×8 chữ viết tay, khác ảnh tự nhiên. Nếu đề bài khuyến khích Caltech-101/CIFAR, cần nêu giới hạn của bộ Digits trong báo cáo.
- Chưa được phép ghi *PASS* cho kiểm thử Julia hoặc kết quả ứng dụng nếu chưa thực sự chạy trên máy/Colab có Julia.

## 6. Ghép vào GitHub nhóm

Nếu sử dụng ZIP đầy đủ để cập nhật thư mục Git đã clone, hãy **sao chép phần mã/tài liệu vào repository Git đang làm việc**; ZIP phát hành không chứa `.git`.

```powershell
git status
git diff --stat
git add -A
git commit -m "docs: align Chapter 3 documentation with Julia implementation"
git push origin main
```

Trước khi commit, kiểm tra kỹ `git status` để không xóa nhầm tệp nhóm khác. Không force-push chỉ vì cập nhật tài liệu.

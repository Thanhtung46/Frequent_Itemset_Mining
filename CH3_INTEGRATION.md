# Hướng dẫn ghép Chương 3 với Chương 1–2 (repository ngày cập nhật)

**Nguồn:** `Frequent_Itemset_Mining.zip` do nhóm cung cấp. Không thay đổi thuật toán, thực nghiệm hoặc test Chương 1–2 của nhóm.

## Thành phần bổ sung

- `applications/`: Python đọc dữ liệu, tạo giao dịch, sinh luật kết hợp, trích visual words, vẽ biểu đồ và đánh giá.
- `src/application_mining.jl`: cầu nối gọi trực tiếp `negfin_baseline` trong `src/algorithm/negfin_baseline.jl` (không đụng mã thuật toán gốc).
- `notebooks/ch3_market_basket.ipynb`: giỏ hàng Groceries.
- `notebooks/ch3_visual_words.ipynb`: Bag of Visual Words bằng Digits.
- `notebooks/demo.ipynb`: notebook tổng hợp chạy cả hai ứng dụng.
- `tests/test_ch3.py`, `tests/test_ch3_julia.jl`: kiểm thử phần Python và negFIN + CLI.
- `docs/Chapter3_notes.md`: khung giải thích báo cáo.
- `requirements-ch3.txt`: dependencies Python.

## Chạy trên Windows (PowerShell từ thư mục gốc `Frequent_Itemset_Mining`)

Yêu cầu **Python >= 3.10**, **Julia >= 1.9**, Julia trong `PATH` (hoặc cấu hình biến môi trường `JULIA_BIN`).

```powershell
python -m pip install -r requirements-ch3.txt
julia --project=. -e 'using Pkg; Pkg.instantiate()'
python -m pytest -q tests/test_ch3.py
julia --project=. tests/runtests.jl
julia --project=. tests/test_ch3_julia.jl
python -m applications.run_market
python -m applications.run_visual
```

Nếu tải dữ liệu Groceries không được, tải CSV từ nguồn được định nghĩa trong `applications/market_basket.py`, đặt tại `data/application/groceries.csv`. Không cần giao diện.

## Colab

1. Push phần Chương 3 vào repository nhóm và kiểm tra đường dẫn GitHub trong ô `REPO_URL` của notebook.
2. Mở `notebooks/demo.ipynb` trên Google Colab, dùng Python runtime, Run all.
3. Mọi kết quả phải sinh lại từ đầu: không dùng số liệu mô phỏng/ước đoán làm kết quả khoa học.
4. Cập nhật link Colab trong README; báo cáo IEEE phải có phân tích bảng/biểu đồ thực tế.

## Tình trạng kiểm chứng

- Kiểm thử Python: chạy lại bằng lệnh pytest; đây **không** thay cho kiểm thử end-to-end với Julia.
- Kiểm thử Julia + chạy hai ứng dụng thực tế: yêu cầu máy có Julia, hiện máy tạo gói không có Julia.
- Tất cả những mục có kết quả trong Chương 1–2 được giữ nguyên như ZIP gốc. Không mặc định coi kết quả Chương 1–2 đã được mình kiểm chứng chỉ dựa vào ảnh/README.

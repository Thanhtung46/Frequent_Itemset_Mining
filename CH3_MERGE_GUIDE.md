# Tích hợp Chương 3 Julia vào GitHub nhóm

Bản **Chapter3_Julia_only.zip** chỉ chứa các file mới của Chương 3. Nên dùng bản này để ghép với repository `datamining` hiện tại nếu các thành viên đã chỉnh sửa thêm Chương 1–2. Không cần ghi đè `src/`, `Project.toml`, các bài benchmark hay file Chương 1–2.

## Các thư mục cần chép

- `applications/*.jl`: code của cả hai ứng dụng, bao gồm cầu nối trực tiếp tới negFIN của nhóm.
- `data/chapter3/digits8x8.csv` và `SOURCE.md`: dữ liệu Digits và trích dẫn nguồn.
- `notebooks/demo.ipynb`, `ch3_market_basket.ipynb`, `ch3_visual_words.ipynb`: notebook Colab (chỉ gọi Julia).
- `tests/test_ch3_julia.jl`: kiểm thử Chương 3.
- `docs/Chapter3_notes.md`: hướng dẫn phân tích và diễn giải kết quả.

## Trên Windows (PowerShell) tại thư mục repo

```powershell
julia --version
julia --project=. tests/runtests.jl
julia --project=. tests/test_ch3_julia.jl
julia --project=. applications/run_market.jl
julia --project=. applications/run_visual.jl
```

Nếu tải Groceries bị lỗi do mạng, tải file nguồn trong `data/chapter3/SOURCE.md` và đặt là `data/chapter3/groceries.csv`, rồi chạy lại.

Khi test pass, mở `results/chapter3/` để xem CSV/SVG. Nên thêm `results/chapter3/` và `data/chapter3/groceries.csv` vào `.gitignore` của nhóm. Thêm link public `notebooks/demo.ipynb` trong README sau khi push lên GitHub.

## Git an toàn khi làm việc nhóm

```powershell
git status
git add applications/ data/chapter3/ notebooks/demo.ipynb notebooks/ch3_market_basket.ipynb notebooks/ch3_visual_words.ipynb tests/test_ch3_julia.jl docs/Chapter3_notes.md
git commit -m "feat: migrate Chapter 3 applications to Julia"
git push origin main
```

**Không chạy `git push --force`** chỉ để tích hợp Chương 3. Nếu đã có chỉnh sửa của đồng đội, kiểm tra `git diff --stat` trước khi commit.

### Cần xác nhận trước khi nộp

1. Julia test Chương 1–2 và Chương 3 đều pass.
2. Hai ứng dụng chạy trên dữ liệu thực, không chỉ chạy toy unit tests.
3. Chạy notebook Colab từ trên xuống, lưu output thật.
4. Báo cáo đúng phương pháp: Bag of Visual Words này dùng dense **gradient descriptors** tự viết, không phải SIFT/ORB.
5. Tự giải thích được lựa chọn thuật toán và quá trình tiền xử lý; không trình bày số liệu chưa thực sự chạy.

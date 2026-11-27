# Chương 3 – Ứng dụng thực tế negFIN, thuần Julia

Đây là hướng dẫn **quy trình và cách giải thích** để nhóm tự viết báo cáo. Không phải kết quả thực nghiệm đã kiểm chứng. **Không điền số liệu tự tưởng tượng**; chạy notebook trên máy/Colab có Julia trước khi trích dẫn số liệu.

## Mục tiêu và nguồn thuật toán

Hai ứng dụng dùng chính `negfin_baseline(...)` hoặc `negfin_optimized(...)` của nhóm trong `src/algorithm/`. Các file đó không được viết lại trong Chương 3. Toàn bộ thuật toán Chương 3 được thực thi bằng **Julia**. Nếu chạy trên Colab, notebook dùng metadata `Python 3` để Colab hiểu các ô `%%bash` và `!julia`; kernel này **không chạy thuật toán FIM hay phần ứng dụng bằng Python**. Không có yêu cầu cài `pip`, OpenCV hoặc scikit-learn để tái hiện Chương 3.

## Ứng dụng 1 — Market Basket Analysis

- **Nguồn**: Groceries – 9.835 giao dịch của cửa hàng bán lẻ, 169 nhóm sản phẩm theo tài liệu `arules`. Tải CSV từ nguồn được ghi trong `applications/market_basket.jl` vào `data/chapter3/groceries.csv` khi chạy lần đầu (máy cần Internet).
- **Chuyển đổi**: mỗi dòng CSV là một giao dịch; bỏ ô rỗng, chuẩn hóa khoảng trắng, loại item lặp trong một giao dịch; từ điển sản phẩm xếp thứ tự chữ cái rồi ánh xạ sang ID nguyên 1..N. File `transactions.spmf` và `item_mapping.csv` cho phép tái hiện.
- **Khai thác**: gọi `mine_itemsets` là cầu nối đến `negfin_baseline`/`negfin_optimized`. Có kiểm tra `support` bằng cách đếm giao dịch trực tiếp để phát hiện sai lệch.
- **Sinh luật**: từ từng frequent itemset Z (|Z| >= 2), xét mọi tập con X khác rỗng và khác Z, Y = Z\X. Dùng support đã khai thác, không gọi thư viện luật kết hợp.
  - `support(X→Y) = count(X∪Y)/N`
  - `confidence(X→Y) = count(X∪Y)/count(X)`
  - `lift(X→Y) = confidence(X→Y)/(count(Y)/N)`
  - `leverage(X→Y) = support(X∪Y) − support(X) × support(Y)`
- **Output**: `results/chapter3/market_basket/` chứa toàn bộ luật, `top10_lift.csv`, `top10_lift.svg`, mapping và summary. Diễn giải 10 luật đầu tiên **theo số liệu thực**. Lift lớn hơn 1 nói lên tương quan dương, **không chứng minh quan hệ nhân quả** hay lợi nhuận; cân nhắc support/confidence trước khi đề xuất nghiệp vụ.

## Ứng dụng 2 — Bag of Visual Words từ ảnh Digits

- **Nguồn**: UCI Optical Recognition of Handwritten Digits, bản 8×8 (tệp CSV có 1.797 ảnh), tham chiếu từ dữ liệu Digits công khai. `data/chapter3/digits8x8.csv` đã được đóng gói sẵn. Tài liệu `scikit-learn: load_digits` chỉ là **nguồn tham khảo về cách phân phối dữ liệu**, không phải dependency của mã Julia. Chỉ phân tích các chữ số 0, 1, 3, 8; giới hạn tối đa 150 mẫu mỗi lớp nhằm rút ngắn thời gian demo.
- **Tách dữ liệu**: chia train/test theo từng lớp (75%/25%) với seed `42`, không dùng nhãn để đưa vào giao dịch khai thác.
- **Trích descriptor**: tự cài đặt 9 local descriptors/image trên lưới 3×3, mỗi descriptor gồm trung bình cường độ, độ lệch chuẩn và bốn đặc trưng hướng gradient dương/âm. Đây là **hand-crafted dense gradient descriptors**, **không phải SIFT/ORB**. Khác biệt này phải nêu rõ nếu trình bày.
- **Codebook**: k-means tự cài bằng Julia, khởi tạo có seed, với mặc định K=16. Codebook chỉ học trên descriptor của ảnh **train**. Mỗi ảnh -> 9 descriptor -> centroid ID -> một transaction gồm các visual-word ID khác nhau; loại lặp trong cùng ảnh.
- **Khai thác**: chạy negFIN trên tập giao dịch train, `minsup` mặc định 0.12; chọn tối đa 60 frequent patterns dài >= 2 để nghiên cứu. Nhãn ảnh chỉ dùng **sau** quá trình khai thác.
- **Diễn giải**: `enrichment(P, C) = P(P xuất hiện | class = C) / P(P xuất hiện)` tính trên train. Giá trị lớn cho thấy pattern đặc trưng hơn cho lớp C, nhưng không cho phép khẳng định visual word ứng với một nét chữ cụ thể.
- **Đánh giá ứng dụng**: cùng một bộ phân loại nearest-centroid tự cài, so sánh đặc trưng chỉ gồm visual words với visual words + frequent patterns, đo trên **test chưa được dùng trong bước chọn pattern**. Không giả định thêm pattern luôn cải thiện độ chính xác.
- **Output**: `results/chapter3/visual_words/` gồm dữ liệu giao dịch, itemsets, codebook, mẫu ảnh SVG, pattern-enrichment CSV/SVG và so sánh accuracy.

**Giới hạn**: ảnh Digits 8×8 rất nhỏ và khác đáng kể ảnh tự nhiên (như CIFAR/Caltech); đặc trưng gradient tự cài không tương đương SIFT, và nearest-centroid chỉ là bộ phân loại minh họa. Nếu muốn đánh giá trên ảnh tự nhiên, cần thêm bộ dữ liệu và thiết kế descriptor phù hợp. Các hạn chế phải ghi trung thực trong báo cáo.

## Chạy và kiểm tra

```powershell
julia --project=. tests/runtests.jl
julia --project=. tests/test_ch3_julia.jl
julia --project=. applications/run_market.jl
julia --project=. applications/run_visual.jl
```

Ngoài ra, chạy `notebooks/demo.ipynb` trên Google Colab với **Python 3 kernel (chỉ là shell launcher)**. Các ô thực thi dùng `%%bash`/`!julia`, không import thư viện Python để xử lý dữ liệu hoặc khai thác itemset; notebook có bước cài Julia. Không thay metadata notebook sang Julia nếu vẫn sử dụng cú pháp shell đặc thù của Colab.

**Không dùng đầu ra cũ của bản Python làm bằng chứng chạy Julia.** Các tệp `summary.json`, `*.png` từng nằm trong `results/chapter3/` là kết quả phiên bản trước; bản Julia xuất `summary.txt`, CSV và SVG, cần chạy lại để thu số liệu xác thực.

### Bảng điền sau khi chạy thực tế

| Dữ liệu cần báo cáo | File đầu ra |
| --- | --- |
| Số giao dịch, itemsets, luật; thời gian chạy negFIN | `market_basket/summary.txt` |
| Top-10 luật support/confidence/lift | `market_basket/top10_lift.csv` |
| Biểu đồ top-10 | `market_basket/top10_lift.svg` |
| Số train/test, số pattern; accuracy | `visual_words/summary.txt` |
| Mẫu đặc trưng theo từng lớp | `visual_words/patterns_by_class.csv` |
| So sánh bộ phân loại | `visual_words/test_accuracy_comparison.csv` |
| Biểu đồ enrichment, ảnh ví dụ | `visual_words/enriched_patterns.svg`, `digits_samples.svg` |

## Nguồn tham khảo

1. [Đề bài FIM chính thức](https://hcmus-cs-ta.github.io/lab-book/data-mining/projects/itemset/).
2. [Hahsler et al., tài liệu dữ liệu Groceries](https://michael.hahsler.net/arules/reference/Groceries.html).
3. [scikit-learn: load_digits (mô tả ảnh 8×8)](https://scikit-learn.org/stable/modules/generated/sklearn.datasets.load_digits.html).
4. [negFIN: bài báo gốc – DOI](https://doi.org/10.1016/j.eswa.2018.03.041).
5. Sivic, J., Zisserman, A. (2003), *Video Google: A Text Retrieval Approach to Object Matching in Videos*, ICCV.

## Giải thích ngắn gọn khi vấn đáp

- **Vì sao dùng Julia?** Nhóm đã tự triển khai negFIN bằng Julia ở Chương 1–2; dùng tiếp ở Chương 3 giúp gọi trực tiếp thuật toán, không phải duy trì hai ngôn ngữ cho pipeline chạy thực tế.
- **Python có còn trong đồ án không?** Không có mã ứng dụng hay thuật toán Chương 3 bằng Python. Metadata `Python 3` của Colab và nguồn tham khảo `load_digits` không đồng nghĩa sử dụng thư viện Python.
- **Bảo đảm tính đúng đắn thế nào?** Chạy `tests/test_ch3_julia.jl` và đối chiếu support do negFIN trả về với phép đếm trên giao dịch; kiểm thử Chương 1–2 phải chạy riêng.
- **Tại sao chọn ảnh Digits?** Có dữ liệu nhỏ để kiểm tra quy trình và chạy demo. Đây là lựa chọn thuận tiện cho minh họa, không đủ để suy rộng kết quả cho dữ liệu ảnh tự nhiên.

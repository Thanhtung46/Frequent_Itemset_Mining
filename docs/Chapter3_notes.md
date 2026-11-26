# Ghi chú báo cáo Chương 3 — Ứng dụng thực tế của negFIN

> Nội dung bổ trợ viết báo cáo, không phải kết quả thực nghiệm đã được chạy. Mọi số đo, bảng top-10 và hình minh họa thực tế phải lấy từ output của notebook sau khi chạy **thành công** với Julia.

## 3.1 Mục tiêu và nguyên tắc

Chương 3 lựa chọn (i) phân tích giỏ hàng từ Groceries và (ii) khai thác mẫu trực quan từ UCI Digits. Nguồn frequent itemsets và support duy nhất của cả hai bài toán là cài đặt `negfin_baseline` Julia của nhóm. Mã Python không tự khai thác frequent itemsets bằng thư viện có sẵn.

## 3.2 Ứng dụng 1 — Phân tích giỏ hàng

### Dữ liệu và biểu diễn

Dữ liệu **Groceries** có 9.835 hóa đơn trong 30 ngày, thuộc 169 loại sản phẩm theo tài liệu `arules` (Hahsler, Hornik và Reutterer). Mỗi dòng CSV là một hóa đơn; mỗi hàng hóa là một item, không đếm nhiều lần cùng một loại trong một hóa đơn. Ô trống bị bỏ qua. Mã hóa ID theo tên sản phẩm đã sắp từ điển để lần chạy sau cho cùng biểu diễn.

### Luật kết hợp

Với luật `X -> Y`, `X` và `Y` không rỗng và không giao nhau. `N` là tổng số giao dịch, `c(Z)` là số giao dịch chứa `Z`.

- `support(X -> Y) = c(X union Y) / N`
- `confidence(X -> Y) = c(X union Y) / c(X)`
- `lift(X -> Y) = confidence(X -> Y) / support(Y)`
- `leverage(X -> Y) = support(X union Y) - support(X)*support(Y)`

Mặc định dùng `minsup = 0.01` và `minconf = 0.15`, xuất toàn bộ luật đủ ngưỡng và top-10 theo lift. Việc sinh luật được viết từ support do negFIN trả về. Kiểm chứng support bằng cách đếm trực tiếp mỗi itemset đã khai thác trên giao dịch gốc; đây **không** phải thuật toán FIM thay thế hay phép so khớp SPMF.

### Diễn giải kinh doanh

Luật có lift > 1 thể hiện quan hệ đồng xuất hiện mạnh hơn kỳ vọng độc lập, không chứng minh rằng mua X **gây ra** việc mua Y. Trước khi đề xuất khuyến mãi, cần đồng thời xem support và confidence, đánh giá độ phổ biến, và kiểm chứng bằng A/B test. Dữ liệu không chứa doanh thu, số lượng, giá bán, tồn kho nên không thể suy luận trực tiếp lợi nhuận.

## 3.3 Ứng dụng 2 — Bag of Visual Words trên ảnh

### Dữ liệu và biểu diễn

Dùng bộ dữ liệu ảnh chữ số viết tay **UCI Digits** (phiên bản `sklearn.datasets.load_digits`: 1.797 ảnh 8×8, 10 lớp). Thử nghiệm lấy 4 lớp 0, 1, 3, 8 để kiểm tra pattern đặc trưng theo nhãn. Trước hết chia dữ liệu train/test 75/25 có stratify, seed = 42, tránh rò rỉ thông tin kiểm thử.

Trên từng ảnh, tăng kích thước 8×8 lên 96×96 bằng nội suy bicubic; trích SIFT (Scale-Invariant Feature Transform) tại 4×4 điểm cố định, nhận 16 vector mô tả 128 chiều. K-means với K = 24, random_state = 42 được huấn luyện **chỉ trên descriptor ảnh train**. Mỗi descriptor gán cho một visual word; một ảnh là một giao dịch các ID visual word xuất hiện, ID bắt đầu từ 1. Loại bỏ số lần lặp của một word trong cùng ảnh theo đúng định nghĩa transaction set.

### Khai thác pattern và phân tích

Chạy negFIN trên **train transactions** với minsup = 0.08. Lấy itemset độ dài >= 2, tính độ giàu tính đặc trưng theo lớp:

`enrichment(P, C) = P(P | C) / P(P)`

Tính trên train đã có nhãn, **nhãn không được đưa vào transaction lúc khai thác**. Những pattern nhiều lần xuất hiện ở lớp C hơn tỉ lệ chung có thể liên hệ cấu trúc nét trong lớp đó, nhưng visual word là cụm trong không gian mô tả SIFT, không phải nhãn nét chữ rõ ràng như 'nét cong'.

### Đánh giá downstream

Chọn tối đa 100 pattern nhiều hỗ trợ từ train; tạo binary features cho cả train và test. So sánh cùng bộ phân loại Logistic Regression giữa (a) chỉ visual words và (b) visual words + frequent patterns. Báo cáo test accuracy; không giả định phiên bản có frequent patterns luôn tốt hơn. Lưu ý ảnh Digits độ phân giải thấp và không đại diện ảnh tự nhiên.

## 3.4 Tái lập và kiểm thử

- Chạy `python -m pytest -q tests/test_ch3.py` kiểm tra cấu trúc SPMF, phép sinh luật và xử lý ảnh.
- Chạy cả 2 notebook từ trên xuống trên Colab có Julia, thu output/biểu đồ trong `results/chapter3/`.
- Trong hai pipeline, support itemset negFIN được đếm trực tiếp để kiểm tra. Cần thêm so khớp SPMF đầy đủ như Chương 1 khi nhóm hoàn thiện.
- Seed: 42. Các thư viện được pin major version ở `requirements-ch3.txt`. Môi trường Python và Julia nên được ghi cụ thể trong báo cáo.

## 3.5 Điền số liệu thực tế sau khi chạy (không bịa số)

| Phần | Số liệu cần điền | File sinh tự động |
|---|---|---|
| Market Basket | Số giao dịch, sản phẩm, itemset, luật | `market_basket/summary.json` |
| Market Basket | Top-10 luật, support, confidence, lift | `market_basket/top10_by_lift.csv` |
| Market Basket | Biểu đồ luật | `market_basket/top10_lift.png` |
| Visual | Số ảnh train/test, số patterns | `visual_words/summary.json` |
| Visual | Pattern đặc trưng từng lớp | `visual_words/patterns_by_class.csv` |
| Visual | So sánh test accuracy | `visual_words/test_accuracy_comparison.csv` |
| Visual | Biểu đồ phân tích | `visual_words/enriched_patterns.png` |

## Nguồn tham khảo

1. Aryabarzan, Minaei-Bidgoli, Teshnehlab (2018). *negFIN: An efficient algorithm for fast mining frequent itemsets*. Expert Systems With Applications, 105, 129–143. (Bản PDF do nhóm cung cấp.)
2. Hahsler, Hornik, Reutterer (2006). *Implications of probabilistic data modeling for mining association rules*. Tài liệu nguồn Groceries: https://michael.hahsler.net/arules/reference/Groceries.html
3. scikit-learn: *load_digits*. https://scikit-learn.org/stable/modules/generated/sklearn.datasets.load_digits.html
4. Lowe (2004). *Distinctive Image Features from Scale-Invariant Keypoints*. International Journal of Computer Vision.
5. Sivic & Zisserman (2003). *Video Google: A Text Retrieval Approach to Object Matching in Videos*. ICCV.

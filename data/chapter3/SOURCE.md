# Nguồn dữ liệu Chương 3

- **Groceries**: bản CSV 9.835 giao dịch, tải tự động khi chạy từ <https://raw.githubusercontent.com/Elthiero/association-rule-learning-groceries/main/data/groceries.csv>. Nguồn gốc bộ dữ liệu: R `arules`, <https://michael.hahsler.net/arules/reference/Groceries.html>. Không commit file dữ liệu lớn vào repo, đặt tại `data/chapter3/groceries.csv` (được `.gitignore`).
- **Digits 8×8**: `digits8x8.csv` chứa 1.797 ảnh; cột đầu là nhãn 0–9, 64 cột tiếp là pixel 8×8 theo hàng, giá trị 0–16. Nguồn công khai: bộ UCI Optical Recognition of Handwritten Digits phân phối dưới `sklearn.datasets.load_digits` (<https://scikit-learn.org/stable/modules/generated/sklearn.datasets.load_digits.html>). File CSV được xuất trước và chỉ là dữ liệu đầu vào, không đòi hỏi người chạy cài Python.

Các ứng dụng Chương 3 được viết bằng Julia. Không dùng bất kỳ thư viện FIM ngoài code của nhóm.

# Nguồn dữ liệu Chương 3

- **Groceries**: bản CSV 9.835 giao dịch, tự động tải từ Hugging Face mirror của nhóm (<https://huggingface.co/datasets/stephent9/Lab1_Frequent_Itemset_Mining/resolve/main/groceries.csv>, fallback về GitHub raw). Nguồn gốc bộ dữ liệu: R `arules`, <https://michael.hahsler.net/arules/reference/Groceries.html>. Đặt tại `data/chapter3/groceries.csv` (được `.gitignore`).
- **Digits 8×8**: `digits8x8.csv` chứa 1.797 ảnh; cột đầu là nhãn 0–9, 64 cột tiếp là pixel 8×8 theo hàng, giá trị 0–16. Host tại Hugging Face (<https://huggingface.co/datasets/stephent9/Lab1_Frequent_Itemset_Mining/resolve/main/digits8x8.csv>) và có bản sẵn trong `data/chapter3/digits8x8.csv`. Nguồn gốc công khai: UCI Optical Recognition of Handwritten Digits (<https://scikit-learn.org/stable/modules/generated/sklearn.datasets.load_digits.html>).

Các ứng dụng Chương 3 được viết bằng Julia. Không dùng bất kỳ thư viện FIM ngoài code của nhóm.

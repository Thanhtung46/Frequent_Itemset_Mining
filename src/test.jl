# Khai báo biến (hỗ trợ cả ký tự Unicode: gõ \alpha rồi nhấn Tab)
x = 10                  # Int64 (Số nguyên)
pi_val = 3.14           # Float64 (Số thực)
α = 0.5                 # Biến ký tự toán học
is_valid = true         # Bool (true / false)

# Chuỗi (luôn dùng ngoặc kép "") và Ký tự (ngoặc đơn '')
ten = "Julia"
ky_tu = 'J'

# Nối chuỗi dùng dấu * (KHÔNG dùng dấu +)
loi_chao = "Xin chào " * ten

# Chèn biến vào chuỗi (String Interpolation) dùng dấu $
println("Giá trị của x là $x, và x + 5 = $(x + 5)")
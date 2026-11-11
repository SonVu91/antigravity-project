# 🚀 Antigravity Project Hub

Kho lưu trữ Monorepo trung tâm quản lý tất cả các dự án phát triển với **Google Antigravity AI**, đồng bộ trực tiếp hai chiều với GitHub:
**Repository:** [https://github.com/SonVu91/antigravity-project](https://github.com/SonVu91/antigravity-project)

---

## 📂 Danh mục các dự án (Projects Catalog)

| # | Dự án | Mô tả | Công nghệ | Trạng thái |
| :--- | :--- | :--- | :--- | :--- |
| **02** | [**2. Tạo ví Cardano v2.0**](./2.%20Tạo%20ví%20Cardano%20v2.0/) | **Cardano Hot Wallet & Watch-Only Hub v2.0**: Ứng dụng ví nóng Cardano đa thiết bị, chạy Web PWA trực tiếp qua GitHub Pages và bộ cài Android APK (32-bit & 64-bit). Quản lý tài khoản, theo dõi số dư, staking qua Blockfrost API và xây dựng giao dịch Conway CIP-1694. | Flutter Web/Android, Rust FFI, Dart Pure | 🚀 [Chạy Web Trực Tiếp](https://sonvu91.github.io/antigravity-project/) |
| **03+** | *Các dự án tiếp theo* | Sẽ được tự động thêm vào thư mục riêng (`3. Ten_Du_An/...`) và đồng bộ lên repository này. | Đa nền tảng | ⏳ Đang mở rộng |

---

## 🌐 Trải nghiệm Trực Tuyến
* **Web Hot Wallet PWA (GitHub Pages):** [https://sonvu91.github.io/antigravity-project/](https://sonvu91.github.io/antigravity-project/)
* Tương thích hoàn toàn trên mọi trình duyệt: Chrome, Safari (iOS), Edge, Firefox, không cần cài đặt.

---

## 🔄 Quy trình làm việc đa máy tính (Multi-Device Workflow)

Khi bạn sử dụng Antigravity trên nhiều máy tính khác nhau (máy ở nhà, máy cơ quan, laptop), làm theo quy trình đơn giản sau để dữ liệu luôn luôn khớp nhau 100%:

```
[Bắt đầu ngày / Bật máy]  ---> Chạy sync_pull.bat   ---> Nhận code & ngữ cảnh mới nhất
[Lập trình cùng AI]        ---> Thực hiện dự án     ---> Antigravity hỗ trợ
[Kết thúc phiên làm việc] ---> Chạy sync_push.bat   ---> Đẩy an toàn lên GitHub
```

### 1. Khi mở máy tính để bắt đầu làm việc:
Click đúp chuột vào:
```cmd
sync_pull.bat
```
*(hoặc chạy `.\sync_pull.ps1` trong PowerShell)*. Kịch bản sẽ tự động kéo tất cả các thay đổi mà bạn đã thực hiện từ các máy tính khác về máy hiện tại.

### 2. Khi hoàn thành công việc hoặc muốn lưu tiến độ:
Click đúp chuột vào:
```cmd
sync_push.bat
```
*(hoặc chạy `.\sync_push.ps1` trong PowerShell)*. Kịch bản sẽ tự động gom toàn bộ thay đổi của tất cả các dự án, tạo commit rõ ràng và đẩy lên GitHub.

---

## 💻 Thiết lập lần đầu trên một máy tính mới

Khi bạn vừa tải hoặc mở repo này trên một máy tính hoàn toàn mới:

1. **Clone repository về máy:**
   ```bash
   git clone https://github.com/SonVu91/antigravity-project.git
   cd antigravity-project
   ```
2. **Chạy kịch bản khởi tạo 1-click:**
   Click đúp chuột vào `setup_new_machine.bat` (hoặc chạy `.\setup_new_machine.ps1`). Kịch bản sẽ:
   * Tự động cấu hình danh tính Git (`SonVu91` / `SonVu91@users.noreply.github.com`).
   * Kiểm tra các công cụ lập trình cần thiết (Flutter, Rust `cargo`, Python, Git).
   * Tạo sẵn các tệp cấu hình mẫu (`.env.example`).
3. **Mở Antigravity:**
   Mở thư mục gốc trong Antigravity IDE. Trợ lý AI sẽ tự động đọc `AGENTS.md` và các kỹ năng trong `.agents/` để tiếp tục công việc liền mạch!

---

## 🛡️ Cam kết an toàn & bảo mật
* Các khóa riêng tư, seed phrase và API key cá nhân được bảo vệ nghiêm ngặt qua `.gitignore` và không bao giờ bị đưa lên GitHub.
* Sử dụng xác thực an toàn qua Git Credential Manager hoặc GitHub Personal Access Token.

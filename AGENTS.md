# Antigravity Monorepo - Workspace Rules & Multi-Device Sync Protocol

Chào mừng trợ lý AI Antigravity đến với không gian làm việc Monorepo đa dự án.
Kho lưu trữ này được đồng bộ liên tục với GitHub: `https://github.com/SonVu91/antigravity-project.git`.

Tài liệu này định nghĩa các quy tắc cốt lõi để đảm bảo dữ liệu, mã nguồn và ngữ cảnh luôn nhất quán, an toàn khi người dùng chuyển đổi làm việc giữa nhiều máy tính khác nhau.

---

## 1. Cấu trúc tổ chức Monorepo

```
E:\Antigravity\  (hoặc thư mục gốc trên máy tính khác)
├── 2. Tạo ví Cardano v2.0/           # Dự án 2: Cardano Hot Wallet & Watch-Only Hub v2.0
│   ├── .agents/                      # Kỹ năng AI cấp dự án (Security, Code-Review)
│   ├── cardano_airgap_bridge/        # Thư viện Dart pure & FFI Bridge
│   ├── mobile_online/                # Ứng dụng Flutter Hot Wallet (Web PWA & Android APK)
│   ├── rust_cardano_core/            # Thư viện lõi Rust mật mã & Bech32
│   ├── output/                       # Các bản build release (APK Hot Wallet, Web bundle)
│   └── docs/                         # Tài liệu kỹ thuật & kiểm định an ninh
├── 3. [Dự án tiếp theo]/             # Các dự án về sau sẽ nằm trong từng thư mục riêng
├── AGENTS.md                         # Quy tắc AI toàn hệ thống (tệp này)
├── README.md                         # Tài liệu tổng thể Monorepo & Hướng dẫn bắt đầu nhanh
├── sync_pull.bat / .ps1              # Kịch bản 1-click kéo code mới từ GitHub khi mở máy
├── sync_push.bat / .ps1              # Kịch bản 1-click commit & push code lên GitHub khi xong việc
└── setup_new_machine.bat / .ps1      # Kịch bản 1-click thiết lập môi trường trên máy tính mới
```

---

## 2. Quy trình làm việc đa máy tính (Multi-Device Protocol)

Mỗi khi người dùng bắt đầu một phiên làm việc mới trên bất kỳ máy tính nào:
1. **Kiểm tra trạng thái đồng bộ ban đầu:**
   * Trợ lý AI hãy chủ động nhắc nhở người dùng hoặc kiểm tra xem máy hiện tại đã có mã nguồn mới nhất từ GitHub chưa.
   * Nếu người dùng vừa mở máy hoặc chuyển từ máy khác sang, khuyến nghị chạy `sync_pull.bat` (hoặc `git pull --rebase origin main`) để cập nhật các thay đổi mới nhất.
2. **Trong quá trình làm việc:**
   * Phát triển mã nguồn, viết tài liệu và kiểm thử tuân thủ các quy tắc chất lượng cao.
   * Khi tạo dự án mới, luôn đặt trong một thư mục con được đánh số thứ tự (ví dụ: `2. Tên Dự Án`).
3. **Kết thúc phiên làm việc:**
   * Trợ lý AI nhắc nhở hoặc hỗ trợ người dùng chạy `sync_push.bat` để gom toàn bộ thay đổi, tạo commit có thông điệp rõ ràng theo chuẩn Semantic Commit (`feat:`, `fix:`, `docs:`, `chore:`) và đẩy lên GitHub.
   * Nhờ đó, khi người dùng sang máy tính khác, dữ liệu luôn ở trạng thái mới nhất.

---

## 3. Quy chuẩn bảo mật bất biến (Security Invariants)

* **TUYỆT ĐỐI KHÔNG BAO GIỜ COMMIT HOẶC ĐẨY LÊN GITHUB:**
  1. Thư mục chứa ví thật, cụm từ khôi phục (seed phrase / mnemonic 12/15/24 từ), hoặc khóa riêng tư (`wallets/`, `*.skey`, `root.xprv`).
  2. Tệp cấu hình chứa API key thật (ví dụ: `online/config.env` chứa key Blockfrost cá nhân).
* **Quy chuẩn:** Luôn chỉ đẩy tệp mẫu cấu hình (như `config.env.example`). Người dùng trên máy mới sẽ sao chép thành `config.env` và điền key riêng tại máy đó.

---

## 4. Hướng dẫn thêm dự án mới trong tương lai

Khi người dùng muốn tạo một dự án mới:
1. Tạo thư mục mới tại thư mục gốc: `E:\Antigravity\<Số thứ tự>. <Tên dự án>` (hoặc tương ứng trên máy tính khác).
2. Tạo tệp `README.md` riêng cho dự án đó để mô tả chức năng, cách chạy và kiểm thử.
3. Đồng bộ dự án mới lên GitHub chỉ bằng 1 thao tác: chạy `sync_push.bat`. Hệ thống sẽ tự động nhận diện thư mục dự án mới và đưa lên nhánh `main` của repository `antigravity-project`.

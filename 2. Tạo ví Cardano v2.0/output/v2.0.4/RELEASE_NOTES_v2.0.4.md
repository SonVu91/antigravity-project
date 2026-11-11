# BẢN GHI PHÁT HÀNH HỆ THỐNG VÍ CARDANO AIR-GAP v2.0.4
## (Cardano Air-Gap Vault - UX Ergonomics & Samsung J7 Prime Optimization)

- **Ngày phát hành:** 11/11/2026
- **Phiên bản:** v2.0.4 (Official Production Release)
- **Mã SHA256 Checksums:** Xem tại `SHA256SUMS-v2.0.4.txt`
- **Mục tiêu chính:** Tối ưu hóa toàn diện công thái học (UX) cho màn hình di động 16:9 và điện thoại Samsung Galaxy J7 Prime.

---

### 🌟 CÁC ĐIỂM NỔI BẬT & CẢI TIẾN TRONG BẢN v2.0.4

1. **Khắc Phục Triệt Để Lỗi Từ Khóa Bị Ẩn (`...`) Khi Tạo Ví Mới:**
   - Chuyển bố cục lưới hiển thị cụm từ bảo mật (Seed Phrase 12, 15, 24 từ) từ 3 cột chật hẹp sang **2 cột rộng rãi** (~160dp mỗi ô).
   - Tích hợp `FittedBox(fit: BoxFit.scaleDown)` với font chữ 15.5pt đậm nét: Mọi từ khóa BIP-39 dài (như *congratulations, infrastructure, responsibility, satisfaction...*) đều hiển thị trọn vẹn 100%, không bao giờ bị cắt cụt bằng dấu `...`.
   - Bổ sung nút **"Dán từ Clipboard"** và **"Xóa nhanh"** ở màn hình Khôi phục ví bằng Seed phrase.

2. **Khôi Phục & Nạp Bản Sao Lưu Đa Phương Thức:**
   - **Tự động quét tệp sao lưu trên thiết bị (`.coldbackup`):** Ứng dụng tự động tìm các tệp sao lưu gần nhất trong bộ nhớ thiết bị và hiển thị thành các nút chạm nhanh (Action Chips). Người dùng chạm 1 lần là nạp ngay đường dẫn mà không cần gõ hay sao chép đường dẫn thủ công.
   - **Tích hợp Dán từ Clipboard & Quét mã QR:** Bổ sung các icon tiện ích trực tiếp trong khung văn bản.

3. **Tách Riêng Bước Xác Thực Mã PIN — Chống Bàn Phím Số Che Khuất:**
   - Ở màn hình Xem trước bản sao lưu (Preview): Loại bỏ ô nhập PIN khỏi danh sách ví, tập trung hiển thị danh sách ví và 2 nút lựa chọn: **"Hợp Nhất (Merge)"** hoặc **"Thay Thế (Replace)"**.
   - Khi chọn hành động, hệ thống hiển thị **Hộp thoại xác thực PIN chuyên dụng**: Ô PIN hiển thị to rõ với ký tự bảo mật (`••••••`) nằm ngay trên bàn phím số, giúp người dùng vừa gõ vừa nhìn thấy trạng thái nhập, không còn bị bàn phím che khuất hay đè bẹp như trước.

4. **Chống Tràn Giao Diện Toàn Diện Trên Màn Hình Nhỏ:**
   - Cấu hình `scrollable: true` và `ConstrainedBox` cho tất cả các hộp thoại trong hệ thống (`cold_settings_screen.dart`, `cold_wallet_manager_dialog.dart`).
   - Tự động cuộn theo khoảng đệm bàn phím ảo (`viewInsets.bottom`), đảm bảo các nút "Hủy", "Áp Dụng", "Xác Nhận" luôn hiển thị trọn vẹn.

---

### 📦 DANH MỤC CÁC TỆP ĐÓNG GÓI TRONG THƯ MỤC /output/v2.0.4/

- **`cardano-cold-wallet-v2.0.4-armv7.apk`**: Bản rút gọn 32-bit ARMv7 dành riêng cho Samsung Galaxy J7 Prime và các dòng chip 32-bit.
- **`cardano-cold-wallet-v2.0.4-arm64.apk`**: Bản rút gọn 64-bit ARMv8 tối ưu cho máy Android hiện đại.
- **`cardano-cold-wallet-v2.0.4-universal.apk`**: Bản Universal tương thích mọi thiết bị Android.
- **`cardano-cold-wallet-v2.0.4.apk`**: Bản cài đặt mặc định cho Ví Lạnh.
- **`cardano-hot-wallet-v2.0.4-universal.apk`**: Ví Nóng Android Universal v2.0.4.
- **`SHA256SUMS-v2.0.4.txt`**: Bảng mã băm SHA-256 xác minh tính toàn vẹn FIPS 140-3.

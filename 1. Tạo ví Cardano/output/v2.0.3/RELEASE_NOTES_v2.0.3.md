# BẢN GHI PHÁT HÀNH HỆ THỐNG VÍ CARDANO AIR-GAP v2.0.3
## (Cardano Air-Gap Vault - Multi-Network & Production Release v2.0.3)

- **Ngày phát hành:** 10/11/2026
- **Phiên bản:** v2.0.3 (Official Production Release)
- **Mã SHA256 Checksums:** Xem tại `SHA256SUMS-v2.0.3.txt`
- **Tài liệu đặc tả kỹ thuật chi tiết:** `docs/tech-document-final.md`

---

### 🌟 CÁC ĐIỂM NỔI BẬT & CẢI TIẾN TRONG BẢN v2.0.3

1. **Bộ Chuyển Đổi Môi Trường Mạng 3 Trong 1 (Multi-Network Environment):**
   - Hỗ trợ đầy đủ 3 môi trường mạng cốt lõi của Cardano: **Mainnet**, **Preprod Testnet**, và **Preview Testnet** (đồng bộ 1:1 giữa Ví Lạnh và Ví Nóng).
   - Tích hợp **Network Badge** trực quan trên thanh tiêu đề (AppBar) với mã màu nhận diện bảo mật cao:
     - 🟢 **Cardano Mainnet** (Mạng chính thức - Tài sản ADA thật)
     - 🟠 **Preprod Testnet** (Môi trường kiểm thử dài hạn)
     - 🔵 **Preview Testnet** (Môi trường tính năng cập nhật mới)
   - Chạm nhanh vào Badge hoặc truy cập Cài đặt để chuyển đổi mạng bằng Modal Bottom Sheet tiện lợi.

2. **Cơ Chế Tự Động Tái Dẫn Xuất Địa Chỉ (Dynamic Derivation Engine):**
   - Khi chuyển đổi mạng, toàn bộ ví đang quản lý và ví đang kích hoạt sẽ **tự động tính toán lại định dạng địa chỉ nhận tiền và địa chỉ stake** (`addr1...` <-> `addr_test1...`) từ cùng một khóa gốc CIP-1852 mà không cần xóa ví hay nhập lại cụm từ khôi phục.
   - Thẻ hiển thị mã QR công khai trên Dashboard cập nhật tức thì theo mạng đã chọn.

3. **Chốt Chặn An Toàn Lệch Mạng Nghiêm Ngặt (Strict Network Guard):**
   - Tự động phân tích toàn bộ địa chỉ người nhận và địa chỉ hoàn tiền (Change Output) trong chuỗi `txRaw` khi quét mã QR hoặc dán CBOR Hex.
   - Nếu phát hiện giao dịch chứa địa chỉ thuộc môi trường mạng khác (ví dụ: quét giao dịch testnet khi đang ở chế độ Mainnet), hệ thống sẽ **báo động đỏ và vô hiệu hóa nút Ký duyệt** để ngăn ngừa tuyệt đối nguy cơ mất mát tài sản.

4. **Lưu Trữ Bền Vững & An Toàn Bộ Nhớ (Persistent & Secure Storage):**
   - Lựa chọn mạng được lưu trữ mã hóa trong `FlutterSecureStorage`.
   - Ứng dụng tự động khôi phục môi trường mạng đã chọn khi khởi động lại.
   - Khi tạo mới hoặc khôi phục ví, giao diện tự động đề xuất môi trường mạng hiện tại với các ChoiceChip trực quan.

5. **Giữ Nguyên 100% Tiêu Chuẩn Bảo Mật Air-Gap Tuyệt Đối:**
   - Hoàn toàn không cấp quyền Internet (`android.permission.INTERNET` bị loại bỏ 100%).
   - Tương thích hoàn toàn cả phần cứng **32-bit ARMv7 (Samsung Galaxy J7 Prime, Exynos 7870)** lẫn **64-bit ARMv8** thông qua Dual-Engine (Native Rust C-FFI & Pure-Dart Fallback).
   - Bảo vệ chống tấn công UTxO Change Hijacking (Change Guard).
   - Kiosk Sentinel chế độ khóa thiết bị Device Owner và cơ chế xóa sạch RAM khi vi phạm Air-Gap.

---

### 📦 DANH MỤC CÁC TỆP ĐÓNG GÓI TRONG THƯ MỤC /output/v2.0.3/

- **`apk/`**:
  - `cardano-cold-wallet-v2.0.3-armv7.apk`: Bản rút gọn dành riêng cho Samsung J7 Prime và máy 32-bit.
  - `cardano-cold-wallet-v2.0.3-arm64.apk`: Bản rút gọn tối ưu cho máy Android 64-bit.
  - `cardano-cold-wallet-v2.0.3-universal.apk`: Bản Universal tương thích mọi thiết bị Android.
  - `cardano-cold-wallet-v2.0.3.apk`: Bản cài đặt chuẩn cho Ví Lạnh.
  - `cardano-hot-wallet-v2.0.3-armv7.apk`: Ví Nóng Android 32-bit.
  - `cardano-hot-wallet-v2.0.3-arm64.apk`: Ví Nóng Android 64-bit.
  - `cardano-hot-wallet-v2.0.3-universal.apk`: Ví Nóng Android Universal.
  - `cardano-hot-wallet-v2.0.3.apk`: Bản cài đặt chuẩn cho Ví Nóng.
- **`SHA256SUMS-v2.0.3.txt`**: Bảng mã băm SHA-256 xác minh tính toàn vẹn FIPS 140-3.

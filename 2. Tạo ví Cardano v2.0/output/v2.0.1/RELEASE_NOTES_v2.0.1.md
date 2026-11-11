# BẢN GHI PHÁT HÀNH HỆ THỐNG VÍ CARDANO AIR-GAP v2.0.1
## (Cardano Air-Gap Vault - Enterprise Release v2.0.1)

- **Ngày phát hành:** 10/11/2026
- **Phiên bản:** v2.0.1 (Enterprise Gold Release)
- **Mã SHA256 Bundle:** Xem tại `SHA256SUMS.txt`
- **Tài liệu đặc tả kỹ thuật chi tiết:** `docs/tech-document-final.md`

---

### 🌟 CÁC ĐIỂM NỔI BẬT & CẬP NHẬT TRONG BẢN v2.0.1

1. **Bộ Chọn Động Account Index & Address Index (CIP-1852):**
   - Hỗ trợ tùy biến `account_index` và `address_index` linh hoạt (`m/1852'/1815'/account'/role/index`).
   - Cung cấp giao diện chuyển đổi tài khoản tức thì trên cả Ví Lạnh và Ví Nóng.

2. **Gia Cố Toàn Diện Mật Mã & Chống Tấn Công Ký Mù:**
   - Hoàn thiện bộ giải mã Conway CBOR (`tx_parser.rs`) hiển thị chi tiết người nhận, số tiền, phí mạng, token Native, chứng chỉ ủy thác DRep CIP-1694 và rút thưởng staking.
   - Thuật toán `Strict Change Guard`: Tự động xác thực trùng khớp Stake Credential và chuỗi địa chỉ nội bộ `role = 1`. Cảnh báo giao dịch 1 đầu ra (1-output protection).
   - Tiêu chuẩn `FIPS 140-3`: Tự xác minh chữ ký Ed25519 trong RAM ngay sau khi ký để phòng ngừa tiêm lỗi phần cứng (Fault Injection).
   - Tẩy xóa sâu bộ nhớ nhạy cảm với crate `zeroize`.

3. **Chốt Chặn An Ninh Kiosk Sentinel (Ví Lạnh):**
   - Hỗ trợ cấu hình Android Dedicated Device Owner (khóa thanh điều hướng, cấm Wi-Fi/Bluetooth/Data/USB transfer).
   - In-App Air-Gap Sentinel Watchdog phát hiện mạng và kích hoạt Màn hình Khóa Khẩn Cấp (Emergency Lockdown).
   - Mã PIN 6 số băm PBKDF2 200k vòng, tự hủy sạch dữ liệu (Auto-Wipe) sau 5 lần nhập sai liên tiếp.

4. **Giao Thức Quang Học Adaptive Dual-Mode QR:**
   - Dưới 500 bytes: `UR:CARDANO-TX/` (Base64 thuần).
   - Từ 500 bytes trở lên: `UR:CARDANO-TX-Z/` (Zlib nén Deflate) kết hợp Sequential Animated QR 3.5 - 4.0 FPS.
   - Hỗ trợ kênh sao chép Hex CBOR dự phòng.

5. **Trải Nghiệm Đồng Bộ Hóa Web & Bàn Giả Lập Song Song (Workbench):**
   - Bản phát hành Web PWA cho cả Ví Lạnh (`output/v2.0.1/web/cardano-cold-wallet-web-v2.0.1.zip`) và Ví Nóng (`output/v2.0.1/web/cardano-hot-wallet-web-v2.0.1.zip`).
   - Bàn giả lập `workbench.html` hiển thị 2 khung iframe song song cân đối kèm nút cầu nối 1-chạm.
   - Trình giám sát cụm dịch vụ tự phục hồi `run_cluster.py` và dịch vụ phụ trợ `cardano_auxiliary_service.py` (:5050).

6. **Kiểm Toán An Ninh & Tự Động Hóa 14 Test Suites:**
   - Vượt qua kiểm định bảo mật nghiêm ngặt từ Cloudflare Security Audit, Sentry Code Review, và Backend Security Coder.
   - Kịch bản `test_e2e_verification.ps1` kiểm tra 14 bộ kiểm thử đạt trạng thái **100% PASS**.

---

### 📦 DANH MỤC CÁC TỆP ĐÓNG GÓI TRONG THƯ MỤC /output/v2.0.1/

- **`apk/`**: Các bản cài đặt Native Android APK (`cardano-cold-wallet-v2.0.1.apk`, `cardano-hot-wallet-v2.0.1.apk`).
- **`web/`**: Các gói Zip Web PWA (`cardano-cold-wallet-web-v2.0.1.zip`, `cardano-hot-wallet-web-v2.0.1.zip`).
- **`binaries/`**: Thư viện lõi Rust 64-bit DLL (`rust_cardano_core.dll`) và dịch vụ API phụ trợ (`cardano_auxiliary_service.py`).
- **`tools/`**: Bàn giả lập `workbench.html`, kịch bản khởi chạy `run_workbench.bat` / `.ps1`, trình giám sát `run_cluster.py`, kịch bản thiết lập Kiosk `provision_kiosk.bat` / `.sh`, và bộ test `test_e2e_verification.ps1`.
- **`docs/`**: Tài liệu kỹ thuật hoàn thiện `tech-document-final.md`, cẩm nang Kiosk `AIRGAP_KIOSK_GUIDE.md`, và `README.md`.
- **`cardano-airgap-vault-v2.0.1-enterprise-bundle.zip`**: Gói nén trọn bộ toàn bộ các thành phần trên phục vụ phân phối nhanh.
- **`SHA256SUMS.txt`**: Bảng mã băm xác minh tính toàn vẹn cho toàn bộ các tệp xuất xưởng.

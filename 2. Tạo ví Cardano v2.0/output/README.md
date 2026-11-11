# Bộ Phần Mềm Ví Cardano Air-Gap v2.0.3 (Production Release)

Thư mục này chứa toàn bộ sản phẩm hoàn chỉnh và đóng gói của dự án **Cardano Air-Gap Vault** v2.0.3:
- **Ví Lạnh Android APK v2.0.3** (Hỗ trợ hoàn toàn 32-bit ARMv7 cho Samsung Galaxy J7 Prime và 64-bit ARMv8).
- **Ví Nóng Web Hot Wallet v2.0.3** (Truy cập trực tiếp tại `https://sonvu91.github.io/antigravity-project/` cho iOS Safari & Android Chrome).
- **Bộ công cụ quản lý cài đặt đa năng** (`cai_dat_vi_lanh_j7.bat` / `.ps1` hỗ trợ Cài mới sạch - Reset PIN / Cập nhật an toàn).

---

## 🏛️ Danh Mục Bản Đóng Gói v2.0.3 (`output/`)

```
output/
├── cardano-cold-wallet-v2.0.3.apk               # BẢN CÀI ĐẶT CHÍNH THỨC VÍ LẠNH (~32.2 MB Universal)
│                                                 (Tương thích 100% 32-bit ARMv7 cho J7 Prime & 64-bit)
├── cardano-cold-wallet-v2.0.3-armv7.apk         # Bản rút gọn tối ưu riêng cho ARMv7 32-bit (~10.0 MB)
├── cardano-cold-wallet-v2.0.3-arm64.apk         # Bản rút gọn tối ưu riêng cho ARM64 64-bit (~11.7 MB)
├── cardano-cold-wallet-v2.0.3-universal.apk     # Bản Universal nguyên gốc (~32.2 MB)
│
├── cardano-hot-wallet-v2.0.3.apk                # BẢN CÀI ĐẶT VÍ NÓNG ANDROID (~32.8 MB Universal)
├── cardano-hot-wallet-v2.0.3-armv7.apk          # Ví Nóng rút gọn ARMv7 (~10.6 MB)
├── cardano-hot-wallet-v2.0.3-arm64.apk          # Ví Nóng rút gọn ARM64 (~12.3 MB)
│
├── cardano-hot-wallet-web-v2.0.3.zip            # Gói nén Web Hot Wallet v2.0.3 deploy PWA (~7.8 MB)
├── web_hot_wallet/                              # Thư mục Web Hot Wallet xuất bản GitHub Pages
├── web_cold_wallet/                             # Giả lập Web Cold Wallet
│
├── SHA256SUMS-v2.0.3.txt                        # Bảng mã băm xác minh toàn vẹn tệp v2.0.3
└── v2.0.3/                                      # Thư mục lưu trữ theo phiên bản
```

---

## 📱 Hướng Dẫn Cài Đặt Cho Samsung Galaxy J7 Prime (32-bit ARMv7)

### Phương thức 1: Sử dụng Kịch Bản 1-Click (`cai_dat_vi_lanh_j7.bat` - Khuyên dùng)
1. Cắm cáp USB nối điện thoại **Samsung Galaxy J7 Prime** với máy tính.
2. Bật **Gỡ lỗi USB (USB Debugging)** trên điện thoại:
   - *Cài đặt > Thông tin điện thoại > Thông tin phần mềm > Bấm 7 lần vào "Số hiệu bản tạo".*
   - *Quay lại Cài đặt > Tùy chọn nhà phát triển > Bật "Gỡ lỗi USB".*
   - *Trên màn hình điện thoại, chọn "Luôn cho phép từ máy tính này" và bấm OK.*
3. Nhấp đúp vào tệp `cai_dat_vi_lanh_j7.bat` tại thư mục gốc:
   - **Chọn [1] Cài Mới Sạch Hoàn Toàn (Đặt mã PIN mới):** Kịch bản sẽ tự động xóa sạch dữ liệu ứng dụng cũ (`pm clear`), gỡ bản cũ và cài mới v2.0.3. Khi mở máy lên, thiết bị ở trạng thái mới 100%, yêu cầu bạn thiết lập **Mã PIN mới (6 số)** và tạo/khôi phục ví.
   - **Chọn [2] Cập Nhật An Toàn (Giữ nguyên dữ liệu & mã PIN cũ):** Dành cho các lần nâng cấp sau này, bảo toàn 100% ví và mã PIN cũ.
   - **Chọn [3] Gỡ Bỏ Phần Mềm Cũ:** Xóa sạch ứng dụng khỏi máy.
4. Rút cáp USB để đưa Samsung J7 Prime về chế độ **Cách ly ngoại tuyến hoàn toàn (Air-Gap Sentinel)**.

### Phương thức 2: Cài Đặt Thủ Công Bằng Thẻ Nhớ / USB OTG
1. Sao chép tệp `output/cardano-cold-wallet-v2.0.3.apk` vào thẻ nhớ MicroSD hoặc USB OTG.
2. Cắm vào Samsung J7 Prime.
3. Dùng ứng dụng **File của bạn (My Files)** để mở tệp APK và tiến hành cài đặt.

---

## 🌐 Ví Nóng Chạy Trên Web Cho iOS & Android

Ví Nóng Web Watch-Only được triển khai trực tiếp tại:
👉 **[https://sonvu91.github.io/antigravity-project/](https://sonvu91.github.io/antigravity-project/)**

* **Trên iPhone (iOS Safari):** Mở link bằng trình duyệt Safari. Safari sẽ cấp quyền Camera để quét mã QR từ Ví Lạnh. Bạn có thể chọn *Chia sẻ > Thêm vào Màn hình chính (Add to Home Screen)* để cài đặt thành ứng dụng PWA độc lập.
* **Trên Android (Chrome):** Mở link bằng trình duyệt Chrome. Chrome cấp quyền Camera quét mã QR ngay lập tức và hỗ trợ cài đặt PWA bằng một chạm.
* **Giao tiếp hoàn toàn ngoại tuyến qua Quang học (QR Code):** Ví Nóng chỉ lưu khóa công khai (xPub) để theo dõi số dư và tạo giao dịch chưa ký. Mọi thao tác ký được thực hiện trên Ví Lạnh Samsung J7 Prime ngoại tuyến.

# Bộ Phần Mềm Ví Cardano Air-Gap v2.0.18 (Production Release)

Thư mục này chứa toàn bộ sản phẩm hoàn chỉnh và đóng gói của dự án **Cardano Air-Gap Vault** v2.0.18:
- **Ví Lạnh Android APK v2.0.18** (Hỗ trợ ký tự động UTXO đa nhánh `0/x` và `1/x`, chốt chặn an ninh Fail-Closed, tối ưu 32-bit ARMv7 cho Samsung Galaxy J7 Prime và 64-bit ARMv8).
- **Ví Nóng Android APK v2.0.18** (Bản cài đặt trực tiếp trên Android 32-bit & 64-bit, tự động truyền metadata nguồn UTXO).
- **Ví Nóng Web Hot Wallet v2.0.18** (Truy cập trực tiếp tại `https://sonvu91.github.io/antigravity-project/` cho iOS Safari & Android Chrome).
- **Bộ công cụ quản lý cài đặt đa năng** (`cai_dat_vi_lanh_j7.bat` / `.ps1` hỗ trợ Cài mới sạch - Reset PIN / Cập nhật an toàn).

---

## 🏛️ Danh Mục Bản Đóng Gói v2.0.18 (`output/`)

```
output/
├── cardano-cold-wallet-v2.0.18.apk               # BẢN CÀI ĐẶT CHÍNH THỨC VÍ LẠNH (~24.8 MB Universal)
│                                                  (Tương thích 100% 32-bit ARMv7 cho J7 Prime & 64-bit)
├── cardano-cold-wallet-v2.0.18-armv7.apk         # Bản rút gọn tối ưu riêng cho ARMv7 32-bit (~8.7 MB)
├── cardano-cold-wallet-v2.0.18-arm64.apk         # Bản rút gọn tối ưu riêng cho ARM64 64-bit (~9.2 MB)
├── cardano-cold-wallet-v2.0.18-universal.apk     # Bản Universal nguyên gốc (~24.8 MB)
│
├── cardano-hot-wallet-v2.0.18.apk                # BẢN CÀI ĐẶT VÍ NÓNG ANDROID (~22.3 MB Universal)
├── cardano-hot-wallet-v2.0.18-armv7.apk          # Ví Nóng rút gọn ARMv7 (~8.0 MB)
├── cardano-hot-wallet-v2.0.18-arm64.apk          # Ví Nóng rút gọn ARM64 (~8.5 MB)
│
├── cardano-hot-wallet-web-v2.0.18.zip            # Gói nén Web Hot Wallet v2.0.18 deploy PWA
├── web_hot_wallet/                               # Thư mục Web Hot Wallet xuất bản GitHub Pages
│
├── SHA256SUMS-v2.0.18.txt                        # Bảng mã băm xác minh toàn vẹn tệp v2.0.18
└── v2.0.18/                                      # Thư mục lưu trữ theo phiên bản
```

---

## 🛡️ Bảng Mã Băm Toàn Vẹn Chính Thức (SHA-256 Checksums)

```
d8be41b5c50145f99170cee07d17c442d50dc1b59b532361a4f0731ec786b4d5  cardano-cold-wallet-v2.0.18-arm64.apk
d5a180f00c871fa992221fd1d65b38854882c620b52e3160882753864de10d09  cardano-cold-wallet-v2.0.18-armv7.apk
0ae578332d325bf500206074784499b5b1fdec1e6861a319da9bb11b794c57e3  cardano-cold-wallet-v2.0.18-universal.apk
0ae578332d325bf500206074784499b5b1fdec1e6861a319da9bb11b794c57e3  cardano-cold-wallet-v2.0.18.apk
37093900ebc8ea9e5660f8500e9bf7d98b6874301238ec0a12fe6fe5215f7ab6  cardano-hot-wallet-v2.0.18-arm64.apk
4125368a80c8b14904261a5506d68176aebe22198f07164069a30f1ffc28da49  cardano-hot-wallet-v2.0.18-armv7.apk
535e47f04abcfc959f81f12eb5648544523ba91144b9deb6ae3e0a6140795ff3  cardano-hot-wallet-v2.0.18-universal.apk
535e47f04abcfc959f81f12eb5648544523ba91144b9deb6ae3e0a6140795ff3  cardano-hot-wallet-v2.0.18.apk
bc6ec44f4c464a86b0a28d3e718ee307dcc83907e7cedb924a636bc01b52c440  cardano-hot-wallet-web-v2.0.18.zip
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
   - **Chọn [1] Cài Mới Sạch Hoàn Toàn (Đặt mã PIN mới):** Kịch bản sẽ tự động xóa sạch dữ liệu ứng dụng cũ (`pm clear`), gỡ bản cũ và cài mới v2.0.18. Khi mở máy lên, thiết bị ở trạng thái mới 100%, yêu cầu bạn thiết lập **Mã PIN mới (6 số)** và tạo/khôi phục ví.
   - **Chọn [2] Cập Nhật An Toàn (Giữ nguyên dữ liệu & mã PIN cũ):** Dành cho các lần nâng cấp sau này, bảo toàn 100% ví và mã PIN cũ.
   - **Chọn [3] Gỡ Bỏ Phần Mềm Cũ:** Xóa sạch ứng dụng khỏi máy.
4. Rút cáp USB để đưa Samsung J7 Prime về chế độ **Cách ly ngoại tuyến hoàn toàn (Air-Gap Sentinel)**.

### Phương thức 2: Cài Đặt Thủ Công Bằng Thẻ Nhớ / USB OTG
1. Sao chép tệp `output/cardano-cold-wallet-v2.0.18.apk` hoặc `cardano-cold-wallet-v2.0.18-armv7.apk` vào thẻ nhớ MicroSD hoặc USB OTG.
2. Cắm vào Samsung J7 Prime và tiến hành cài đặt.

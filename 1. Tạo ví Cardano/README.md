# CARDANO HOT WALLET & WATCH-ONLY HUB v2.0
## (Cardano Multi-Platform Web PWA & Android Application)

Dự án cung cấp giải pháp **Ví Nóng Cardano Đa Nền Tảng (Hot Wallet & Watch-Only Hub)** cho mạng lưới blockchain **Cardano** (hỗ trợ kỷ nguyên Conway CIP-1694), hoạt động trực tiếp trên trình duyệt Web (PWA) và ứng dụng di động Android (32-bit & 64-bit).

🌐 **Trải nghiệm trực tiếp trên Web:** [https://sonvu91.github.io/antigravity-project/](https://sonvu91.github.io/antigravity-project/)

---

## 1. Tính Năng Nổi Bật

- **Web PWA trên GitHub Pages:** Chạy mượt mà trên mọi thiết bị và hệ điều hành (iOS Safari, Android Chrome, Windows, macOS, Linux) mà không cần cài đặt.
- **Quản lý Đa Tài Khoản Ví (Watch-Only):**
  - Thêm, theo dõi và quản lý nhiều địa chỉ ví Cardano (`addr1...`, `addr_test1...`).
  - Phân loại tài khoản theo tên gợi nhớ, gắn nhãn tài sản.
  - Tự động truy vấn số dư ADA thực tế, danh mục Native Tokens / NFTs, và phần thưởng Staking.
- **Tích hợp Blockfrost API độc lập theo mạng:**
  - Hỗ trợ lưu trữ API Key Blockfrost riêng biệt cho từng mạng: **Mainnet**, **Preprod**, và **Preview**.
  - Tự động cách ly môi trường dữ liệu và xác thực mạng an toàn.
- **Hỗ trợ Kỷ nguyên Conway (CIP-1694):**
  - Xây dựng giao dịch Cardano chuẩn xác theo định dạng CBOR hiện đại.
  - Tự động gom UTxO, tính toán phí mạng (network fee) và địa chỉ nhận tiền thừa (change address).
  - Xuất giao dịch thô (`txRaw`) dưới dạng mã QR động nén Zlib hoặc văn bản để dễ dàng phối hợp ký ngoại tuyến.
- **Camera QR Scanner & Tiện ích Clipboard:**
  - Tích hợp máy quét Camera trực tiếp trên Web (HTML5 QRCode) và Mobile để quét địa chỉ ví, mã giao dịch nhanh chóng.
  - Nút dán (Paste) và xóa (Clear) một chạm tiện lợi trên giao diện di động.
- **Hỗ trợ Đầy Đủ Android 32-bit & 64-bit:**
  - Đóng gói file APK tách biệt tối ưu cho chip 32-bit ARMv7 (như Samsung Galaxy J7 Prime) và chip 64-bit ARM64 hiện đại.

---

## 2. Cấu Trúc Thư Mục Dự Án

```text
2. Tạo ví Cardano v2.0/
├── mobile_online/             # Ứng dụng Ví Nóng Flutter (Web PWA & Android APK)
│   ├── lib/
│   │   ├── core/              # Quản lý mạng Blockfrost, UTxO builder, clipboard
│   │   ├── presentation/      # Màn hình Dashboard, tạo giao dịch, cài đặt
│   │   └── main.dart          # Khởi chạy ứng dụng
│   └── web/                   # Tài nguyên Web PWA (manifest, icons, canvaskit)
├── cardano_airgap_bridge/     # Thư viện lõi Dart (Bech32, BIP-39, QR multipart)
├── rust_cardano_core/         # Lõi Rust mật mã phục vụ build APK native Android
├── scripts/                   # Kịch bản tiện ích & tải APK tự động từ GitHub Release
│   └── download_release_apk.ps1 # Tải file APK Ví Nóng từ GitHub Release
├── serve_hot_wallet.bat       # Kịch bản 1-click khởi chạy Web Hot Wallet trên máy cục bộ
├── output/                    # Các bản đóng gói phát hành
│   ├── web_hot_wallet/        # Thư mục xuất bản GitHub Pages
│   └── *.apk                  # Các file cài đặt APK cho Android
├── .env.example               # Mẫu cấu hình Blockfrost API Key
└── README.md                  # Tài liệu hướng dẫn này
```

---

## 3. Hướng Dẫn Cài Đặt & Sử Dụng

### A. Sử dụng trực tiếp trên Web (Khuyến nghị)
Truy cập liên kết [https://sonvu91.github.io/antigravity-project/](https://sonvu91.github.io/antigravity-project/) bằng bất kỳ trình duyệt nào.
* Trên iPhone / iPad (Safari): Bấm nút **Chia sẻ (Share)** -> Chọn **"Thêm vào Màn hình chính" (Add to Home Screen)** để dùng như một ứng dụng độc lập.
* Trên Android (Chrome): Bấm menu 3 chấm -> Chọn **"Cài đặt ứng dụng" (Install App)**.

### B. Chạy cục bộ trên máy tính (Local Development)
1. **Khởi chạy Web Server cục bộ:**
   ```cmd
   serve_hot_wallet.bat
   ```
   Trình duyệt sẽ tự động mở trang Ví Nóng tại địa chỉ `http://127.0.0.1:8080`.

2. **Chạy bằng Flutter SDK:**
   ```bash
   cd mobile_online
   flutter pub get
   flutter run -d chrome
   ```

### C. Cài đặt file APK lên điện thoại Android
Tải trực tiếp các bản APK chính thức từ mục [GitHub Releases](https://github.com/SonVu91/antigravity-project/releases):
* `cardano-hot-wallet-v2.0.5-universal.apk`: Tương thích mọi điện thoại Android.
* `cardano-hot-wallet-v2.0.5-armv7.apk`: Tối ưu dung lượng cho điện thoại 32-bit (Galaxy J7 Prime...).
* `cardano-hot-wallet-v2.0.5-arm64.apk`: Tối ưu hiệu năng cho điện thoại 64-bit đời mới.

---

## 4. Quy Trình Tự Động Hóa CI/CD (GitHub Actions)

* **`.github/workflows/deploy-pages.yml`**: Tự động build bản phát hành Web và triển khai lên nhánh `gh-pages` mỗi khi có commit mới trên nhánh `main`.
* **`.github/workflows/build-apk.yml`**: Tự động biên dịch mã nguồn lõi Rust, chạy toàn bộ kiểm thử đơn vị, đóng gói các bản APK Android (ARM64, ARMv7, Universal) và xuất bản lên GitHub Releases.

---

## 5. Tiêu Chuẩn Bảo Mật
* Không lưu giữ khóa riêng tư (Private Key) trên thiết bị trực tuyến — an toàn tuyệt đối trước nguy cơ bị đánh cắp tài sản từ xa.
* Mã hóa lưu trữ thông tin cấu hình cục bộ bằng cơ chế mã hóa tiêu chuẩn trên trình duyệt và thiết bị di động.

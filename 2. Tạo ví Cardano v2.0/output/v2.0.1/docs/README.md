# HỆ THỐNG VÍ KÉP CARDANO AIR-GAPPED ĐA NỀN TẢNG v2.0.1
## (Cardano Air-Gap Vault - Enterprise Edition)

Dự án cung cấp giải pháp két sắt số lạnh ngoại tuyến hoàn toàn (*100% Air-Gapped Cold Wallet*) kết hợp trạm quan sát và phát sóng trực tuyến (*Watch-Only Hot Wallet*) cho mạng lưới blockchain **Cardano** (kỷ nguyên Conway CIP-1694).
Phiên bản v2.0.1 nâng cấp tính năng tiếp nhận giao dịch Đa phương thức (Quét Live Camera QR & Dán CBOR Hex 1-chạm) cùng bộ bảo vệ Change Guard đối chiếu đa ví tự động.

---

## 1. Cấu Trúc Kho Mã Nguồn

```text
2. Tạo ví Cardano v2.0/
├── docs/                      # Tài liệu đặc tả kỹ thuật toàn diện (tech-documentv2.md)
├── rust_cardano_core/         # Lõi mật mã Rust CML 6.2.0 FFI, FIPS 140-3 & Strict Change Guard
├── cardano_airgap_bridge/     # Thư viện Dart FFI & Adaptive Multipart Animated QR
├── mobile_cold/               # Ứng dụng Ví Lạnh Flutter (Offline Kiosk / Zero Internet)
├── mobile_online/             # Ứng dụng Ví Nóng Flutter (Online Watch-Only / Web PWA)
├── scripts/                   # Kịch bản tự động hóa Kiosk ADB & Tiện ích
├── serve_wallets.py           # Máy chủ phục vụ Simulator Workbench (:8080)
├── cardano_auxiliary_service.py # Dịch vụ C-FFI Web Bridge (:5050)
├── workbench.html             # Bàn giả lập 2 thiết bị song song
├── test_e2e_verification.ps1  # Bộ kiểm thử E2E tự động hóa 14 Test Suites
└── output/                    # Các bản đóng gói phát hành (APK, Web PWA, SHA256SUMS)
```

---

## 2. Tiêu Chuẩn Bảo Mật Cốt Lõi
- **Zero Internet Cold Wallet:** Ví Lạnh không cấp quyền Internet, cưỡng chế Android Device Owner (Release mode).
- **Anti-Blind Signing & Strict Change Guard:** Bóc tách Conway CBOR và quét 51 chỉ số Role 0 & 1 chống đánh tráo tiền thừa.
- **FIPS 140-3 Cryptographic Self-Verification:** Tự xác minh toán học chữ ký Ed25519 trước khi xuất mã.
- **Deep Memory Zeroization:** Tẩy sạch RAM C-Heap và Rust bộ nhớ về `0x00`.
- **Adaptive Multipart QR:** Tự động nén Zlib `UR:CARDANO-TX-Z` khi CBOR $\ge 500$ bytes.
- **Ví Ẩn BIP-39 Passphrase:** Phiên làm việc RAM-only, tone tím Amethyst `#7E22CE`, không lưu vết trên đĩa.

---

## 3. Khởi Chạy Nhanh
- **Kiểm thử E2E Toàn hệ thống:**
  ```powershell
  .\test_e2e_verification.ps1
  ```
- **Chạy Bàn Giả Lập Workbench (:8080):**
  ```powershell
  python serve_wallets.py
  ```

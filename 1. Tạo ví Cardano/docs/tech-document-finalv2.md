# TÀI LIỆU ĐẶC TẢ KỸ THUẬT HOÀN CHỈNH & TOÀN DIỆN (MASTER TECHNICAL SPECIFICATION)
## HỆ THỐNG VÍ KÉP CARDANO AIR-GAPPED ĐA NỀN TẢNG (FLUTTER + RUST CML FFI + PURE-DART)
### PHIÊN BẢN HỢP NHẤT TOÀN DIỆN & KIỂM TOÁN HOÀN HẢO (ENTERPRISE GOLD MASTER RELEASE v2.0.3)

---

### THÔNG TIN TÀI LIỆU & QUẢN TRỊ DỰ ÁN
- **Tên dự án:** Cardano Air-Gapped Multi-Platform Dual-Wallet System
- **Mã định danh hệ thống:** `cardano-airgap-vault`
- **Phiên bản hệ thống:** `v2.0.3 (Enterprise Gold Master Release - Multi-Network & Production Ready)`
- **Ngày phê duyệt & Đóng băng tài liệu:** 10/11/2026
- **Kho lưu trữ chính thức (Monorepo):** `https://github.com/SonVu91/antigravity-project.git`
- **Địa chỉ xuất bản Ví Nóng Web (GitHub Pages):** [https://sonvu91.github.io/antigravity-project/](https://sonvu91.github.io/antigravity-project/)
- **Chuẩn Cardano Protocol:** Conway Era (CIP-1694, CIP-1852, CIP-0005, CIP-0019, CIP-0003, CIP-0008, CIP-0025, CIP-0068)
- **Kiến trúc Mật mã Kép (Dual-Engine Cryptography):**
  1. *Native Engine (64-bit & Desktop):* Rust C-FFI (`cardano-multiplatform-lib` v6.2.0, `bip39`, `ed25519-bip32`, `zeroize`)
  2. *Pure-Dart Engine (32-bit ARMv7 & Web PWA):* `CardanoPure` + `Bip39Pure` (Zero external dynamic library dependency)
- **Thiết bị Mục tiêu Cốt lõi:** Tối ưu hóa 100% cho điện thoại **Samsung Galaxy J7 Prime** (32-bit ARMv7 `armeabi-v7a`, Chipset Samsung Exynos 7870 Octa-core, Android 6.0.1 - 8.1.0) và tương thích hoàn toàn các thiết bị Android 64-bit (`arm64-v8a`), máy tính Windows/macOS/Linux và trình duyệt Web.
- **Khung ứng dụng di động & Web:** Flutter 3.x / Dart 3.x
- **Giao thức Air-Gap:** Kênh quang học 2 chiều Adaptive Multipart Animated QR (`UR:CARDANO-TX` / `UR:CARDANO-TX-Z`) & Kênh Hex CBOR dự phòng
- **Môi trường Mạng hỗ trợ (3 trong 1):** Cardano Mainnet (Network ID = 1), Preprod Testnet (Network ID = 0, Magic = 1), Preview Testnet (Network ID = 0, Magic = 2)
- **Trạng thái Kiểm định An ninh:** Đã vượt qua kiểm định chuyên sâu theo tiêu chuẩn Sentry Code Review, Backend Security Coder, FIPS 140-3 Cryptographic Self-Verification và Cloudflare Zero-Trust Security Audit.

---

## MỤC LỤC TỔNG THỂ

1. [PHẦN 1: TỔNG QUAN DỰ ÁN, TRIẾT LÝ BẢO MẬT & KIẾN TRÚC HỆ THỐNG AIR-GAPPED MONOREPO](#phần-1-tổng-quan-dự-án-triết-lý-bảo-mật--kiến-trúc-hệ-thống-air-gapped-monorepo)
   - 1.1. Bối cảnh Kỹ thuật & 3 Trụ Cột An Ninh Bất Biến
   - 1.2. Mô hình Cô lập Ngoại tuyến Hoàn toàn (Air-Gapped Isolation Model)
   - 1.3. Cấu trúc Kho Mã nguồn Monorepo Hợp nhất
   - 1.4. Lộ trình Tiến hóa Hệ thống từ v2.0.0 đến v2.0.3
   - 1.5. Sơ đồ Luồng Luân chuyển Dữ liệu Kép 3 Bước (3-Step Optical Pipeline)

2. [PHẦN 2: ĐẶC TẢ LÕI MẬT MÃ DÙNG CHUNG VÀ KIẾN TRÚC ĐỘNG CƠ KÉP (DUAL-ENGINE CRYPTOGRAPHY)](#phần-2-đặc-tả-lõi-mật-mã-dùng-chung-và-kiến-trúc-động-cơ-kép-dual-engine-cryptography)
   - 2.1. Động cơ Mật mã Kép: Rust CML FFI & Pure-Dart Engine
   - 2.2. Chuẩn Sinh Mnemonic BIP-39 & Entropy An Toàn CSPRNG
   - 2.3. Phái sinh Khóa Phân cấp CIP-1852 (Shelley/Conway Era HD Wallet)
   - 2.4. Cơ chế Phái sinh Kép: BIP-39 Seed Mặc định & CIP-0003 Icarus
   - 2.5. Cấu trúc Địa chỉ Cơ sở (Shelley Base Address - CIP-0019) & Phân định Mạng
   - 2.6. Xuất Khóa Công khai Mở rộng Tài khoản (Account XPUB) cho Watch-Only
   - 2.7. Cơ chế Xóa Sạch Bộ Nhớ Sâu (Deep Memory Zeroization) & Khử Dữ liệu Nhạy cảm

3. [PHẦN 3: BỘ PHÂN TÍCH GIAO DỊCH CONWAY CBOR & CHỐNG KÝ MÙ (ANTI-BLIND SIGNING)](#phần-3-bộ-phân-tích-giao-dịch-conway-cbor--chống-ký-mù-anti-blind-signing)
   - 3.1. Giải mã Cấu trúc Nhị phân CBOR Giao dịch Kỷ nguyên Conway (CIP-1694)
   - 3.2. Bóc tách Toàn diện: Inputs, Outputs, Phí Mạng (Fee), TTL, Minting & Multi-Asset
   - 3.3. Bóc tách Chứng chỉ Quản trị Conway (DRep Delegation) & Ủy thác Stake Pool
   - 3.4. Bóc tách Rút thưởng Cổ phần (Withdrawals) & Điều kiện Ký Kép (Dual-Witness)
   - 3.5. Hệ thống Cảnh báo Trực quan & Các Chốt chặn Phòng vệ Ký Mù

4. [PHẦN 4: CƠ CHẾ CHỐNG ĐÁNH TRÁO TIỀN THỪA NGHIÊM NGẶT (STRICT CHANGE GUARD)](#phần-4-cơ-chế-chống-đánh-tráo-tiền-thừa-nghiêm-ngặt-strict-change-guard)
   - 4.1. Mối Đe Dọa Đánh Tráo Tiền Thừa (UTxO Change Hijacking Attack)
   - 4.2. Thuật toán Đối soát Khóa Cổ phần (Stake Credential Matching)
   - 4.3. Quét Đa Điểm Không Gian Địa chỉ Nội bộ (`role = 1`, 51 chỉ số)
   - 4.4. Bảo vệ Giao dịch 1-Output & Cảnh Báo Rút Cạn Ví (Full Drain Attack)
   - 4.5. Cơ chế Khóa Chết Ký Duyệt Fail-Closed khi Phát hiện Sai lệch

5. [PHẦN 5: BỘ CHUYỂN ĐỔI ĐA MÔI TRƯỜNG MẠNG & CHỐT CHẶN STRICT NETWORK GUARD v2.0.3](#phần-5-bộ-chuyển-đổi-đa-môi-trường-mạng--chốt-chặn-strict-network-guard-v203)
   - 5.1. Kiến trúc Đa Mạng: Mainnet, Preprod Testnet & Preview Testnet
   - 5.2. Động cơ Tự động Tái Dẫn xuất Địa chỉ Động (Dynamic Derivation Engine)
   - 5.3. Chốt chặn An toàn Lệch mạng Nghiêm ngặt (Strict Network Guard)
   - 5.4. Giao diện Chuyển đổi Mạng Trực quan & Network Badges
   - 5.5. Lưu trữ Bền vững Môi trường Mạng & Đồng bộ 1:1

6. [PHẦN 6: ĐẶC TẢ CHI TIẾT ỨNG DỤNG VÍ LẠNH NGOẠI TUYẾN (`mobile_cold`)](#phần-6-đặc-tả-chi-tiết-ứng-dụng-ví-lạnh-ngoại-tuyến-mobile_cold)
   - 6.1. Triết lý Thiết kế Zero Internet & Loại bỏ Hoàn toàn Quyền Truy cập Mạng
   - 6.2. Hệ thống Kiosk Sentinel v2 & Cưỡng chế Phần cứng Device Owner
   - 6.3. Giám sát Kết nối Liên tục & Màn hình Đỏ Phong tỏa Khẩn cấp (Lockdown Screen)
   - 6.4. Cơ chế Quản trị Mã PIN 6 Chữ số, Khóa Tạm thời & Xóa Dữ liệu Tự động
   - 6.5. Tính năng Ví Ẩn BIP-39 Passphrase Chạy Hoàn Toàn Trên RAM
   - 6.6. Bảng Điều khiển Kiểm toán Air-Gap (Air-Gap Audit Dashboard)
   - 6.7. Ký Giao dịch Ngoại tuyến & Tự Xác minh Chữ ký FIPS 140-3

7. [PHẦN 7: ĐẶC TẢ CHI TIẾT ỨNG DỤNG VÍ NÓNG TRỰC TUYẾN & WEB PWA (`mobile_online`)](#phần-7-đặc-tả-chi-tiết-ứng-dụng-ví-nóng-trực-tuyến--web-pwa-mobile_online)
   - 7.1. Kiến trúc Ví Quan sát Không Khóa Riêng (Watch-Only Vault)
   - 7.2. Xuất bản Ứng dụng Web PWA trên GitHub Pages cho iOS & Android
   - 7.3. Bộ Tích hợp Blockfrost API & Bộ đệm UTxO Thông minh
   - 7.4. Động cơ Lập Giao dịch Ngoại tuyến: Chuyển ADA, Token, Quản trị Conway & Staking
   - 7.5. Camera QR Scanner Tương thích Đa nền tảng (Web HTML5 Video & Mobile Camera)
   - 7.6. Động cơ Phát sóng Giao dịch (Transaction Broadcasting) & Xử lý Mã Lỗi Node

8. [PHẦN 8: GIAO THỨC TRUYỀN TIN QUANG HỌC AIR-GAP THÍCH ỨNG (ADAPTIVE QR PROTOCOL)](#phần-8-giao-thức-truyền-tin-quang-học-air-gap-thích-ứng-adaptive-qr-protocol)
   - 8.1. Mô hình Kênh Truyền Quang học 2 Chiều Không Dây Dẫn
   - 8.2. Tiêu chuẩn Mã hóa Single QR & Nén Zlib UR Multipart QR
   - 8.3. Thuật toán Phân mảnh Dữ liệu & Tần số Quét Hoàn hảo (Carousel Display)
   - 8.4. Kênh Hex CBOR Dự phòng & Kiểm tra Tính Toàn vẹn Checksum

9. [PHẦN 9: HỆ THỐNG THIẾT KẾ UI/UX PRO MAX, TRỰC QUAN HÓA & TRẢI NGHIỆM NGƯỜI DÙNG](#phần-9-hệ-thống-thiết-kế-uiux-pro-max-trực-quan-hóa--trải-nghiệm-người-dùng)
   - 9.1. Bộ Nhận diện Thị giác Cyberpunk Dark & Hệ Màu An Ninh Obsidian
   - 9.2. Phối màu Trực quan Phân định Môi trường Mạng & Trạng thái Ví
   - 9.3. Giao diện Ví Ẩn Tím Thạch Anh Amethyst (#7E22CE)
   - 9.4. Thiết kế Thẻ Giao dịch Phân cấp (Transaction Verification Card Hierarchy)
   - 9.5. Tối ưu hóa Màn hình Cho Thiết bị 32-bit Kích thước 5.5 Inch (Galaxy J7 Prime)

10. [PHẦN 10: HỆ THỐNG KỊCH BẢN TỰ ĐỘNG HÓA ADB, PROVISIONING VÀ QUẢN TRỊ J7 PRIME](#phần-10-hệ-thống-kịch-bản-tự-động-hóa-adb-provisioning-và-quản-trị-j7-prime)
    - 10.1. Bộ Kịch bản Quản lý Cài đặt Đa Năng: `cai_dat_vi_lanh_j7.bat` / `.ps1`
    - 10.2. Chế độ 1: Cài Mới Sạch Sẽ (Clean Installation & New PIN Flow)
    - 10.3. Chế độ 2: Cập Nhật An Toàn (Reinstall Keep Data Mode `-r`)
    - 10.4. Tự động Nhận diện Thiết bị ADB Portable & Cấp Quyền Runtime
    - 10.5. Kịch bản Kiosk Provisioning & Thiết lập Chính sách Device Owner Doanh nghiệp

11. [PHẦN 11: MA TRẬN ĐE DỌA AN NINH, PHÂN TÍCH LỖ HỔNG & GIẢI PHÁP PHÒNG VỆ](#phần-11-ma-trận-đe-dọa-an-ninh-phân-tích-lỗ-hổng--giải-pháp-phòng-vệ)
    - 11.1. Ma trận Phân tích Đe dọa Mô hình STRIDE
    - 11.2. Phòng vệ Tấn công Tiêm Lỗi Phần cứng (Fault Injection Attack)
    - 11.3. Phòng vệ Tấn công Side-Channel & Trích xuất Bộ nhớ RAM
    - 11.4. Phòng vệ Tấn công Man-in-the-Middle (MitM) & Giả mạo Mã QR
    - 11.5. Cơ chế Tự Hủy Dữ liệu Khẩn cấp (Emergency Wipe Out)

12. [PHẦN 12: TIÊU CHUẨN NGHIỆM THU, BỘ KIỂM THỬ E2E 18 KỊCH BẢN & DANH MỤC ĐÓNG GÓI v2.0.3](#phần-12-tiêu-chuẩn-nghiệm-thu-bộ-kiểm-thử-e2e-18-kịch-bản--danh-mục-đóng-gói-v203)
    - 12.1. Bộ Kiểm thử Đầu-Cuối Tự Động Hóa 18 Kịch bản (`test_e2e_verification.ps1`)
    - 12.2. Kiểm thử Tương thích Đa Mạng & Chuyển đổi Mạng Nóng/Lạnh
    - 12.3. Quy trình CI/CD Build Tự động trên GitHub Actions
    - 12.4. Danh mục Đóng gói Phát hành Thư mục `/output/v2.0.3/`
    - 12.5. Bảng Mã Băm SHA-256 Checksums Xác minh Tính Toàn vẹn
    - 12.6. Quy trình Vận hành Tiêu chuẩn Hằng ngày (Standard Operating Procedure - SOP)

---

## PHẦN 1: TỔNG QUAN DỰ ÁN, TRIẾT LÝ BẢO MẬT & KIẾN TRÚC HỆ THỐNG AIR-GAPPED MONOREPO

```mermaid
flowchart TD
    subgraph Online_Zone["VÙNG TRỰC TUYẾN (ONLINE ZONE)"]
        UserHot["Người Dùng Trực Tuyến"] --> HotWeb["Ví Nóng Web GitHub Pages<br/>(Safari iOS / Chrome Android)"]
        UserHot --> HotApp["Ví Nóng Android APK<br/>(mobile_online)"]
        HotWeb & HotApp <--> Blockfrost["Blockfrost API Gateway<br/>(Cardano Cardano Node)"]
        Blockfrost <--> CardanoNet["Cardano Blockchain<br/>(Mainnet / Preprod / Preview)"]
    end

    subgraph Optical_AirGap["KÊNH QUANG HỌC AIR-GAP 2 CHIỀU (KHÔNG DÂY CẮP / KHÔNG SÓNG)"]
        HotApp -- "1. Mã QR Unsigned Tx<br/>(UR:CARDANO-TX-Z / Hex)" --> CamCold["Camera Quét Ví Lạnh"]
        ColdApp -- "3. Mã QR Signed Witness<br/>(UR:CARDANO-TX / Hex)" --> CamHot["Camera Quét Ví Nóng"]
    end

    subgraph Cold_Zone["VÙNG KÉT SẮT LẠNH CÔ LẬP 100% (COLD ZONE)"]
        CamCold --> ColdApp["Ví Lạnh Android Kiosk<br/>(Samsung Galaxy J7 Prime / Android 64-bit)"]
        subgraph Engine["Dual-Engine Cryptography"]
            ColdApp --> PureDart["Pure-Dart Engine<br/>(CardanoPure / 32-bit ARMv7)"]
            ColdApp --> RustCore["Rust Core CML FFI<br/>(librust_cardano_core.so / 64-bit)"]
        end
        ColdApp --> ChangeGuard["Strict Change Guard<br/>(Quét 51 chỉ số Stake Credential)"]
        ColdApp --> NetGuard["Strict Network Guard<br/>(Chặn đứng lệch mạng Mainnet/Testnet)"]
        ColdApp --> AntiBlind["Anti-Blind Signing<br/>(Bóc tách Conway CBOR toàn diện)"]
    end
```

### 1.1. Bối cảnh Kỹ thuật & 3 Trụ Cột An Ninh Bất Biến
Trong kỷ nguyên blockchain Cardano Conway (CIP-1694) với các cơ chế quản trị phi tập trung phức tạp, các mối đe dọa bảo mật đối với người nắm giữ tài sản số ngày càng tinh vi:
- **Tấn công Ký Mù (Blind Signing):** Người dùng bị dẫn dụ ký các chuỗi hex nhị phân khó đọc mà không nắm được chính xác số tiền bị trừ, tài sản token bị chuyển đi, hay các chứng chỉ quản trị DRep bị đánh tráo.
- **Tấn công Đánh tráo Tiền thừa (UTxO Change Hijacking):** Mã độc trên ví nóng hoặc thiết bị kết nối internet sửa đổi địa chỉ trả tiền thừa (Change Output) sang địa chỉ của kẻ tấn công, khiến người dùng mất toàn bộ số dư còn lại của UTxO.
- **Tấn công Lệch Mạng (Cross-Network Confusion):** Kẻ tấn công dẫn dụ người dùng ký giao dịch trên môi trường Mainnet bằng việc hiển thị số liệu từ Testnet hoặc ngược lại.

Hệ thống Ví Kép Cardano Air-Gapped được xây dựng dựa trên **3 Trụ Cột An Ninh Bất Biến**:
1. **Cô Lập Ngoại Tuyến Tuyệt Đối (100% Air-Gapped Zero Internet):** Ví Lạnh hoạt động trên thiết bị di động chuyên dụng bị ngắt hoàn toàn mọi kết nối vô tuyến (WiFi, Bluetooth, 3G/4G/5G, NFC, GPS) và bị chặn truyền tệp qua cổng USB ở cấp độ phần cứng hệ điều hành.
2. **Ký Trực Quan Minh Bạch Chống Ký Mù (Anti-Blind Signing & Conway CBOR Decoding):** Mọi trường dữ liệu nhị phân trong giao dịch Cardano đều được bóc tách và giải trình minh bạch trên màn hình Ví Lạnh trước khi người dùng xác nhận.
3. **Phòng Vệ Đánh Tráo Tiền Thừa Tuyệt Đối (Strict Change Guard):** Hệ thống tự động truy xuất và đối soát toán học mã băm chứng chỉ cổ phần (Stake Credential Hash) của địa chỉ tiền thừa với toàn bộ không gian khóa nội bộ của ví.

### 1.2. Mô hình Cô lập Ngoại tuyến Hoàn toàn (Air-Gapped Isolation Model)
Khái niệm **Air-Gap** trong hệ thống được định nghĩa chặt chẽ theo tiêu chuẩn quốc phòng và an ninh mật mã:
- **Tách biệt Vật lý (Physical Isolation):** Thiết bị chạy Ví Lạnh (`mobile_cold`) không chia sẻ bất kỳ kênh kết nối vô tuyến hoặc hữu tuyến nào với thiết bị Ví Nóng (`mobile_online`) hay thế giới bên ngoài.
- **Kênh Truyền Tin Duy Nhất Bằng Quang Học (Optical-Only Data Plane):** Toàn bộ dữ liệu trao đổi giữa Ví Nóng và Ví Lạnh được thực hiện thông qua việc quét mã QR hai chiều trên màn hình. Kênh quang học chỉ mang thông tin nhị phân giao dịch dạng tĩnh (Read-Only Scan), không cho phép thực thi mã lệnh hay tương tác hai chiều cấp socket.
- **Chính sách Quyền Cưỡng Chế Doanh Nghiệp (Enterprise Device Owner Policy):** Ứng dụng Ví Lạnh nắm quyền quản trị tối cao của Android thông qua `DevicePolicyManager`, tự động khóa cứng Airplane Mode và vô hiệu hóa mọi giao diện mạng của phần cứng.

### 1.3. Cấu trúc Kho Mã nguồn Monorepo Hợp nhất
Dự án được cấu trúc theo mô hình Monorepo tối ưu hóa tính độc lập module nhưng dùng chung thư viện cầu nối mật mã:

```text
2. Tạo ví Cardano v2.0/
├── AGENTS.md                         # Quy tắc cộng tác AI & Giao thức đồng bộ đa máy
├── README.md                         # Sổ tay tổng quan dự án & Hướng dẫn bắt đầu nhanh
├── cai_dat_vi_lanh_j7.bat            # Kịch bản 1-click Cài đặt / Cập nhật Ví Lạnh J7 Prime
├── cai_dat_vi_lanh_j7.ps1            # Kịch bản PowerShell quản trị Ví Lạnh J7 Prime
├── run_tests.ps1                     # Bộ khởi chạy kiểm thử toàn hệ thống
├── test_e2e_verification.ps1         # Bộ kiểm thử E2E tự động hóa 18 bài kiểm tra
├── serve_wallets.py                  # Máy chủ giả lập Simulator Workbench (:8080)
├── cardano_auxiliary_service.py      # Dịch vụ phụ trợ C-FFI Web Bridge (:5050)
├── workbench.html                    # Môi trường giả lập 2 thiết bị song song
│
├── rust_cardano_core/                # LÕI MẬT MÃ RUST CHUẨN CML 6.2.0 FFI
│   ├── Cargo.toml                    # Cấu hình dependency: CML 6.2.0, zeroize, bip39
│   ├── src/
│   │   ├── lib.rs                    # Module root & Quản lý an toàn bộ nhớ
│   │   ├── api.rs                    # C-FFI Header & Giao diện hàm Native
│   │   ├── crypto.rs                 # BIP-39 PBKDF2, CIP-1852 HD Key Derivation
│   │   ├── tx_parser.rs              # Giải mã Conway CBOR, Governance, Certificates
│   │   ├── tx_signer.rs              # Ký Ed25519 & FIPS 140-3 Cryptographic Self-Verify
│   │   └── change_guard.rs           # Thuật toán Strict Change Guard quét 51 chỉ số
│   └── tests/
│       └── cardano_core_tests.rs     # 18 Unit Tests mật mã chuyên sâu
│
├── cardano_airgap_bridge/            # THƯ VIỆN DART FFI & DUAL-ENGINE BRIDGE
│   ├── pubspec.yaml                  # Khai báo dependency Dart
│   └── lib/
│       ├── cardano_airgap_bridge.dart # Entrypoint xuất bản thư viện
│       └── src/
│           ├── ffi_bridge_io.dart    # Nạp Native Library C-FFI (.so / .dll)
│           ├── ffi_bridge_web.dart   # Cầu nối Web Bridge phụ trợ qua HTTP :5050
│           ├── cardano_pure.dart     # Động cơ Pure-Dart CIP-1852 (Dành cho 32-bit & Web)
│           ├── bip39_pure.dart       # Pure-Dart BIP-39 CSPRNG & Wordlist 2048 từ
│           ├── models.dart           # Data Models, CardanoNetwork, ParsedTransaction
│           ├── multipart_qr.dart     # Bộ nén Zlib & Bộ chia mảnh Adaptive Animated QR
│           └── wallet_grouping.dart  # Nhóm ví theo Root Hash & Passphrase
│
├── mobile_cold/                      # ỨNG DỤNG VÍ LẠNH FLUTTER (OFFLINE KIOSK)
│   ├── pubspec.yaml                  # Cấu hình dự án Flutter Cold Wallet
│   ├── android/                      # Native Android Shell
│   │   └── app/src/main/
│   │       ├── AndroidManifest.xml   # KHÔNG cấp quyền INTERNET, khai báo DeviceAdmin
│   │       ├── res/xml/device_admin_receiver.xml # Chính sách Device Owner
│   │       └── kotlin/.../
│   │           └── AirGapDeviceAdminReceiver.kt  # Quản trị phần cứng cấp OS
│   └── lib/
│       ├── main.dart                 # Khởi chạy hệ thống, Kiosk LockTask & Sentinel
│       ├── core/
│       │   ├── security/             # Air-Gap Sentinel, Secure Storage, PIN Manager
│       │   └── theme/                # ColdTheme Cyberpunk Obsidian Dark & Badges
│       └── presentation/
│           ├── screens/              # Dashboard, Setup, Verify TX, Settings, Audit
│           └── widgets/              # Animated Multipart QR Viewer, Scanner
│
├── mobile_online/                    # ỨNG DỤNG VÍ NÓNG FLUTTER (ONLINE WATCH-ONLY)
│   ├── pubspec.yaml                  # Cấu hình dự án Flutter Hot Wallet
│   └── lib/
│       ├── main.dart                 # Entrypoint Ví Nóng
│       ├── core/
│       │   ├── network/              # BlockfrostClient (Hỗ trợ 3 mạng song song)
│       │   └── services/             # TxBuilder Conway, UTxO Resolver, Coin Selection
│       └── presentation/
│           ├── screens/              # Dashboard, Tx Create, Scanner, Settings
│           └── widgets/              # Animated QR Display, Account XPUB Importer
│
├── docs/                             # TÀI LIỆU KỸ THUẬT & KIỂM TOÁN HỆ THỐNG
│   ├── tech-document-finalv2.md      # Tài liệu đặc tả kỹ thuật hoàn chỉnh Master v2.0.3 (Tệp này)
│   ├── AIRGAP_KIOSK_GUIDE.md         # Sổ tay Kiosk Device Owner Android chuyên sâu
│   └── ...
│
├── scripts/                          # BỘ KỊCH BẢN TỰ ĐỘNG HÓA VẬN HÀNH & KIOSK
│   ├── platform-tools/               # Công cụ kết nối ADB Portable (Windows adb.exe)
│   ├── cai_dat_vi_lanh_j7.bat        # Kịch bản quản lý cài đặt chuyên dụng J7 Prime
│   ├── provision_kiosk.bat / .sh     # Kịch bản tự động hóa gán Device Owner qua ADB
│   ├── update_cold_wallet.bat / .sh  # Kịch bản cập nhật an toàn không mất dữ liệu
│   └── download_release_apk.ps1      # Tải APK chính thức từ GitHub Release
│
└── output/                           # CÁC BẢN PHÁT HÀNH ĐÓNG GÓI CHÍNH THỨC
    ├── v2.0.3/                       # Bản phát hành sản phẩm chính thức v2.0.3
    │   ├── apk/                      # Bộ cài đặt APK (Universal, ARMv7, ARM64)
    │   ├── cardano-hot-wallet-web-v2.0.3.zip # Gói Web PWA đóng gói
    │   ├── RELEASE_NOTES_v2.0.3.md   # Ghi chú phát hành phiên bản v2.0.3
    │   └── SHA256SUMS-v2.0.3.txt     # Bảng mã băm kiểm tra tính toàn vẹn
    └── web_hot_wallet/               # Thư mục triển khai GitHub Pages trực tiếp
```

### 1.4. Lộ trình Tiến hóa Hệ thống từ v2.0.0 đến v2.0.3
Hệ thống đã trải qua quá trình phát triển, kiểm thử thực địa và tối ưu hóa qua 4 cột mốc kỹ thuật lớn:
- **Phiên bản v2.0.0 (Foundation Alpha):** Xây dựng lõi mật mã Rust CML v6.2.0 FFI, triển khai thuật toán Strict Change Guard cơ bản và cơ chế ký giao dịch Conway CBOR.
- **Phiên bản v2.0.1 (Enterprise Gold Master):** Chuẩn hóa toàn bộ giao diện Tiếng Việt doanh nghiệp, tích hợp hệ thống Kiosk Sentinel trên Android với quyền Device Owner, hoàn thiện cơ chế Adaptive Multipart QR và bổ sung tính năng Ví Ẩn BIP-39 Passphrase tone tím Amethyst.
- **Phiên bản v2.0.2 (Galaxy J7 Prime & Web Hot Wallet Release):**
  - Mở rộng kiến trúc **Động cơ Kép (Dual-Engine Cryptography)** với việc phát triển module **Pure-Dart Cardano Engine (`CardanoPure`)** hoạt động 100% độc lập, giải quyết triệt để vấn đề tương thích thư viện native trên kiến trúc 32-bit ARMv7 (Samsung Galaxy J7 Prime, Exynos 7870).
  - Tách kênh xuất xưởng bộ cài APK thành 2 nhánh: Bản Universal và Bản chuyên biệt rút gọn ARMv7 (`cardano-cold-wallet-v2.0.2-armv7.apk`).
  - Xây dựng kịch bản quản lý cài đặt đa năng 1-click `cai_dat_vi_lanh_j7.bat` hỗ trợ song song 2 luồng: Cài mới sạch sẽ (Reset PIN) và Cập nhật an toàn (Giữ nguyên dữ liệu).
  - Đóng gói và phát hành ứng dụng Ví Nóng trực tuyến chạy trên trình duyệt Web (Web PWA CanvasKit) tại GitHub Pages với camera scanner HTML5 Video.
- **Phiên bản v2.0.3 (Multi-Network & Strict Network Guard - Bản hiện hành):**
  - Bổ sung bộ chuyển đổi **Đa Môi Trường Mạng 3 trong 1** (Mainnet, Preprod Testnet, Preview Testnet) đồng bộ giữa Ví Nóng và Ví Lạnh.
  - Xây dựng chốt chặn **Strict Network Guard**: Tự động bóc tách và kiểm tra tính hợp lệ của toàn bộ địa chỉ nhận và địa chỉ hoàn tiền trong chuỗi CBOR hex. Nếu phát hiện giao dịch chứa địa chỉ không khớp với mạng đang chọn (ví dụ quét giao dịch testnet trên ví Mainnet), ứng dụng lập tức báo động đỏ và **khóa cứng nút Ký duyệt**.
  - Động cơ **Dynamic Derivation Engine**: Tự động tái tính toán địa chỉ nhận tiền (`addr1...` $\leftrightarrow$ `addr_test1...`) và XPUB từ cùng cụm từ gốc mà không yêu cầu xóa ví hay nhập lại mnemonic.
  - Tích hợp hộp thoại xác nhận chuyển đổi mạng an toàn trong Cài đặt (`cold_settings_screen.dart`).

### 1.5. Sơ đồ Luồng Luân chuyển Dữ liệu Kép 3 Bước (3-Step Optical Pipeline)
Mọi chu trình tạo và phát sóng giao dịch giữa hai ví diễn ra qua 3 bước quang học tuần tự khép kín:

```text
+-----------------------+                    +-----------------------+
|   VÍ NÓNG TRỰC TUYẾN  |                    |   VÍ LẠNH NGOẠI TUYẾN |
|    (mobile_online)    |                    |     (mobile_cold)     |
+-----------------------+                    +-----------------------+
            |                                            |
 [Bước 1: LẬP GIAO DỊCH]                                 |
 1. Quét UTxO từ Blockfrost                              |
 2. Chọn Coin & Phí Mạng                                 |
 3. Dựng Unsigned Conway CBOR                            |
 4. Hiển thị Animated QR                                 |
    (UR:CARDANO-TX-Z)                                    |
            |                                            |
            |-------- [Quét Kênh Quang Học #1] --------->|
            |                                            |
            |                                 [Bước 2: GIẢI MÃ & KÝ]
            |                                 1. Quét Animated QR
            |                                 2. Strict Network Guard Check
            |                                 3. Bóc tách Anti-Blind Signing
            |                                 4. Strict Change Guard Verify
            |                                 5. Xác nhận PIN Người Dùng
            |                                 6. Ký Ed25519 & FIPS 140-3
            |                                 7. Hiển thị QR Chữ Ký
            |                                    (UR:CARDANO-TX / Witness)
            |                                            |
            |<------- [Quét Kênh Quang Học #2] ----------|
            |                                            |
 [Bước 3: GHÉP & PHÁT SÓNG]                              |
 1. Quét QR Chữ ký từ Ví Lạnh                            |
 2. Ghép Witness vào Tx Body                             |
 3. Đóng gói Signed Conway CBOR                          |
 4. Phát sóng lên Blockchain Node                        |
 5. Nhận Tx Hash & Cập nhật UI                           |
```

---

## PHẦN 2: ĐẶC TẢ LÕI MẬT MÃ DÙNG CHUNG VÀ KIẾN TRÚC ĐỘNG CƠ KÉP (DUAL-ENGINE CRYPTOGRAPHY)

```mermaid
graph LR
    subgraph Caller["Tầng Ứng Dụng (Flutter Dart)"]
        App[mobile_cold / mobile_online]
    end

    subgraph Bridge["cardano_airgap_bridge"]
        FfiBridge[ffi_bridge_io.dart]
        Detector{Hỗ trợ C-FFI Native?}
        PureDart[cardano_pure.dart<br/>bip39_pure.dart]
    end

    subgraph NativeCore["rust_cardano_core"]
        CmlLib[librust_cardano_core.so / .dll<br/>CML v6.2.0 + Zeroize]
    end

    App --> FfiBridge
    FfiBridge --> Detector
    Detector -- "Có (64-bit Android / Windows)" --> CmlLib
    Detector -- "Không (32-bit ARMv7 J7 Prime / Web)" --> PureDart
```

### 2.1. Động cơ Mật mã Kép: Rust CML FFI & Pure-Dart Engine
Để đạt được sự cân bằng tối đa giữa hiệu năng xử lý mật mã đỉnh cao và khả năng tương thích toàn diện trên các thiết bị cũ (đặc biệt là Samsung Galaxy J7 Prime chạy kiến trúc 32-bit ARMv7), hệ thống áp dụng kiến trúc **Động cơ Kép (Dual-Engine Architecture)**:
1. **Engine 1 - Lõi Native Rust CML (`librust_cardano_core.so` / `.dll`):**
   - Xây dựng trên nền tảng thư viện chính thức của Cardano Foundation: `cardano-multiplatform-lib` (CML) v6.2.0.
   - Biên dịch native cho các target: `x86_64-pc-windows-msvc`, `aarch64-linux-android` (arm64-v8a).
   - Tối ưu hóa tính toán toán học đường cong elliptic Curve25519 bằng lệnh hợp ngữ (Assembly SIMD).
   - Tích hợp cơ chế tự động xóa sạch bộ nhớ `zeroize`.
2. **Engine 2 - Lõi Pure-Dart Cardano (`CardanoPure` & `Bip39Pure`):**
   - Viết hoàn toàn bằng ngôn ngữ Dart chuẩn, không phụ thuộc bất kỳ tệp thư viện động `.so` hay `.dll` nào.
   - Đảm bảo ứng dụng chạy mượt mà 100% trên thiết bị 32-bit ARMv7 (`armeabi-v7a`) mà không bao giờ gặp sự cố thiếu symbol hay lỗi ABI tải thư viện động.
   - Đảm bảo tính nhất quán trên nền tảng Web PWA CanvasKit khi không có môi trường C-FFI.
   - Cơ chế tự động phát hiện: Lớp `CardanoCoreBridge` trong `ffi_bridge_io.dart` sẽ thử nạp thư viện Native; nếu nạp thất bại hoặc môi trường không hỗ trợ, hệ thống sẽ tự động chuyển hướng trong suốt (transparent fallback) sang `CardanoPure`.

### 2.2. Chuẩn Sinh Mnemonic BIP-39 & Entropy An Toàn CSPRNG
Hệ thống tuân thủ nghiêm ngặt tiêu chuẩn quốc tế **BIP-39**:
- **Tập từ điển:** 2048 từ tiếng Anh chuẩn hóa (Wordlist BIP-39 English).
- **Độ dài Mnemonic:** Hỗ trợ 12, 15, và 24 từ. Mặc định khởi tạo 24 từ với độ dài entropy 256 bits để đảm bảo an toàn tuyệt đối chống tấn công vét cạn.
- **Khởi tạo Entropy an toàn CSPRNG:** Sử dụng hàm sinh số ngẫu nhiên mật mã của hệ điều hành (`/dev/urandom` trên Android/Linux, `BCryptGenRandom` trên Windows).
- **Công thức tính Checksum BIP-39:**
  $$\text{Checksum Length } CS = \frac{ENT}{32} \text{ bits}$$
  $$\text{Total Bits } MS = ENT + CS$$
  Entropy được băm qua thuật toán SHA-256; $CS$ bits đầu tiên của mã băm sẽ được nối vào cuối chuỗi Entropy trước khi chia thành các nhóm 11 bits để ánh xạ vào danh sách 2048 từ.

### 2.3. Phái sinh Khóa Phân cấp CIP-1852 (Shelley/Conway Era HD Wallet)
Cấu trúc cây phái sinh khóa phân cấp tuân thủ chuẩn **CIP-1852** dành cho kỷ nguyên Shelley và Conway:

$$\text{Path: } m / 1852' / 1815' / \text{account}' / \text{role} / \text{address\_index}$$

Trong đó:
- `1852'`: Purpose code chỉ định chuẩn ví Cardano Shelley/Conway HD Wallet.
- `1815'`: Coin type dành cho đồng ADA của Cardano (theo năm sinh của Ada Lovelace).
- `account'`: Chỉ số tài khoản (bắt đầu từ `0'`), cho phép tách biệt các quỹ tài sản trong cùng một ví.
- `role`: Xác định vai trò của cặp khóa:
  - `role = 0`: Địa chỉ thanh toán công khai bên ngoài (External Payment Address - nhận tiền từ người khác).
  - `role = 1`: Địa chỉ thanh toán tiền thừa nội bộ (Internal Change Address - nhận tiền thối lại từ UTxO).
  - `role = 2`: Địa chỉ chứng chỉ cổ phần (Staking Credential / Stake Key).
- `address_index`: Chỉ số tuần tự của địa chỉ (bắt đầu từ `0`).

### 2.4. Cơ chế Phái sinh Kép: BIP-39 Seed Mặc định & CIP-0003 Icarus
Hệ thống hỗ trợ song song 2 phương pháp chuyển đổi Mnemonic thành Master Root Key:
1. **Phương pháp Chuẩn BIP-39 PBKDF2 (Mặc định):**
   - Áp dụng thuật toán tạo khóa mật mã PBKDF2 với hàm băm HMAC-SHA512:
     $$\text{Seed} = \text{PBKDF2}(\text{HMAC-SHA512}, \text{Mnemonic}, \text{Salt} = \text{"mnemonic"} + \text{Passphrase}, \text{Iterations} = 2048, \text{Len} = 64)$$
   - Từ 64 bytes Seed, phái sinh khóa gốc Ed25519-BIP32:
     $$I = \text{HMAC-SHA512}(\text{Key} = \text{"ed25519 seed"}, \text{Data} = \text{Seed}[0..32])$$
     $$k_L = I[0..32], \quad k_R = I[32..64]$$
   - Cắt tỉa bit (Bit clamping) theo chuẩn Ed25519:
     $$k_L[0] \ \&= 248, \quad k_L[31] \ \&= 127, \quad k_L[31] \ |= 64$$
2. **Phương pháp CIP-0003 Icarus Master Derivation (Tùy chọn tương thích Daedalus/Yoroi):**
   - Sử dụng trực tiếp chuỗi Entropy gốc để tính mã băm Blake2b-512 hoặc HMAC-SHA512 theo quy cách Icarus, giúp người dùng có thể khôi phục chính xác các ví Cardano lịch sử được tạo từ các ứng dụng cũ.

### 2.5. Cấu trúc Địa chỉ Cơ sở (Shelley Base Address - CIP-0019) & Phân định Mạng
Địa chỉ Cardano Shelley/Conway Base Address là sự kết hợp của 2 phần tử mã hóa theo chuẩn **CIP-0019** và mã hóa nhị phân Bech32:

```text
[Header Byte: 1 byte] + [Payment KeyHash: 28 bytes] + [Stake KeyHash: 28 bytes] = 57 bytes
```

- **Header Byte (Type 0 - Base Address):**
  $$\text{Header} = (\text{AddressType} \ll 4) \ | \ \text{NetworkId}$$
  - Trên mạng **Mainnet**: $\text{NetworkId} = 1 \implies \text{Header} = (0 \ll 4) \ | \ 1 = \mathbf{0x01}$.
  - Trên mạng **Testnet (Preprod/Preview)**: $\text{NetworkId} = 0 \implies \text{Header} = (0 \ll 4) \ | \ 0 = \mathbf{0x00}$.
- **Địa chỉ Stake (Type 14 - Reward Account):**
  - Mainnet: Header byte = $\mathbf{0xE1}$ $\implies$ Tiền tố Bech32: `stake1...`
  - Testnet: Header byte = $\mathbf{0xE0}$ $\implies$ Tiền tố Bech32: `stake_test1...`
- **Địa chỉ Thanh toán (Payment Address):**
  - Mainnet: Header byte = $\mathbf{0x01}$ $\implies$ Tiền tố Bech32: `addr1...`
  - Testnet: Header byte = $\mathbf{0x00}$ $\implies$ Tiền tố Bech32: `addr_test1...`

### 2.6. Xuất Khóa Công khai Mở rộng Tài khoản (Account XPUB) cho Watch-Only
Nhằm cho phép Ví Nóng trực tuyến có thể giám sát số dư và tự động phát hiện địa chỉ mới mà không cần lưu khóa bí mật, Ví Lạnh cung cấp tính năng xuất Khóa công khai mở rộng:
- **Đường dẫn trích xuất:** $m / 1852' / 1815' / \text{account}'$
- **Cấu trúc Khóa XPUB (64 bytes):**
  $$\text{XPUB} = [\text{Extended Public Key: 32 bytes}] + [\text{Chain Code: 32 bytes}]$$
- Khóa XPUB cho phép Ví Nóng áp dụng thuật toán dẫn xuất khóa công khai con (Non-hardened child public key derivation) cho $\text{role} \in \{0, 1\}$ và $\text{index} \ge 0$ mà **toàn bộ quá trình tính toán không thể đảo ngược để tìm ra khóa riêng tư**.

### 2.7. Cơ chế Xóa Sạch Bộ Nhớ Sâu (Deep Memory Zeroization) & Khử Dữ liệu Nhạy cảm
Nhằm triệt tiêu nguy cơ rò rỉ khóa bí mật qua các kỹ thuật đọc trộm RAM (Cold Boot Attack, RAM Dump):
- Trong tầng Rust: Mọi cấu trúc dữ liệu lưu trữ Mnemonic, Seed, Root Extended Private Key (`XPrv`), và Session Keys đều áp dụng trait `Zeroize` và `ZeroizeOnDrop`. Khi các biến ra khỏi tầm vực (scope), bộ nhớ heap và stack chứa dữ liệu mật mã sẽ tự động bị ghi đè các byte `0x00` bằng lệnh hợp ngữ ngăn chặn tối ưu hóa trình biên dịch (`volatile write`).
- Trong tầng Dart C-FFI Bridge (`ffi_bridge_io.dart`): Hàm giải phóng con trỏ `_secureFreeUtf8` chủ động duyệt toàn bộ độ dài chuỗi nhạy cảm trên C-Heap và ghi đè `0x00` trước khi gọi `malloc.free`:
  ```dart
  static void _secureFreeUtf8(Pointer<Utf8> ptr, [int? knownByteLen]) {
    if (ptr == nullptr) return;
    try {
      final len = knownByteLen ?? ptr.length;
      final bytePtr = ptr.cast<Uint8>();
      for (int i = 0; i < len; i++) {
        bytePtr[i] = 0; // Deep Zeroization
      }
    } catch (_) {}
    malloc.free(ptr);
  }
  ```

---

## PHẦN 3: BỘ PHÂN TÍCH GIAO DỊCH CONWAY CBOR & CHỐNG KÝ MÙ (ANTI-BLIND SIGNING)

```mermaid
flowchart TD
    RawCbor["Chuỗi Nhị Phân Giao Dịch Conway CBOR (Hex)"] --> Decoder["Bộ Giải Mã Nhị Phân CML / Pure-Dart"]
    Decoder --> Parser["Bộ Phân Tích Cú Pháp Chống Ký Mù (Anti-Blind Parser)"]

    subgraph Fields["Bóc Tách Toàn Diện Các Trường Dữ Liệu"]
        Parser --> Fee["Phí Mạng (Fee Lovelace)"]
        Parser --> TTL["Hạn Hiệu Lực Thời Gian (TTL)"]
        Parser --> InOut["Tập Inputs (UTxO) & Tập Outputs"]
        Parser --> Tokens["Tài Sản Token & Multi-Asset (PolicyID, AssetName)"]
        Parser --> GovCert["Chứng Chỉ Quản Trị CIP-1694 (DRep Delegation)"]
        Parser --> Withdrawals["Rút Thưởng Staking (Withdrawals)"]
    end

    InOut --> VerifyDest["Xác Định Địa Chỉ Nhận & Địa Chỉ Tiền Thừa"]
    VerifyDest --> ChangeCheck["Thuật Toán Strict Change Guard"]
    VerifyDest --> NetCheck["Thuật Toán Strict Network Guard"]

    ChangeCheck & NetCheck & GovCert --> UI["Bảng Hiển Thị Trực Quan Minh Bạch (TxVerifyScreen)"]
```

### 3.1. Giải mã Cấu trúc Nhị phân CBOR Giao dịch Kỷ nguyên Conway (CIP-1694)
Giao dịch Cardano kỷ nguyên Conway được đóng gói theo chuẩn định dạng nhị phân **CBOR (Concise Binary Object Representation - RFC 8949)**. Cấu trúc một giao dịch hoàn chỉnh gồm 4 phần tử chính:

$$\text{Transaction} = [\text{TransactionBody}, \text{WitnessSet}, \text{IsValid: bool}, \text{AuxiliaryData / Metadata}]$$

Bộ phân tích `tx_parser.rs` tiến hành bóc tách đệ quy `TransactionBody` dạng Map:
- Key 0: `set<transaction_input>` (Tập danh sách UTxO đầu vào)
- Key 1: `[* transaction_output]` (Danh sách đầu ra giao dịch)
- Key 2: `coin` (Phí giao dịch mạng tính bằng Lovelace)
- Key 3: `uint` (Thời gian hết hạn giao dịch - Time to Live TTL)
- Key 4: `[* certificate]` (Danh sách chứng chỉ staking và quản trị CIP-1694)
- Key 5: `withdrawals` (Bản đồ rút tiền thưởng từ tài khoản stake)
- Key 9: `mint` (Bản đồ đúc hoặc đốt Native Tokens)
- Key 11: `script_data_hash` (Mã băm dữ liệu Plutus V1/V2/V3)
- Key 16: `voting_procedures` (Thủ tục bỏ phiếu quản trị Conway)
- Key 17: `proposal_procedures` (Đề xuất quản trị On-chain)

### 3.2. Bóc tách Toàn diện: Inputs, Outputs, Phí Mạng (Fee), TTL, Minting & Multi-Asset
Mỗi đối tượng đầu ra `transaction_output` được giải mã chi tiết thành:
- **Địa chỉ Đích:** Giải mã nhị phân thành định dạng Bech32 có thể đọc được (`addr1...` hoặc `addr_test1...`).
- **Giá trị ADA:** Tính toán chính xác lượng Lovelace và chuyển đổi sang ADA ($1 \text{ ADA} = 1,000,000 \text{ Lovelace}$).
- **Native Tokens (Multi-Asset):** Bóc tách Policy ID (28 bytes hex), tên tài sản Asset Name (chuyển đổi từ Hex sang chuỗi ký tự UTF-8), và số lượng nguyên tử.
- **Xác định Phí mạng & TTL:** Cảnh báo nếu phí mạng vượt quá ngưỡng an toàn thông thường (> 1.5 ADA) hoặc thời hạn TTL quá xa so với thời điểm hiện tại.

### 3.3. Bóc tách Chứng chỉ Quản trị Conway (DRep Delegation) & Ủy thác Stake Pool
Giao dịch trong kỷ nguyên Conway thường mang theo các chứng chỉ quản trị on-chain phức tạp:
1. **Ủy quyền DRep (Vote Delegation Certificate):**
   - Bóc tách DRep Credential: Nhận diện DRep dạng Hash, DRep dạng Script, hoặc hai tùy chọn đặc biệt:
     - `AlwaysAbstain`: Luôn bỏ phiếu trắng trong mọi biểu quyết quản trị.
     - `AlwaysNoConfidence`: Luôn bỏ phiếu bất tín nhiệm đối với Ủy ban Lập hiến.
2. **Ủy thác Stake Pool (Stake Pool Delegation Certificate):**
   - Bóc tách Stake Credential và Pool ID (dạng Bech32 `pool1...`).
3. **Đăng ký / Hủy đăng ký Stake Credential:**
   - Kiểm tra khoản tiền ký quỹ đặt cọc (Deposit 2 ADA) hoặc hoàn trả đặt cọc (Refund 2 ADA).

### 3.4. Bóc tách Rút thưởng Cổ phần (Withdrawals) & Điều kiện Ký Kép (Dual-Witness)
Khi giao dịch có chứa yêu cầu rút tiền thưởng tích lũy từ Staking (Withdrawals):
- Bóc tách địa chỉ `stake1...` / `stake_test1...` rút tiền và số Lovelace rút về.
- **Cảnh báo Ký Kép (Dual-Witness Requirement):** Hệ thống nhận diện giao dịch yêu cầu bắt buộc phải có chữ ký của cả Payment Key (`role = 0`) và Stake Key (`role = 2`). Lõi mật mã sẽ tự động lập lịch ký kép 2 lần và sinh 2 Vkeywitness riêng biệt để giao dịch hợp lệ trên blockchain.

### 3.5. Hệ thống Cảnh báo Trực quan & Các Chốt chặn Phòng vệ Ký Mù
Để loại bỏ 100% rủi ro Ký Mù:
- Mọi thông tin cốt lõi được định dạng thành các thẻ trực quan có phân cấp màu sắc rõ rệt.
- Nếu giao dịch có chứa các phần tử rủi ro (như hợp đồng Plutus phức tạp, đốt token không mong muốn, hoặc không có tiền thừa), hệ thống hiển thị hộp cảnh báo màu hổ phách hoặc màu đỏ kèm theo giải thích chi tiết bằng tiếng Việt.
- Nút xác nhận ký chỉ được kích hoạt sau khi người dùng đã cuộn qua toàn bộ thông tin chi tiết của giao dịch.

---

## PHẦN 4: CƠ CHẾ CHỐNG ĐÁNH TRÁO TIỀN THỪA NGHIÊM NGẶT (STRICT CHANGE GUARD)

```mermaid
flowchart TD
    TxOutputs["Danh Sách Đầu Ra (Outputs) Trong Giao Dịch"] --> FilterChange{"Xác Định Output Tiền Thừa (Change Output)?"}

    FilterChange -- "Không có Output thứ 2" --> CheckDrain["Cảnh Báo Giao Dịch 1-Output: RÚT CẠN VÍ"]
    FilterChange -- "Có Output thứ 2 (Change)" --> ExtractChange["Trích Xuất Địa Chỉ Change & Stake Credential C_stake"]

    subgraph DerivationSpace["Không Gian Khóa Của Ví Lạnh (Tài Khoản Hiện Tại)"]
        AccXPUB["Account XPUB (m/1852'/1815'/acc')"] --> DeriveChange["Phái Sinh 51 Địa Chỉ Nội Bộ: m/1852'/1815'/acc'/1/0..50"]
        DeriveChange --> ExtractStake["Trích Xuất Stake Credential Hợp Lệ S_stake (role 2 index 0)"]
    end

    ExtractChange & ExtractStake --> CompareCred{"C_stake == S_stake ?"}

    CompareCred -- "Trùng Khớp (Equal)" --> CompareIndex{"Địa Chỉ Nằm Trong 51 Địa Chỉ Nội Bộ?"}
    CompareCred -- "Sai Lệch (Mismatch)" --> AttackAlarm["BÁO ĐỘNG ĐỎ: PHÁT HIỆN ĐÁNH TRÁO TIỀN THỪA (HIJACKING)"]

    CompareIndex -- "Hợp Lệ" --> Verified["CHANGE GUARD: XÁC MINH TUYỆT ĐỐI AN TOÀN (Cho Phép Ký)"]
    CompareIndex -- "Không Nằm Trong Dải" --> WarnAudit["CẢNH BÁO: Stake Khớp Nhưng Index > 50 (Cần Kiểm Toán)"]

    AttackAlarm --> LockKill["FAIL-CLOSED: KHÓA CHẾT NÚT KÝ DUYỆT"]
```

### 4.1. Mối Đe Dọa Đánh Tráo Tiền Thừa (UTxO Change Hijacking Attack)
Trong mô hình eUTxO của Cardano, khi chi tiêu một UTxO có số dư lớn hơn số tiền cần gửi, phần tiền còn lại phải được hoàn trả vào một địa chỉ tiền thừa (Change Address) thuộc quyền sở hữu của người gửi.
- **Kịch bản Tấn công:** Kẻ tấn công cài cắm mã độc trên Ví Nóng hoặc can thiệp vào máy chủ API trực tuyến để thay thế địa chỉ tiền thừa bằng địa chỉ của kẻ tấn công trong chuỗi nhị phân CBOR gửi sang Ví Lạnh.
- **Hậu quả nếu Ký Mù:** Nếu Ví Lạnh chỉ hiển thị số tiền gửi cho người nhận (ví dụ gửi 5 ADA) mà không kiểm tra địa chỉ tiền thừa, người dùng ký duyệt giao dịch sẽ vô tình chuyển toàn bộ 9,995 ADA còn lại trong UTxO vào tay kẻ tấn công.

### 4.2. Thuật toán Đối soát Khóa Cổ phần (Stake Credential Matching)
Nhằm triệt tiêu triệt để nguy cơ này, lõi mật mã triển khai thuật toán **Strict Change Guard** (`change_guard.rs`):
1. **Trích xuất Stake Credential của Địa chỉ Tiền thừa:**
   - Mọi địa chỉ Base Address của Cardano đều chứa 28 bytes mã băm khóa cổ phần $C_{\text{stake}}$:
     $$C_{\text{stake}} = \text{Address}[29..57]$$
2. **Trích xuất Stake Credential Gốc của Ví:**
   - Từ Account Extended Public Key (`XPUB`), phái sinh khóa cổ phần duy nhất của tài khoản tại đường dẫn:
     $$m / 1852' / 1815' / \text{account}' / 2 / 0$$
   - Tính mã băm Blake2b-224 của Public Key tương ứng để thu được $S_{\text{stake}}$:
     $$S_{\text{stake}} = \text{Blake2b-224}(\text{PublicKey}_{\text{stake}})$$
3. **Mệnh đề So Khớp Bất Biến:**
   $$\text{Change Safe} \iff C_{\text{stake}} == S_{\text{stake}}$$
   Nếu mã băm không trùng khớp, giao dịch ngay lập tức bị kết luận là **BỊ TẤN CÔNG ĐÁNH TRÁO TIỀN THỪA**.

### 4.3. Quét Đa Điểm Không Gian Địa chỉ Nội bộ (`role = 1`, 51 chỉ số)
Để tăng cường phòng vệ theo chiều sâu, ngoài việc so khớp Stake Credential, hệ thống tiến hành phái sinh trước **51 địa chỉ nội bộ** (`role = 1, index \in [0..50]`):
- So sánh địa chỉ tiền thừa trong giao dịch với tập hợp 51 địa chỉ này.
- Nếu địa chỉ tiền thừa trùng khớp hoàn toàn với một địa chỉ trong tập hợp, hệ thống đánh dấu cờ `is_change_verified = true` và xác định chính xác chỉ số `change_index`.

### 4.4. Bảo vệ Giao dịch 1-Output & Cảnh Báo Rút Cạn Ví (Full Drain Attack)
Trong trường hợp giao dịch chỉ có duy nhất **1 Output** (toàn bộ tiền trong UTxO được gửi đi và không có tiền thừa trả về):
- Hệ thống kích hoạt trạng thái cảnh báo đặc biệt: **"CẢNH BÁO: GIAO DỊCH RÚT CẠN VÍ (1-OUTPUT DRAIN)"**.
- Bắt buộc giao diện hiển thị hộp cảnh báo màu vàng cảnh báo người dùng rằng tài khoản sẽ không nhận lại bất kỳ đồng ADA thối nào từ các UTxO đã chọn.

### 4.5. Cơ chế Khóa Chết Ký Duyệt Fail-Closed khi Phát hiện Sai lệch
Nếu thuật toán Change Guard phát hiện địa chỉ tiền thừa có dấu hiệu giả mạo:
- Trạng thái `isChangeSafe` được gán bằng `false`.
- Giao diện `TxVerifyScreen` chuyển sang chế độ báo động khẩn cấp: Thẻ thông tin tiền thừa vi phạm chuyển sang màu đỏ rực.
- Nút bấm ký duyệt bị vô hiệu hóa hoàn toàn (`onPressed: null`), nhãn nút đổi thành **"ĐÃ KHÓA KÝ (KHÔNG AN TOÀN)"**.
- Người dùng tuyệt đối không thể xác nhận ký trong mọi tình huống.

---

## PHẦN 5: BỘ CHUYỂN ĐỔI ĐA MÔI TRƯỜNG MẠNG & CHỐT CHẶN STRICT NETWORK GUARD v2.0.3

```mermaid
stateDiagram-v2
    [*] --> Dashboard: Khởi Động Ứng Dụng (Mặc Định Preprod)

    state Dashboard {
        NetworkBadge: Huy Hiệu Mạng Trên AppBar (🟢/🟠/🔵)
        WalletAddress: Địa Chỉ Ví Đang Kích Hoạt
    }

    Dashboard --> Settings: Mở Cài Đặt Ví Lạnh
    Settings --> NetworkDialog: Chạm "Chuyển Đổi Môi Trường Mạng"

    state NetworkDialog {
        SelectMainnet: 🟢 Cardano Mainnet (Tài Sản Thật)
        SelectPreprod: 🟠 Preprod Testnet (Mặc Định)
        SelectPreview: 🔵 Preview Testnet (Thử Nghiệm Mới)
    }

    NetworkDialog --> ConfirmDialog: Chọn Mạng Mới != Mạng Hiện Tại
    ConfirmDialog --> DynamicDerive: Bấm "Xác Nhận Chuyển Đổi"

    state DynamicDerive {
        RecalculateAddresses: Tái Dẫn Xuất Toàn Bộ Ví (addr1 <-> addr_test1)
        SaveSecureStorage: Lưu Mã Hóa Tùy Chọn Mạng
        UpdateState: Làm Mới Toàn Bộ Dashboard & QR Code
    }

    DynamicDerive --> Dashboard: Quay Lại Màn Hình Chính
```

### 5.1. Kiến trúc Đa Mạng: Mainnet, Preprod Testnet & Preview Testnet
Trong phiên bản phát hành chính thức **v2.0.3**, hệ thống tích hợp giải pháp quản trị mạng toàn diện hỗ trợ 3 môi trường mạng chủ lực của hệ sinh thái Cardano:

| Thông Số Kỹ Thuật | Cardano Mainnet | Preprod Testnet | Preview Testnet |
| :--- | :--- | :--- | :--- |
| **Mục đích sử dụng** | Mạng chính thức (Tài sản ADA thật) | Thử nghiệm dài hạn, tích hợp dApp | Thử nghiệm các tính năng cốt lõi mới |
| **Network ID** | `1` | `0` | `0` |
| **Protocol Magic** | `764824073` | `1` | `2` |
| **Tiền tố Địa chỉ Payment** | `addr1...` | `addr_test1...` | `addr_test1...` |
| **Tiền tố Địa chỉ Stake** | `stake1...` | `stake_test1...` | `stake_test1...` |
| **Mã màu Nhận diện UI** | 🟢 Xanh Lục Emerald (`0xFF10B981`) | 🟠 Hổ Phách Amber (`0xFFF59E0B`) | 🔵 Xanh Lam Sapphire (`0xFF3B82F6`) |
| **Blockfrost API Endpoint** | `cardano-mainnet.blockfrost.io` | `cardano-preprod.blockfrost.io` | `cardano-preview.blockfrost.io` |

### 5.2. Động cơ Tự động Tái Dẫn xuất Địa chỉ Động (Dynamic Derivation Engine)
Trước phiên bản v2.0.3, việc chuyển đổi mạng thường yêu cầu người dùng phải xóa ví và nhập lại cụm từ khôi phục từ đầu. Hệ thống v2.0.3 giải quyết triệt để vấn đề này bằng **Dynamic Derivation Engine**:
- Khi người dùng thay đổi môi trường mạng (ví dụ từ Preprod sang Mainnet), hàm `switchNetwork(targetNetwork)` trong `cold_wallet_provider.dart` sẽ tự động duyệt qua danh sách toàn bộ các ví đang quản lý trong bộ nhớ mã hóa:
  ```dart
  Future<void> switchNetwork(CardanoNetwork targetNetwork) async {
    if (state.network == targetNetwork) return;
    await _security.saveNetwork(targetNetwork);
    final isTestnet = targetNetwork != CardanoNetwork.mainnet;

    final updatedWallets = state.wallets.map((w) {
      if (w.mnemonic.isNotEmpty) {
        final keys = CardanoCoreBridge.createWallet(
          w.mnemonic,
          isTestnet: isTestnet,
          accountIndex: w.accountIndex,
          addressIndex: w.addressIndex,
        );
        return w.copyWith(
          paymentAddress: keys.paymentAddress,
          stakeAddress: keys.stakeAddress,
          accountXpubHex: keys.accountXpubHex,
        );
      }
      return w;
    }).toList();

    state = state.copyWith(
      network: targetNetwork,
      wallets: updatedWallets,
      activeWallet: updatedWallets.firstWhere((w) => w.id == state.activeWallet?.id, orElse: () => state.activeWallet!),
    );
  }
  ```
- **Kết quả:** Địa chỉ nhận tiền và địa chỉ stake của tất cả các ví được chuyển đổi định dạng tức thì mà không yêu cầu nhập lại bất kỳ thông tin nào, đồng thời mã QR công khai trên Dashboard tự động cập nhật ngay lập tức.

### 5.3. Chốt chặn An toàn Lệch mạng Nghiêm ngặt (Strict Network Guard)
Để ngăn ngừa tuyệt đối nguy cơ người dùng vô tình ký một giao dịch Mainnet (tiền thật) khi tưởng rằng đang thao tác trên mạng thử nghiệm Testnet:
- Trong màn hình thẩm định giao dịch `tx_verify_screen.dart`, hệ thống kích hoạt chốt chặn **Strict Network Guard**:
  ```dart
  bool get _isNetworkMismatch {
    final currentNetwork = ref.read(coldWalletProvider).network;
    final isMainnet = currentNetwork == CardanoNetwork.mainnet;
    for (final out in tx.outputs) {
      final addr = out.address.toLowerCase();
      // Nếu đang ở Mainnet mà phát hiện địa chỉ Testnet
      if (isMainnet && (addr.startsWith('addr_test1') || addr.startsWith('stake_test1'))) {
        return true;
      }
      // Nếu đang ở Testnet mà phát hiện địa chỉ Mainnet
      if (!isMainnet && (addr.startsWith('addr1') || addr.startsWith('stake1'))) {
        return true;
      }
    }
    return false;
  }
  ```
- **Hành vi Bảo vệ:** Khi `_isNetworkMismatch == true`:
  1. Xuất hiện banner cảnh báo đỏ nổi bật trên đầu màn hình: *"CẢNH BÁO STRICT NETWORK GUARD: Giao dịch này chứa địa chỉ nhận/change không thuộc mạng [Tên mạng] đang chọn. Để ngăn ngừa thất thoát tài sản, Ví Lạnh đã khóa chức năng ký."*
  2. Nút ký duyệt giao dịch lập tức bị vô hiệu hóa và chuyển sang nhãn: **"ĐÃ KHÓA KÝ (LỆCH MẠNG)"**.
  3. Mọi thao tác cố tình gọi hàm ký đều bị chặn đứng và đưa ra thông báo lỗi từ chối rõ ràng.

### 5.4. Giao diện Chuyển đổi Mạng Trực quan & Network Badges
Giao diện chuyển đổi môi trường mạng được thiết kế tối ưu hóa trải nghiệm người dùng theo yêu cầu thực tế:
- **Network Badge trên AppBar:** Hiển thị trực tiếp trạng thái mạng hiện hành với huy hiệu bo góc và màu sắc đặc trưng.
- **Tích hợp bên trong Cài đặt (Settings Screen):** Chức năng chuyển đổi mạng được đặt an toàn bên trong mục Cài đặt (`cold_settings_screen.dart`). Khi nhấn vào, hệ thống mở hộp thoại tùy chọn mạng với các nút bấm trực quan có biểu tượng sóng và mô tả chi tiết:
  - *"Cardano Mainnet - Mạng chính thức (Tài sản ADA thật)"*
  - *"Preprod Testnet - Môi trường thử nghiệm dài hạn (Mặc định)"*
  - *"Preview Testnet - Môi trường thử nghiệm tính năng mới"*
- **Hộp thoại Cảnh báo Xác nhận (Confirmation Dialog):** Khi chuyển sang mạng Mainnet, ứng dụng hiển thị thêm lời nhắc nhở an ninh để người dùng ý thức rõ việc chuẩn bị giao dịch với tài sản thực tế.

### 5.5. Lưu trữ Bền vững Môi trường Mạng & Đồng bộ 1:1
- Trạng thái mạng đã chọn được mã hóa và lưu trữ an toàn trong `FlutterSecureStorage` thông qua khóa `cardano_active_network`.
- Khi ứng dụng Ví Lạnh khởi động lại, trạng thái mạng được phục hồi nguyên vẹn mà không bị đặt lại về mặc định.
- Khi tạo mới ví hoặc khôi phục ví bằng cụm từ 24 từ, hệ thống tự động kế thừa môi trường mạng đang hoạt động, đồng thời cho phép người dùng lựa chọn lại môi trường mạng mong muốn thông qua các thẻ lựa chọn (ChoiceChip) trực quan.

---

## PHẦN 6: ĐẶC TẢ CHI TIẾT ỨNG DỤNG VÍ LẠNH NGOẠI TUYẾN (`mobile_cold`)

```mermaid
flowchart TD
    OSBoot["Khởi Động Hệ Điều Hành Android (Samsung J7 Prime)"] --> CheckDO{"Đã Cấp Quyền Device Owner?"}

    CheckDO -- "Chưa (Chế Độ Kiểm Thử)" --> StandardStart["Khởi Chạy Ứng Dụng (Cảnh Báo Chưa Kích Hoạt Kiosk)"]
    CheckDO -- "Đã Cấp (Bản Xuất Xưởng)" --> KioskEnforce["Cưỡng Chế Phần Cứng Cấp Doanh Nghiệp"]

    subgraph HardwareLockdown["Chính Sách Khóa Phần Cứng Kiosk Sentinel"]
        KioskEnforce --> AirplaneLock["Ép Bật Airplane Mode = ON (Khóa Cấm Tắt)"]
        KioskEnforce --> RadioBlock["Cấm Bật Wi-Fi & Bluetooth Vĩnh Viễn"]
        KioskEnforce --> UsbBlock["Chặn Truyền Tệp USB (Chỉ Nhận Nguồn Sạc)"]
        KioskEnforce --> PinApp["Kích Hoạt LockTask Mode (Ghim Màn Hình, Ẩn Thanh Điều Hướng)"]
    end

    StandardStart & PinApp --> InAppSentinel["Lớp Giám Sát In-App Sentinel (BroadcastReceiver & NetworkCallback)"]

    InAppSentinel --> MonitorLoop{"Phát Hiện Sóng Vô Tuyến Kích Hoạt?"}
    MonitorLoop -- "An Toàn (100% Offline)" --> AppRunning["Mở Khóa Giao Diện Sử Dụng Bình Thường"]
    MonitorLoop -- "Vi Phạm Air-Gap!" --> LockdownScreen["KÍCH HOẠT MÀN HÌNH ĐỎ PHONG TỎA KHẨN CẤP"]

    LockdownScreen --> MemPurge["XÓA SẠCH TOÀN BỘ KHÓA TRONG RAM (ZEROIZE)"]
    LockdownScreen --> LockSign["KHÓA CỨNG NÚT TẠO VÍ & KÝ GIAO DỊCH"]
```

### 6.1. Triết lý Thiết kế Zero Internet & Loại bỏ Hoàn toàn Quyền Truy cập Mạng
Khác với các ứng dụng ví thông thường, tệp khai báo hệ thống `AndroidManifest.xml` của `mobile_cold` hoàn toàn **KHÔNG CHỨA QUYỀN TRUY CẬP INTERNET**:
```xml
<!-- TUYỆT ĐỐI KHÔNG KHAI BÁO: <uses-permission android:name="android.permission.INTERNET" /> -->
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.VIBRATE" />
```
Điều này đảm bảo rằng ngay cả khi có lỗ hổng bảo mật cấp ứng dụng hoặc thư viện bên thứ ba bị xâm nhập, kẻ tấn công cũng **không thể mở bất kỳ kết nối mạng nào** ra bên ngoài do bị hệ điều hành Android từ chối ngay từ tầng hạt nhân Linux (Linux Kernel Network Namespace).

### 6.2. Hệ thống Kiosk Sentinel v2 & Cưỡng chế Phần cứng Device Owner
Để biến chiếc điện thoại phổ thông (như Samsung Galaxy J7 Prime) thành két sắt lạnh chuyên dụng, hệ thống triển khai kiến trúc **Kiosk Sentinel v2** với lớp nhận quyền quản trị cao nhất `DeviceOwner`:
- Lớp `AirGapDeviceAdminReceiver` kế thừa từ `DeviceAdminReceiver` của Android.
- Các chính sách cưỡng chế được kích hoạt tự động khi cấp quyền Device Owner qua lệnh ADB:
  - `addUserRestriction(admin, DISALLOW_CONFIG_WIFI)`: Cấm hoàn toàn việc quét, kết nối hoặc cấu hình mạng Wi-Fi.
  - `addUserRestriction(admin, DISALLOW_CONFIG_BLUETOOTH)`: Cấm kích hoạt và ghép nối thiết bị Bluetooth.
  - `addUserRestriction(admin, DISALLOW_USB_FILE_TRANSFER)`: Vô hiệu hóa giao thức MTP/PTP truyền tệp qua cáp USB, chỉ cho phép dòng điện sạc đi qua cáp.
  - `setGlobalSetting(admin, Settings.Global.AIRPLANE_MODE_ON, "1")`: Cưỡng chế bật chế độ máy bay và cấm người dùng tắt trong phần Cài đặt nhanh.
  - `startLockTask()`: Ghim ứng dụng cố định trên màn hình, vô hiệu hóa phím Home, Recent Apps, và thanh trạng thái kéo xuống từ trên.

### 6.3. Giám sát Kết nối Liên tục & Màn hình Đỏ Phong tỏa Khẩn cấp (Lockdown Screen)
Song song với chính sách cấp hệ điều hành, trong tầng mã nguồn Dart (`security_service.dart`), một dịch vụ giám sát thường trực liên tục theo dõi trạng thái phần cứng:
- Theo dõi các sự kiện thay đổi kết nối mạng qua `Connectivity().onConnectivityChanged`.
- Nếu phát hiện bất kỳ giao diện nào (Wi-Fi, Bluetooth, Mobile Data) được kích hoạt hoặc Chế độ máy bay bị tắt:
  1. Giao diện lập tức bị bao phủ bởi **Màn hình Đỏ Phong tỏa Khẩn cấp (Emergency Lockdown Screen)** với cảnh báo vi phạm Air-Gap.
  2. Toàn bộ khóa riêng tư và cụm từ Mnemonic đang nằm trên bộ nhớ RAM bị kích hoạt cơ chế xóa sạch (`Zeroize`).
  3. Mọi tính năng tạo ví, mở khóa ví hoặc ký duyệt giao dịch bị vô hiệu hóa hoàn toàn cho đến khi môi trường ngoại tuyến tuyệt đối được tái lập.

### 6.4. Cơ chế Quản trị Mã PIN 6 Chữ số, Khóa Tạm thời & Xóa Dữ liệu Tự động
Để bảo vệ quyền truy cập vật lý:
- Người dùng bắt buộc phải thiết lập **Mã PIN 6 chữ số** trong lần đầu khởi tạo thiết bị.
- Mã PIN được băm một chiều với Salt ngẫu nhiên bằng thuật toán PBKDF2-HMAC-SHA256 (10,000 vòng lặp) và lưu trong `FlutterSecureStorage` (được bảo vệ bởi phần cứng Android Keystore).
- **Chống tấn công Brute-Force vật lý:**
  - Nhập sai liên tiếp 3 lần: Khóa tạm thời 30 giây.
  - Nhập sai liên tiếp 5 lần: Khóa tạm thời 5 phút.
  - Nhập sai liên tiếp 10 lần: Tự động kích hoạt cơ chế **Tự Hủy Dữ Liệu (Self-Destruct Wipe)**, xóa toàn bộ cơ sở dữ liệu khóa bí mật và đưa thiết bị về trạng thái xuất xưởng.

### 6.5. Tính năng Ví Ẩn BIP-39 Passphrase Chạy Hoàn Toàn Trên RAM
Để chống lại các kịch bản bị cưỡng ép cung cấp mã PIN (Duress Attack):
- Hệ thống hỗ trợ tính năng **Ví Ẩn (Hidden Wallet / Plausible Deniability)** thông qua cụm từ mật khẩu BIP-39 Passphrase (hay còn gọi là từ thứ 25).
- Khi mở khóa, người dùng có thể tùy chọn nhập thêm Passphrase.
- **Bảo Mật Tối Thượng:** Cụm từ Passphrase và các khóa phái sinh từ Passphrase **CHỈ TỒN TẠI TẠM THỜI TRÊN BỘ NHỚ RAM**, tuyệt đối không bao giờ được ghi xuống bộ nhớ lưu trữ bền vững (Flash/SSD).
- Khi người dùng thoát ứng dụng, khóa màn hình hoặc chuyển ví, vùng nhớ chứa Passphrase được ghi đè `0x00` ngay lập tức.
- **Nhận diện Thị giác:** Khi đang hoạt động trong phiên làm việc Ví Ẩn, toàn bộ thanh tiêu đề và các nút bấm chính chuyển sang **Tone Tím Thạch Anh Amethyst (`#7E22CE`)** giúp người dùng phân biệt rõ ràng với phiên làm việc Ví Chính.

### 6.6. Bảng Điều khiển Kiểm toán Air-Gap (Air-Gap Audit Dashboard)
Ứng dụng cung cấp màn hình kiểm toán chuyên dụng cho phép người dùng và kiểm toán viên an ninh kiểm tra trực quan trạng thái của từng lớp phòng vệ phần cứng:
- Trạng thái Chế độ máy bay (Airplane Mode): Bắt buộc `BẬT`.
- Trạng thái Wi-Fi: Bắt buộc `TẮT VÀ BỊ CẤM`.
- Trạng thái Bluetooth: Bắt buộc `TẮT VÀ BỊ CẤM`.
- Trạng thái Dữ liệu di động (SIM Data): Bắt buộc `TẮT VÀ BỊ CẤM`.
- Trạng thái Kiosk Device Owner: Hiển thị trạng thái gán quyền ADB cấp doanh nghiệp.
- Cho phép người quản trị thoát Kiosk tạm thời (`Admin Exit`) bằng cách nhập mã PIN để bảo trì hệ thống mà vẫn giữ nguyên 100% các chính sách khóa vô tuyến.

### 6.7. Ký Giao dịch Ngoại tuyến & Tự Xác minh Chữ ký FIPS 140-3
Quy trình ký giao dịch được thực thi hoàn toàn trong môi trường cô lập:
1. Tính mã băm giao dịch Transaction Body Hash bằng thuật toán Blake2b-256:
   $$\text{TxHash} = \text{Blake2b-256}(\text{TransactionBodyBytes})$$
2. Ký Ed25519 bằng khóa riêng tư phái sinh:
   $$\text{Signature} = \text{Ed25519-Sign}(\text{PrivateKey}_{\text{payment}}, \text{TxHash})$$
3. **Tự Kiểm Tra Mật Mã FIPS 140-3 (Cryptographic Self-Verification):**
   Ngay trước khi xuất chữ ký ra ngoài giao diện, hàm native `cardano_core_verify_signed_tx` tiến hành xác minh toán học chữ ký vừa tạo trực tiếp trên bộ nhớ:
   $$\text{Verify}(\text{PublicKey}_{\text{payment}}, \text{TxHash}, \text{Signature}) \stackrel{?}{=} \text{True}$$
   Nếu việc tự xác minh thất bại (dấu hiệu của tấn công tiêm lỗi phần cứng - Fault Injection Attack), hệ thống hủy bỏ toàn bộ kết quả, tẩy xóa RAM và khóa giao diện.

---

## PHẦN 7: ĐẶC TẢ CHI TIẾT ỨNG DỤNG VÍ NÓNG TRỰC TUYẾN & WEB PWA (`mobile_online`)

```mermaid
flowchart TD
    subgraph HotWalletClients["Khách Thể Ứng Dụng Ví Nóng (mobile_online)"]
        HotMobile["Ứng Dụng Di Động Android APK"]
        HotWeb["Ứng Dụng Web PWA GitHub Pages (iOS / Android / PC)"]
    end

    subgraph CoreServices["Dịch Vụ Ví Nóng Cốt Lõi"]
        XpubStore["Lưu Trữ Khóa Công Khai XPUB (Watch-Only Vault)"]
        BlockfrostGateway["Blockfrost API Client (Đa Môi Trường Mạng)"]
        TxEngine["Động Cơ Lập Giao Dịch Conway (TxBuilder)"]
        QrScanner["Camera Live Scanner (Quét Mã QR Từ Ví Lạnh)"]
    end

    subgraph BlockchainSync["Đồng Bộ Mạng Lưới Blockchain Cardano"]
        BlockfrostGateway <--> PreprodAPI["cardano-preprod.blockfrost.io"]
        BlockfrostGateway <--> PreviewAPI["cardano-preview.blockfrost.io"]
        BlockfrostGateway <--> MainnetAPI["cardano-mainnet.blockfrost.io"]
    end

    HotMobile & HotWeb --> CoreServices
    XpubStore --> TxEngine
    BlockfrostGateway --> TxEngine
    TxEngine --> UnsignedQR["Hiển Thị Mã QR Giao Dịch Chưa Ký"]
    QrScanner --> BroadcastTx["Ghép Chữ Ký & Phát Sóng Lên Cardano Node"]
```

### 7.1. Kiến trúc Ví Quan sát Không Khóa Riêng (Watch-Only Vault)
Ứng dụng Ví Nóng `mobile_online` được xây dựng theo kiến trúc **Watch-Only thuần túy**:
- Cơ sở dữ liệu của Ví Nóng **hoàn toàn không chứa cụm từ Mnemonic hay Khóa riêng tư (Private Keys)**.
- Ví Nóng chỉ nhập và quản lý chuỗi Khóa công khai mở rộng tài khoản (`Account XPUB Hex`) được quét từ màn hình Ví Lạnh.
- Nhờ Khóa XPUB, Ví Nóng có thể:
  - Tự động dẫn xuất danh sách địa chỉ nhận tiền công khai (`addr1...` / `addr_test1...`).
  - Truy vấn số dư ADA và các tài sản Native Tokens, NFT từ mạng lưới blockchain.
  - Theo dõi lịch sử giao dịch và trạng thái các UTxO có thể chi tiêu.
  - Xây dựng giao dịch nhị phân hoàn chỉnh chưa ký (Unsigned Conway CBOR Tx).

### 7.2. Xuất bản Ứng dụng Web PWA trên GitHub Pages cho iOS & Android
Để mang lại sự tiện lợi tối đa cho người dùng trên mọi hệ điều hành (đặc biệt là người dùng iPhone / iPad không thể cài đặt tệp APK):
- Ứng dụng Ví Nóng được đóng gói và xuất bản chính thức dưới dạng **Web Progressive Web App (PWA CanvasKit)** tại địa chỉ:
  **[https://sonvu91.github.io/antigravity-project/](https://sonvu91.github.io/antigravity-project/)**
- **Tính năng Web PWA:**
  - Hoạt động trực tiếp trên trình duyệt di động Safari (iOS) và Google Chrome (Android).
  - Tích hợp chuẩn giao diện Responsive thích ứng với mọi kích thước màn hình từ điện thoại đến máy tính để bàn.
  - Người dùng có thể chọn *"Thêm vào Màn hình chính (Add to Home Screen)"* để sử dụng như một ứng dụng gốc độc lập.
  - Tích hợp công nghệ Camera Web Scanner thông qua API trình duyệt chuẩn `navigator.mediaDevices.getUserMedia`, cho phép quét trực tiếp mã QR trên màn hình Ví Lạnh từ camera điện thoại.

### 7.3. Bộ Tích hợp Blockfrost API & Bộ đệm UTxO Thông minh
Ví Nóng tích hợp trực tiếp với dịch vụ cổng kết nối **Blockfrost API**:
- **Hỗ trợ 3 Endpoint Mạng Riêng Biệt:** Tự động chuyển đổi URL cơ sở (`baseUrl`) và API Key tương ứng với mạng được người dùng lựa chọn:
  - Mainnet: `https://cardano-mainnet.blockfrost.io/api/v0`
  - Preprod: `https://cardano-preprod.blockfrost.io/api/v0`
  - Preview: `https://cardano-preview.blockfrost.io/api/v0`
- **Bộ đệm UTxO & Đồng bộ Thông minh:**
  - Lấy danh sách UTxO có thể chi tiêu của địa chỉ thanh toán.
  - Tự động phân loại tài sản pure ADA và tài sản chứa Native Tokens/NFT.
  - Tự động truy vấn thông tin metadata của Token (CIP-0025, CIP-0068) để hiển thị tên, biểu tượng, số chữ số thập phân (Decimals).

### 7.4. Động cơ Lập Giao dịch Ngoại tuyến: Chuyển ADA, Token, Quản trị Conway & Staking
Động cơ lập giao dịch trong Ví Nóng hỗ trợ đầy đủ các loại hình giao dịch trong kỷ nguyên Conway:
1. **Giao dịch Chuyển ADA & Native Tokens:**
   - Thuật toán chọn Coin (Coin Selection Algorithm) tối ưu hóa số lượng UTxO đầu vào nhằm giảm thiểu phí mạng.
   - Tự động tính toán lượng ADA tối thiểu bắt buộc đi kèm theo Token (Min-UTxO Value theo quy định của Cardano Ledger).
   - Tự động gán địa chỉ nhận tiền thừa là địa chỉ nội bộ (`role = 1`) phái sinh từ XPUB.
2. **Giao dịch Ủy thác Quản trị Conway CIP-1694 (DRep Delegation):**
   - Hỗ trợ ủy quyền cho các DRep đã đăng ký trên mạng hoặc chọn bỏ phiếu trắng `AlwaysAbstain`.
   - Đóng gói chứng chỉ `VoteDelegationCertificate` vào trường Certificate của giao dịch.
3. **Giao dịch Ủy thác Stake Pool & Đăng ký Staking:**
   - Hỗ trợ chọn Stake Pool từ danh sách các Pool đang hoạt động hoặc nhập Pool ID tùy ý.
   - Tự động đóng gói khoản đặt cọc 2 ADA (Deposit) khi đăng ký mới tài khoản stake.
4. **Tính toán Thời gian Hiệu lực (TTL) Theo Thời Gian Thực:**
   - Tính toán slot hiện tại của mạng và cộng thêm thời lượng an toàn 7200 slots (tương đương 2 giờ) để đảm bảo người dùng có đủ thời gian quét mã và ký duyệt trên Ví Lạnh.

### 7.5. Camera QR Scanner Tương thích Đa nền tảng (Web HTML5 Video & Mobile Camera)
Module quét mã QR được thiết kế tối ưu hóa độ nhạy và tốc độ nhận diện:
- Trên Mobile Native (Android): Sử dụng thư viện `mobile_scanner` tận dụng Google ML Kit Barcode Scanning cho tốc độ nhận diện dưới 50ms.
- Trên Web PWA (Safari/Chrome): Tự động chuyển hướng sang bộ đọc mã QR HTML5 Video với khung hình quét mượt mà 60 FPS, hỗ trợ tự động căn nét và phóng to.
- Hỗ trợ quét liên tục các chuỗi mã QR động (Animated Multipart QR) để tự động thu thập và ghép nối các mảnh dữ liệu lớn mà không bị gián đoạn.

### 7.6. Động cơ Phát sóng Giao dịch (Transaction Broadcasting) & Xử lý Mã Lỗi Node
Sau khi quét nhận chữ ký từ Ví Lạnh:
- Ví Nóng ghép `Vkeywitness` vào cấu trúc `Transaction` ban đầu để tạo ra chuỗi nhị phân hoàn chỉnh `SignedTransactionHex`.
- Phát sóng trực tiếp lên Cardano Node qua endpoint POST `/tx/submit` của Blockfrost.
- **Hệ thống Xử lý & Thông Dịch Mã Lỗi Node Thông Minh:**
  - `BadInputsUTxO`: Thông báo UTxO đã bị tiêu trước đó, khuyến nghị người dùng nhấn *"Làm Mới Số Dư"* và lập lại giao dịch.
  - `ValueNotConservedUTxO`: Thông báo lỗi mất cân bằng giá trị tài sản đầu vào và đầu ra.
  - `FeeTooSmallUTxO`: Thông báo phí mạng không đủ, tự động điều chỉnh tăng phí dự phòng.
  - `ExpiredUTxO / TTL`: Thông báo giao dịch đã quá thời hạn hiệu lực, hướng dẫn người dùng lập giao dịch mới với TTL mới.
  - `DelegateeStakePoolNotRegisteredDELEG`: Stake Pool chưa đăng ký trên mạng hiện tại.
  - `DelegateeDRepNotRegisteredDELEG`: DRep ID chưa hợp lệ trên mạng hiện tại.

---

## PHẦN 8: GIAO THỨC TRUYỀN TIN QUANG HỌC AIR-GAP THÍCH ỨNG (ADAPTIVE QR PROTOCOL)

```mermaid
flowchart TD
    Payload["Dữ Liệu Nhị Phân Giao Dịch (CBOR Hex)"] --> SizeCheck{"Kích Thước Payload < 500 Bytes?"}

    SizeCheck -- "ĐÚNG (Nhỏ)" --> SingleMode["CHẾ ĐỘ TĨNH: SINGLE QR CODE"]
    SizeCheck -- "SAI (Lớn)" --> MultiMode["CHẾ ĐỘ ĐỘNG: ADAPTIVE MULTIPART QR"]

    SingleMode --> HeaderSingle["Tiền Tố: UR:CARDANO-TX/<cborHex>"]
    SingleMode --> RenderSingle["Hiển Thị Mã QR Tĩnh Duy Nhất"]

    MultiMode --> Compress["Nén Dữ Liệu Bằng Thuật Toán Zlib"]
    Compress --> Chunking["Cắt Mảnh Nhị Phân: Kích Thước Mỗi Mảnh 180 Bytes"]
    Chunking --> FormatChunks["Định Dạng Tiền Tố: UR:CARDANO-TX-Z/<seq>-<total>/<payload>"]
    FormatChunks --> Carousel["Trình Chiếu Hoạt Họa Carousel (Tần Số 250ms/Frame)"]

    RenderSingle & Carousel --> CameraScanner["Camera Quét Đầu Nhận"]
    CameraScanner --> Assemble["Ghép Nối Đầy Đủ Các Mảnh & Giải Nén Zlib"]
    Assemble --> CompleteTx["Khôi Phục Nguyên Vẹn Chuỗi CBOR Giao Dịch"]
```

### 8.1. Mô hình Kênh Truyền Quang học 2 Chiều Không Dây Dẫn
Toàn bộ chu trình trao đổi thông tin giữa Ví Nóng và Ví Lạnh vận hành trên nguyên lý **Kênh Truyền Tin Quang Học Hai Chiều (Bidirectional Optical Channel)**:
- **Chiều đi (Hot $\rightarrow$ Cold):** Truyền tải thông tin giao dịch chưa ký (`Unsigned Tx CBOR`).
- **Chiều về (Cold $\rightarrow$ Hot):** Truyền tải tập chữ ký nhân chứng (`Vkeywitness Set CBOR`) hoặc toàn bộ giao dịch đã ký (`Signed Tx CBOR`).
- Không có bất kỳ tín hiệu điện tử, sóng RF hay trường điện từ nào có khả năng truyền ngược lại từ Ví Lạnh sang Ví Nóng ngoài hình ảnh ánh sáng phát ra từ màn hình.

### 8.2. Tiêu chuẩn Mã hóa Single QR & Nén Zlib UR Multipart QR
Do giới hạn về mật độ điểm ảnh của mã QR và tiêu cự camera điện thoại di động, hệ thống triển khai cơ chế **Thích Ứng Kích Thước (Adaptive Payload Mechanism)**:
1. **Chế độ Single QR (Payload < 500 bytes):**
   - Áp dụng khi giao dịch đơn giản (chuyển ADA thuần túy, ít input/output).
   - Định dạng tiền tố: `UR:CARDANO-TX/<cborHex>`
   - Mã QR được hiển thị tĩnh ở mức sửa lỗi Level M hoặc Level Q giúp camera nhận diện ngay lập tức trong 1 khung hình.
2. **Chế độ Adaptive Multipart Animated QR (Payload $\ge 500$ bytes):**
   - Áp dụng khi giao dịch phức tạp (chứa nhiều UTxO, chuyển nhiều Native Tokens, hoặc mang chứng chỉ quản trị Conway CIP-1694).
   - **Nén Dữ Liệu Zlib:** Chuỗi nhị phân CBOR được nén bằng thuật toán Zlib Deflate giúp giảm kích thước từ 40% đến 65%.
   - Định dạng tiền tố nén: `UR:CARDANO-TX-Z/<seq>-<total>/<chunkHex>`
     - `seq`: Thứ tự của mảnh dữ liệu (bắt đầu từ 1).
     - `total`: Tổng số mảnh dữ liệu cần truyền tải.
     - `chunkHex`: Dữ liệu nhị phân của mảnh đã nén.

### 8.3. Thuật toán Phân mảnh Dữ liệu & Tần số Quét Hoàn hảo (Carousel Display)
- **Kích thước mảnh tối ưu:** Mỗi mảnh dữ liệu được khống chế ở mức **180 bytes**. Mức này tạo ra mã QR có phiên bản Version 6 - 8 (khoảng $45 \times 45$ modules), đây là mật độ điểm ảnh lý tưởng nhất để camera Samsung Galaxy J7 Prime và camera máy tính có thể đọc sắc nét mà không bị nhòe mờ.
- **Tần số chuyển khung hình (FPS):** Bộ trình chiếu chuyển đổi liên tục giữa các mảnh với chu kỳ **250ms mỗi khung hình (4 FPS)**. Tần số này đã được kiểm nghiệm thực tế đạt độ ổn định 100% đối với tốc độ phân tích của camera Google ML Kit.
- Thanh tiến trình hiển thị rõ ràng số mảnh đã quét được (ví dụ: `Đang quét: 3/5 mảnh (60%)`) giúp người dùng căn chỉnh góc camera chuẩn xác.

### 8.4. Kênh Hex CBOR Dự phòng & Kiểm tra Tính Toàn vẹn Checksum
Để đảm bảo khả năng vận hành trong mọi hoàn cảnh (kể cả khi camera bị hỏng vật lý hoặc môi trường thiếu sáng):
- Cả Ví Nóng và Ví Lạnh đều cung cấp kênh dự phòng: **"Dán / Xem Chuỗi Hex CBOR Trực Tiếp"**.
- Mọi chuỗi Hex nhập vào đều được kiểm tra định dạng nghiêm ngặt bằng biểu thức chính quy (`^[0-9a-fA-F]+$`) và giải mã cấu trúc CBOR hợp lệ trước khi chuyển sang các bước xử lý tiếp theo.

---

## PHẦN 9: HỆ THỐNG THIẾT KẾ UI/UX PRO MAX, TRỰC QUAN HÓA & TRẢI NGHIỆM NGƯỜI DÙNG

```text
+-------------------------------------------------------------+
| [=] VÍ NGOẠI TUYẾN - AIR GAPPED          [PREPROD TESTNET]  | <-- Network Badge
+-------------------------------------------------------------+
|                                                             |
|  [ THẺ VÍ CHÍNH ĐANG HOẠT ĐỘNG ]                            |
|  Ví Gốc: Tài Khoản #0 (m/1852'/1815'/0'/0/0)               |
|  Địa chỉ: addr_test1qz4...98xsa [SAO CHÉP]                  |
|  +-------------------------------------------------------+  |
|  |           [ HÌNH ẢNH MÃ QR ĐỊA CHỈ NHẬN ]            |  |
|  +-------------------------------------------------------+  |
|                                                             |
|  [ CÁC NÚT TÁC VỤ CỐT LÕI ]                                 |
|  +---------------------------+ +-------------------------+  |
|  | [📷] QUÉT MÃ KÝ GIAO DỊCH | | [⚙] CÀI ĐẶT & BẢO MẬT   |  |
|  +---------------------------+ +-------------------------+  |
|                                                             |
|  [ THẺ TRẠNG THÁI KIỂM TOÁN AIR-GAP SENTINEL ]             |
|  ● Chế độ máy bay: BẬT  ● Wi-Fi: TẮT  ● Device Owner: HOẠT ĐỘNG  |
+-------------------------------------------------------------+
```

### 9.1. Bộ Nhận diện Thị giác Cyberpunk Dark & Hệ Màu An Ninh Obsidian
Giao diện ứng dụng được thiết kế theo phong cách hiện đại Cyberpunk Dark mang lại cảm giác an tâm, chuyên nghiệp và bảo mật cao cấp:
- **Nền Tối Chủ Đạo (Obsidian Void):** Màu nền đen sâu `#0A0E17` kết hợp với màu thẻ Card `#111827` và `#1F2937` giúp tiết kiệm pin tối đa cho màn hình AMOLED và Super AMOLED (đặc trưng của dòng máy Samsung Galaxy).
- **Màu Điểm Nhấn Công Nghệ (Cyber Blue & Mint):** Màu xanh công nghệ `#00E5FF` và xanh ngọc `#10B981` làm nổi bật các trạng thái an toàn, địa chỉ và mã QR.
- **Độ Tương Phản Đạt Chuẩn WCAG AAA:** Mọi văn bản và nhãn trạng thái đều có tỷ lệ tương phản cao (> 7:1) so với nền, đảm bảo hiển thị rõ ràng dưới điều kiện ánh sáng mạnh ngoài trời.

### 9.2. Phối màu Trực quan Phân định Môi trường Mạng & Trạng thái Ví
Hệ thống sử dụng ngôn ngữ màu sắc nhất quán để phản ánh môi trường mạng tức thì:
- **Cardano Mainnet:** Huy hiệu xanh lục Emerald `#10B981` kèm biểu tượng khiên bảo vệ. Khi hoạt động trên Mainnet, người dùng luôn nhận biết rõ ràng tài sản đang thao tác là tiền thật.
- **Preprod Testnet:** Huy hiệu màu hổ phách Amber `#F59E0B` đại diện cho môi trường kiểm thử ổn định.
- **Preview Testnet:** Huy hiệu màu xanh lam Sapphire `#3B82F6` đại diện cho môi trường tính năng mới.

### 9.3. Giao diện Ví Ẩn Tím Thạch Anh Amethyst (`#7E22CE`)
Khi người dùng mở khóa phiên làm việc Ví Ẩn bằng BIP-39 Passphrase:
- Toàn bộ thanh tiêu đề AppBar, các đường viền Card, nút quét mã QR và huy hiệu trạng thái chuyển đổi đồng bộ sang **Màu Tím Thạch Anh Amethyst (`#7E22CE` / `#9333EA`)**.
- Thẻ thông tin hiển thị rõ nhãn: *"VÍ ẨN (BIP-39 PASSPHRASE - RAM ONLY)"* nhắc nhở người dùng rằng phiên làm việc này sẽ hoàn toàn biến mất sau khi khóa màn hình.

### 9.4. Thiết kế Thẻ Giao dịch Phân cấp (Transaction Verification Card Hierarchy)
Màn hình thẩm định giao dịch `TxVerifyScreen` áp dụng cấu trúc phân cấp thị giác 4 tầng nghiêm ngặt:
1. **Tầng 1 - Cảnh báo Chốt chặn Tối cao (Strict Guards Banner):** Đặt ở vị trí trên cùng; nếu có vi phạm lệch mạng hoặc đánh tráo tiền thừa, banner đỏ khẩn cấp sẽ lập tức xuất hiện bao trùm.
2. **Tầng 2 - Thẻ Người Nhận (Recipient Card):** Hiển thị nổi bật số lượng ADA chuyển đi, địa chỉ người nhận và danh sách các Native Token/NFT đi kèm.
3. **Tầng 3 - Thẻ Tiền Thừa Đã Xác Minh (Verified Change Card):** Thẻ màu xanh ngọc hiển thị địa chỉ tiền thừa kèm huy hiệu bảo mật *"Strict Change Guard: Đã Xác Minh Tuyệt Đối An Toàn"*.
4. **Tầng 4 - Thẻ Chi Tiết Kỹ Thuật (Network Fee, TTL, Governance):** Hiển thị phí mạng, hạn thời gian, các chứng chỉ ủy quyền DRep/Stake Pool dưới dạng bảng thu gọn.

### 9.5. Tối ưu hóa Màn hình Cho Thiết bị 32-bit Kích thước 5.5 Inch (Galaxy J7 Prime)
Màn hình Samsung Galaxy J7 Prime có kích thước 5.5 inch độ phân giải Full HD ($1080 \times 1920$ pixels):
- Toàn bộ các nút bấm và trường nhập liệu có chiều cao tối thiểu 48dp theo tiêu chuẩn tiếp cận Android Accessibility.
- Bố cục danh sách cuộn mượt mà (`ListView` với `BouncingScrollPhysics`), không bị tràn điểm ảnh (Zero Overflow Errors).
- Khung hiển thị mã QR được tính toán kích thước động dựa trên chiều rộng màn hình, đảm bảo mã QR luôn nằm trọn trong vùng quét của camera đối diện.

---

## PHẦN 10: HỆ THỐNG KỊCH BẢN TỰ ĐỘNG HÓA ADB, PROVISIONING VÀ QUẢN TRỊ J7 PRIME

```mermaid
flowchart TD
    UserScript["Người Quản Trị Chạy cai_dat_vi_lanh_j7.bat"] --> DetectADB["Tự Động Nhận Diện ADB Portable (scripts/platform-tools)"]
    DetectADB --> CheckDevice["Kiểm Tra Thiết Bị Qua Cáp USB (adb devices)"]

    CheckDevice -- "Chưa Cắm Cáp" --> HelpScreen["Hướng Dẫn Bật Gỡ Lỗi USB & Thao Tác Trên J7 Prime"]
    CheckDevice -- "Đã Nhận Thiết Bị" --> Menu["MENU QUẢN TRỊ CÀI ĐẶT & CẬP NHẬT"]

    Menu --> Opt1["[1] CÀI MỚI SẠCH SẼ (CLEAN INSTALL)"]
    Menu --> Opt2["[2] CẬP NHẬT AN TOÀN (KEEP DATA)"]
    Menu --> Opt3["[3] GỠ BỎ HOÀN TOÀN (UNINSTALL)"]

    Opt1 --> WipeOld["Gỡ Bỏ Bản Cũ & Xóa Sạch Cache / Mã PIN Cũ"]
    WipeOld --> InstallNew["Cài Đặt APK v2.0.3 Mới Với Toàn Bộ Quyền (-g)"]
    InstallNew --> LaunchNew["Khởi Động Ứng Dụng -> Buộc Tạo Mã PIN 6 Chữ Số Mới"]

    Opt2 --> Reinstall["Cài Đè Với Cờ Reinstall Keep Data: adb install -r -g"]
    Reinstall --> LaunchKeep["Khởi Động Ứng Dụng -> Bảo Toàn 100% Mã PIN & Dữ Liệu Ví"]

    Opt3 --> RemoveDO["Hủy Quyền Quản Trị & Gỡ Sạch Ứng Dụng Khỏi Thiết Bị"]
```

### 10.1. Bộ Kịch bản Quản lý Cài đặt Đa Năng: `cai_dat_vi_lanh_j7.bat` / `.ps1`
Để loại bỏ hoàn toàn các thao tác dòng lệnh phức tạp cho người dùng khi thiết lập ví lạnh trên điện thoại Samsung Galaxy J7 Prime, hệ thống cung cấp bộ kịch bản tự động hóa 1-click chuyên nghiệp:
- `cai_dat_vi_lanh_j7.bat`: Dành cho người dùng Windows thông thường (nhấp đúp chuột để chạy).
- `cai_dat_vi_lanh_j7.ps1`: Phiên bản PowerShell nâng cao tích hợp kiểm tra mã băm SHA-256 trước khi cài đặt.
- Tự động tích hợp bộ công cụ kết nối **ADB Portable** đặt tại thư mục `scripts/platform-tools/adb.exe`, người dùng **không cần phải cài đặt Android Studio hay cấu hình biến môi trường PATH** trên máy tính.

### 10.2. Chế độ 1: Cài Mới Sạch Sẽ (Clean Installation & New PIN Flow)
Được sử dụng khi người dùng lần đầu cài đặt hoặc muốn xóa bỏ hoàn toàn dữ liệu cũ, đặt lại mã PIN mới:
1. Kịch bản thực hiện gỡ cài đặt sạch sẽ bản cũ: `adb uninstall com.cardano.coldwallet`.
2. Xóa toàn bộ bộ nhớ ứng dụng và phân vùng lưu trữ an toàn cũ.
3. Cài đặt bản phát hành APK v2.0.3 với cờ tự động cấp quyền: `adb install -g cardano-cold-wallet-v2.0.3-armv7.apk`.
4. Tự động khởi chạy ứng dụng: Khi mở ra, ứng dụng nhận biết trạng thái cài mới sạch và đưa người dùng trực tiếp vào quy trình **Thiết lập Mã PIN 6 chữ số mới** mà không bao giờ bị kẹt lại mã PIN cũ.

### 10.3. Chế độ 2: Cập Nhật An Toàn (Reinstall Keep Data Mode `-r`)
Được sử dụng khi người dùng nâng cấp từ các phiên bản cũ (như v2.0.1, v2.0.2) lên phiên bản v2.0.3:
1. Kịch bản sử dụng cờ cập nhật an toàn của Android Package Manager:
   ```cmd
   adb install -r -g output\v2.0.3\apk\cardano-cold-wallet-v2.0.3-armv7.apk
   ```
2. Cờ `-r` (`INSTALL_REPLACE_EXISTING`) chỉ thay thế mã máy nhị phân của ứng dụng, **bảo toàn nguyên vẹn 100% phân vùng lưu trữ khóa mã hóa trong Android Keystore và mã PIN đã thiết lập**.
3. Người dùng mở ứng dụng và đăng nhập bình thường bằng mã PIN hiện tại, toàn bộ các ví đang quản lý được giữ nguyên vẹn.

### 10.4. Tự động Nhận diện Thiết bị ADB Portable & Cấp Quyền Runtime
Kịch bản tự động dò tìm công cụ ADB theo 4 mức ưu tiên:
1. Thư mục cục bộ dự án: `scripts\platform-tools\adb.exe`
2. Thư mục platform-tools gốc
3. Thư mục cài đặt Android SDK của người dùng: `%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe`
4. Công cụ ADB toàn cục trong biến môi trường hệ thống.
Tự động khởi động ADB Server và hiển thị hướng dẫn chi tiết từng bước bật Gỡ lỗi USB trên giao diện Samsung TouchWiz / One UI của Galaxy J7 Prime.

### 10.5. Kịch bản Kiosk Provisioning & Thiết lập Chính sách Device Owner Doanh nghiệp
Đối với các thiết bị xuất xưởng chuyên dụng, kịch bản `scripts/provision_kiosk.bat` tự động gán quyền quản trị cao nhất:
```cmd
adb shell dpm set-device-owner com.cardano.coldwallet/.AirGapDeviceAdminReceiver
```
Sau khi lệnh được thực thi thành công, ứng dụng Ví Lạnh trở thành chủ sở hữu thiết bị (Device Owner), toàn bộ các chính sách khóa phần cứng Kiosk Sentinel được kích hoạt vĩnh viễn.

---

## PHẦN 11: MA TRẬN ĐE DỌA AN NINH, PHÂN TÍCH LỖ HỔNG & GIẢI PHÁP PHÒNG VỆ

### 11.1. Ma trận Phân tích Đe dọa Mô hình STRIDE
Hệ thống được phân tích và đánh giá an ninh toàn diện theo mô hình chuẩn **STRIDE**:

| Danh Mục Đe Dọa | Kịch Bản Tấn Công Tiềm Ẩn | Mức Độ Rủi Ro | Giải Pháp Phòng Vệ Trong Kiến Trúc v2.0.3 | Trạng Thái |
| :--- | :--- | :--- | :--- | :--- |
| **Spoofing** (Giả mạo danh tính) | Kẻ tấn công tạo mã QR giả mạo địa chỉ ví nhận hoặc giả mạo chữ ký | Cao (High) | Xác thực mã băm Blake2b-256 của toàn bộ Transaction Body và đối soát chữ ký Ed25519 tại chỗ. | ✅ Đã Triệt Tiêu |
| **Tampering** (Can thiệp dữ liệu) | Mã độc trên Ví Nóng thay đổi địa chỉ tiền thừa sang địa chỉ của hacker (Change Hijacking) | Rất Cao (Critical) | **Strict Change Guard**: Tự động so khớp Stake Credential và quét 51 địa chỉ nội bộ; khóa chết ký duyệt nếu sai lệch. | ✅ Đã Triệt Tiêu |
| **Repudiation** (Chối bỏ trách nhiệm) | Người dùng hoặc ứng dụng chối bỏ việc đã phê duyệt giao dịch | Thấp (Low) | Mọi giao dịch ký xong đều xuất tập nhân chứng Vkeywitness chứa chữ ký mật mã không thể làm giả. | ✅ Đã Triệt Tiêu |
| **Information Disclosure** (Rò rỉ thông tin) | Đọc trộm bộ nhớ RAM hoặc trích xuất khóa riêng qua kết nối không dây | Rất Cao (Critical) | **Zero Internet + Deep Memory Zeroization**: Không cấp quyền Internet; tẩy sạch RAM C-Heap và Rust Heap về `0x00`. | ✅ Đã Triệt Tiêu |
| **Denial of Service** (Từ chối dịch vụ) | Gửi chuỗi CBOR rác hoặc payload khổng lồ làm sập ứng dụng Ví Lạnh | Trung bình (Medium) | Bộ giải mã CBOR giới hạn độ sâu đệ quy và độ dài buffer; tự động bắt lỗi cú pháp an toàn (Fail-Closed). | ✅ Đã Triệt Tiêu |
| **Elevation of Privilege** (Leo thang đặc quyền) | Ứng dụng độc hại khác trên máy cố gắng chiếm quyền điều khiển ví | Cao (High) | Cưỡng chế **Device Owner Kiosk Mode**, vô hiệu hóa cài đặt ứng dụng ngoài và khóa chặt màn hình. | ✅ Đã Triệt Tiêu |

### 11.2. Phòng vệ Tấn công Tiêm Lỗi Phần cứng (Fault Injection Attack)
- **Cơ chế Tấn công:** Kẻ tấn công sử dụng tia laser hoặc biến động điện áp xung nhằm làm sai lệch phép tính nhân đường cong elliptic Ed25519 trong lúc ký, từ đó khôi phục khóa riêng tư qua thuật toán phân tích sai lỗi vi sai (DFA).
- **Phòng vệ FIPS 140-3:** Ngay sau khi tính toán chữ ký Ed25519 và trước khi trả dữ liệu về bộ nhớ ứng dụng, hàm native thực hiện phép kiểm tra toán học ngược:
  $$\text{Verify}(\text{PublicKey}, \text{TxHash}, \text{Signature}) == \text{True}$$
  Nếu kết quả xác minh không hợp lệ, hệ thống lập tức xóa sạch dữ liệu và treo tiến trình (Halt Execution) để ngăn chặn kẻ tấn công thu thập dữ liệu chữ ký lỗi.

### 11.3. Phòng vệ Tấn công Side-Channel & Trích xuất Bộ nhớ RAM
- Phép biến đổi khóa PBKDF2 được cố định thời gian tính toán.
- Áp dụng các thư viện mật mã chống tấn công kênh kề qua đo đạc thời gian (Constant-Time Operations).
- Bộ nhớ nhạy cảm được cô lập trong vùng nhớ không thể tráo đổi ra phân vùng swap disk.

### 11.4. Phòng vệ Tấn công Man-in-the-Middle (MitM) & Giả mạo Mã QR
- Kênh truyền quang học đòi hỏi tiếp xúc vật lý tầm gần (Line-of-Sight). Kẻ tấn công từ xa không thể can thiệp vào luồng ánh sáng giữa màn hình và camera.
- Các chuỗi QR động được đóng gói kèm số thứ tự mảnh và tổng số mảnh; mọi sự xáo trộn hoặc thiếu sót mảnh đều bị bộ ghép nối từ chối.

### 11.5. Cơ chế Tự Hủy Dữ liệu Khẩn cấp (Emergency Wipe Out)
- Trong trường hợp thiết bị rơi vào tay kẻ xấu hoặc người dùng bị cưỡng ép nhập mã PIN:
  - Nếu nhập sai mã PIN quá 10 lần, cơ chế tự hủy xóa sạch các khóa trong `FlutterSecureStorage`.
  - Trong cài đặt ứng dụng cung cấp nút **"Xóa Sạch Dữ Liệu Ví Lạnh"** yêu cầu xác nhận 2 lần để người dùng chủ động xóa sổ toàn bộ dữ liệu chỉ trong 1 giây.

---

## PHẦN 12: TIÊU CHUẨN NGHIỆM THU, BỘ KIỂM THỬ E2E 18 KỊCH BẢN & DANH MỤC ĐÓNG GÓI v2.0.3

```mermaid
pie title Kết Quả 18 Kịch Bản Kiểm Thử E2E Toàn Diện (Tỷ Lệ Đạt 100%)
    "Sinh Khóa & Mnemonic BIP-39" : 3
    "Strict Change Guard & Chống Hijacking" : 4
    "Strict Network Guard & Multi-Network" : 3
    "Bóc Tách Conway CBOR & Anti-Blind" : 3
    "FIPS 140-3 & Deep Memory Zeroize" : 2
    "Adaptive Multipart Animated QR" : 2
    "Kiosk Sentinel & Device Owner" : 1
```

### 12.1. Bộ Kiểm thử Đầu-Cuối Tự Động Hóa 18 Kịch bản (`test_e2e_verification.ps1`)
Hệ thống tích hợp bộ kịch bản kiểm thử tự động hóa E2E toàn diện gồm 18 bài kiểm tra chuyên sâu, có thể kích hoạt nhanh bằng lệnh:
```powershell
.\run_tests.ps1
```

Danh mục 18 kịch bản kiểm thử nghiệm thu:
1. `TEST_CORE_01`: Sinh Mnemonic 24 từ ngẫu nhiên hợp lệ theo chuẩn BIP-39 CSPRNG.
2. `TEST_CORE_02`: Kiểm tra tính hợp lệ và phát hiện lỗi từ điển / checksum sai trong chuỗi Mnemonic.
3. `TEST_CORE_03`: Dẫn xuất khóa phân cấp CIP-1852 và sinh địa chỉ Payment, Stake, XPUB chuẩn xác.
4. `TEST_CORE_04`: Kiểm tra cơ chế phái sinh kép: BIP-39 Seed mặc định và tùy chọn CIP-0003 Icarus.
5. `TEST_PARSER_05`: Giải mã nhị phân CBOR giao dịch Conway phức tạp (Inputs, Outputs, Fee, TTL).
6. `TEST_PARSER_06`: Bóc tách chứng chỉ quản trị Conway CIP-1694 (Ủy thác DRep và bỏ phiếu).
7. `TEST_PARSER_07`: Bóc tách giao dịch chứa Native Multi-Asset và hiển thị tên Token dạng UTF-8.
8. `TEST_PARSER_08`: Bóc tách giao dịch rút thưởng Staking (Withdrawals) và yêu cầu ký kép.
9. `TEST_GUARD_09`: Xác minh thuật toán Strict Change Guard nhận diện chính xác địa chỉ tiền thừa hợp lệ.
10. `TEST_GUARD_10`: Báo động đỏ và chặn đứng giao dịch khi địa chỉ tiền thừa bị đánh tráo Stake Credential.
11. `TEST_GUARD_11`: Quét đa điểm không gian 51 địa chỉ nội bộ (`role = 1`) và phát hiện chỉ số index.
12. `TEST_GUARD_12`: Kích hoạt cảnh báo an toàn đối với giao dịch rút cạn ví 1-Output.
13. `TEST_NET_13`: Kiểm tra tính năng Dynamic Derivation tái tính toán địa chỉ `addr1` $\leftrightarrow$ `addr_test1`.
14. `TEST_NET_14`: Strict Network Guard khóa nút ký khi quét giao dịch Testnet trên chế độ Mainnet.
15. `TEST_CRYPTO_15`: Tự động xác minh chữ ký Ed25519 in-memory theo tiêu chuẩn FIPS 140-3.
16. `TEST_MEM_16`: Xác minh cơ chế Deep Memory Zeroization tẩy sạch RAM C-Heap về `0x00`.
17. `TEST_QR_17`: Kiểm tra tính năng nén Zlib và phân mảnh Adaptive Animated Multipart QR.
18. `TEST_KIOSK_18`: Kiểm tra trạng thái Kiosk Sentinel và cơ chế phát hiện vi phạm Air-Gap.

### 12.2. Kiểm thử Tương thích Đa Mạng & Chuyển đổi Mạng Nóng/Lạnh
Bộ kiểm thử đơn vị tự động hóa trong `mobile_cold/test/cold_network_switching_test.dart` đảm bảo:
- Khi chuyển đổi qua lại giữa Mainnet, Preprod, Preview, trạng thái ví được cập nhật nhất quán 100%.
- Không xảy ra tình trạng rò rỉ bộ nhớ hoặc lỗi vòng đời Riverpod Ref (`setState after dispose`).

### 12.3. Quy trình CI/CD Build Tự động trên GitHub Actions
Quy trình xây dựng đóng gói tự động được cấu hình trong `.github/workflows/build-apk.yml`:
1. Kiểm tra mã nguồn, chạy linter Dart và phân tích bảo mật Rust.
2. Biên dịch thư viện lõi Rust cho Linux, Windows và Android NDK.
3. Đóng gói ứng dụng Ví Lạnh Flutter thành các phiên bản APK: Universal, ARMv7 (32-bit), và ARM64 (64-bit).
4. Đóng gói ứng dụng Ví Nóng Flutter thành APK và xuất bản bản Web PWA lên GitHub Pages.
5. Tự động tính toán bảng mã băm `SHA256SUMS` và xuất xưởng vào thư mục phát hành.

### 12.4. Danh mục Đóng gói Phát hành Thư mục `/output/v2.0.3/`
Toàn bộ các gói sản phẩm hoàn thiện của phiên bản v2.0.3 được lưu trữ tại `output/v2.0.3/`:

```text
output/v2.0.3/
├── apk/
│   ├── cardano-cold-wallet-v2.0.3-armv7.apk      # Bản rút gọn tối ưu cho Samsung J7 Prime & 32-bit (10.0 MB)
│   ├── cardano-cold-wallet-v2.0.3-arm64.apk      # Bản rút gọn tối ưu cho máy Android 64-bit (11.7 MB)
│   ├── cardano-cold-wallet-v2.0.3-universal.apk  # Bản Universal tương thích mọi thiết bị Android (32.2 MB)
│   ├── cardano-cold-wallet-v2.0.3.apk            # Bản phát hành chính thức chuẩn cho Ví Lạnh (32.2 MB)
│   ├── cardano-hot-wallet-v2.0.3-armv7.apk       # Bản Ví Nóng Android 32-bit (10.6 MB)
│   ├── cardano-hot-wallet-v2.0.3-arm64.apk       # Bản Ví Nóng Android 64-bit (12.3 MB)
│   ├── cardano-hot-wallet-v2.0.3-universal.apk   # Bản Ví Nóng Android Universal (32.8 MB)
│   └── cardano-hot-wallet-v2.0.3.apk             # Bản phát hành chính thức chuẩn cho Ví Nóng (32.8 MB)
├── cardano-hot-wallet-web-v2.0.3.zip             # Gói nén Web PWA đóng gói đầy đủ (7.8 MB)
├── RELEASE_NOTES_v2.0.3.md                       # Bản ghi chi tiết các điểm mới của bản phát hành
└── SHA256SUMS-v2.0.3.txt                         # Bảng mã băm SHA-256 xác minh tính toàn vẹn
```

### 12.5. Bảng Mã Băm SHA-256 Checksums Xác minh Tính Toàn vẹn
Bảng mã băm SHA-256 chính thức của các bản build release v2.0.3:

```text
8e250fe0881bc0c84c6e93eb2e4c8bc4656ecf81d1ba0784ad70404414efebdb  apk/cardano-cold-wallet-v2.0.3-arm64.apk
b7bb70974864c3c3a9f0f9715c9f5383dd1157945d8b7b250ec405a183d2a76f  apk/cardano-cold-wallet-v2.0.3-armv7.apk
b9a89d380ca175a228fb5dc504eb22442d815779075775fba18ba4d5d36e788c  apk/cardano-cold-wallet-v2.0.3-universal.apk
b9a89d380ca175a228fb5dc504eb22442d815779075775fba18ba4d5d36e788c  apk/cardano-cold-wallet-v2.0.3.apk
bfa0b43534a78103328eb8e0340b6e927c92b23a73c1d9f826353d93708eeb4a  apk/cardano-hot-wallet-v2.0.3-arm64.apk
7c728e24449842a275e7a9ef332560ce0d65fa5064f2e96d9962a98f79f22589  apk/cardano-hot-wallet-v2.0.3-armv7.apk
a3ef561fae4e137f8d68407cebe9f63cf9c98ef73289053915bc5c6d3bc01b54  apk/cardano-hot-wallet-v2.0.3-universal.apk
a3ef561fae4e137f8d68407cebe9f63cf9c98ef73289053915bc5c6d3bc01b54  apk/cardano-hot-wallet-v2.0.3.apk
d07f354ab92b6a83a0eecbc6dbceab457019623821035dc64972d001648bc704  cardano-hot-wallet-web-v2.0.3.zip
```

### 12.6. Quy trình Vận hành Tiêu chuẩn Hằng ngày (Standard Operating Procedure - SOP)
Để đảm bảo an toàn tuyệt đối cho tài sản lưu trữ trên Ví Lạnh, người dùng cần tuân thủ quy trình vận hành tiêu chuẩn:

1. **Chuẩn Bị Thiết Bị:**
   - Sử dụng chiếc Samsung Galaxy J7 Prime chuyên dụng đã được cài đặt bản APK v2.0.3 và bật chế độ Kiosk Sentinel.
   - Kiểm tra Bảng Kiểm Toán Air-Gap: Xác nhận Chế độ máy bay BẬT, Wi-Fi TẮT, Bluetooth TẮT.
2. **Khởi Tạo Giao Dịch Từ Ví Nóng (Web hoặc Mobile):**
   - Mở Ví Nóng tại [https://sonvu91.github.io/antigravity-project/](https://sonvu91.github.io/antigravity-project/) hoặc ứng dụng trên điện thoại online.
   - Nhập số lượng ADA, địa chỉ người nhận và chọn môi trường mạng phù hợp (Mainnet hoặc Preprod).
   - Nhấn *"Lập Giao Dịch"* và mở màn hình hiển thị mã QR.
3. **Thẩm Định & Ký Duyệt Trên Ví Lạnh:**
   - Mở Ví Lạnh, chọn *"Quét Mã Ký Giao Dịch"*.
   - Hướng camera Ví Lạnh vào màn hình Ví Nóng để quét mã QR giao dịch.
   - Đọc kỹ thông tin trên màn hình:
     - Kiểm tra Network Badge có đúng mạng mong muốn không.
     - Kiểm tra số tiền chuyển và địa chỉ người nhận.
     - Kiểm tra Thẻ Tiền Thừa có huy hiệu *"Change Guard: Đã Xác Minh"* màu xanh hay không.
   - Nếu toàn bộ thông tin chính xác, nhấn *"KÝ DUYỆT GIAO DỊCH"*, nhập mã PIN 6 chữ số.
   - Màn hình Ví Lạnh sẽ hiển thị mã QR chữ ký nhân chứng (`UR:CARDANO-TX`).
4. **Phát Sóng & Hoàn Tất:**
   - Sử dụng camera của Ví Nóng quét lại mã QR chữ ký trên màn hình Ví Lạnh.
   - Ví Nóng tự động phát sóng giao dịch lên blockchain Cardano và hiển thị Transaction Hash thành công.
   - Cất giữ điện thoại Ví Lạnh vào két sắt hoặc nơi an toàn sau khi sử dụng.

---

## PHẦN KẾT LUẬN & CAM KẾT CHẤT LƯỢNG

Tài liệu Đặc tả Kỹ thuật Toàn diện **`tech-document-finalv2.md`** là bản mô tả kiến trúc chuẩn mực và đầy đủ nhất của Hệ thống Ví Kép Cardano Air-Gapped đa nền tảng phiên bản **v2.0.3 Enterprise Gold Master**.

Toàn bộ các phân hệ từ Lõi Mật Mã Kép Rust CML / Pure-Dart, Kiosk Sentinel cưỡng chế phần cứng cấp hệ điều hành Android, thuật toán Strict Change Guard chống đánh tráo tiền thừa, chốt chặn Strict Network Guard chống nhầm lẫn môi trường mạng, giao thức truyền tin quang học thích ứng hai chiều, cho đến giải pháp Ví Nóng Web PWA trên GitHub Pages và bộ kịch bản tự động hóa 1-click cho Samsung Galaxy J7 Prime đã được hiện thực hóa, kiểm thử E2E nghiêm ngặt và đóng gói sẵn sàng cho môi trường sản xuất thực tế.

---
*Tài liệu được biên soạn và bảo chứng bởi Đội ngũ Kỹ sư Kiến trúc Bảo mật Antigravity - Dự án Cardano Air-Gap Vault v2.0.3.*

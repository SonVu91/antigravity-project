# Báo Cáo Kiểm Định An Ninh Toàn Diện v2.0 (Security Audit Report)
**Dự án:** Cardano Air-Gap Dual-Wallet System (Hot & Cold Vault)  
**Phiên bản đánh giá:** v2.0.17  
**Tiêu chuẩn kiểm định:** OWASP Mobile Application Security (MASVS v2.1) & CIS Benchmark  
**Ngày thực hiện:** 24/11/2026  
**Đơn vị thực hiện:** Antigravity Automated Security Audit Core  

---

## 1. Tóm Tắt Tổng Quan (Executive Summary)

Sau đợt khắc phục các lỗ hổng tại phiên bản trước và đồng bộ phát hành bản **v2.0.17**, hệ thống đã trải qua đợt tái kiểm định an ninh chuyên sâu lần thứ hai bao gồm:
- **166/166 bài kiểm thử tự động đạt 100%** (14 Rust Core, 19 Bridge, 71 Cold Wallet, 62 Hot Wallet).
- Quét tĩnh mã nguồn chuyên sâu bằng **Rust Clippy**, **Dart Analyzer**, và đối soát các ranh giới bảo mật (Trust Boundaries).
- Đánh giá kiến trúc mật mã, ranh giới cách ly vật lý ngoại tuyến (Air-Gap Isolation), ranh giới FFI (Dart <-> Rust) và bề mặt tấn công mạng.

### Kết quả đánh giá chung:
- **Trạng thái an ninh tổng thể:** **ĐẠT CẤP ĐỘ AN NINH CAO (HIGH ASSURANCE)**
- Không phát hiện lỗ hổng mức Độ nghiêm trọng Nguy kịch (Critical) hay Cao (High) nào còn tồn tại.
- Toàn bộ 5 trụ cột an ninh cốt lõi đều vận hành fail-closed theo đúng thiết kế bảo vệ tài sản tiền mã hóa.
- Phát hiện **5 khuyến nghị tối ưu hóa an ninh (3 Low, 2 Informational)** nhằm nâng cao tối đa độ bền vững của mã nguồn.

---

## 2. Bảng Ma Trận Đánh Giá Rủi Ro Tiềm Ẩn (CVSS v3.1)

| ID | Vị trí mã nguồn | Phân loại rủi ro | CVSS v3.1 | Mức độ | Trạng thái hiện tại |
| :--- | :--- | :--- | :---: | :---: | :--- |
| **SEC-01** | `rust_cardano_core/src/api.rs` | Con trỏ thô FFI chưa đánh dấu `unsafe` tường minh | 2.5 (Low) | Thấp | Đã có `ptr.is_null()` guard; cần bổ sung hợp đồng con trỏ an toàn |
| **SEC-02** | `cardano_airgap_bridge/lib/src/ffi_bridge_io.dart` | Vòng đời Mnemonic trong bộ nhớ Garbage Collector của Dart | 2.9 (Low) | Thấp | Đã zeroize heap Native; chuỗi Dart String bất biến phụ thuộc chu kỳ GC |
| **SEC-03** | `mobile_online/lib/core/network/` | Lưu trữ API Key Blockfrost trên Web LocalStorage | 3.1 (Low) | Thấp | Đã được bảo vệ bởi CSP nghiêm ngặt; có rủi ro nếu có XSS |
| **SEC-04** | `cardano_airgap_bridge/lib/src/ffi_bridge_web.dart` | Synchronous XMLHttpRequest trong nhánh Fallback Web | 2.0 (Info) | Thông tin | Đã vô hiệu hóa qua `isNativeAvailable = false`; nên loại bỏ hoàn toàn |
| **SEC-05** | `mobile_cold/android/AndroidManifest.xml` | Bề mặt quản trị thiết bị `BIND_DEVICE_ADMIN` | 1.8 (Info) | Thông tin | Giới hạn hệ điều hành Android; lưu ý quy trình gỡ cài đặt trên máy cá nhân |

---

## 3. Đánh Giá Chi Tiết Theo 5 Trụ Cột Bảo Mật Cốt Lõi

```mermaid
flowchart TD
    subgraph ColdVault["🔒 Cold Wallet (Samsung J7 Prime - Air-Gap)"]
        A[Android OS Sandbox: No Internet, allowBackup=false] --> B[SecurityService: PBKDF2 100k + AES-256-GCM]
        B --> C[Rust Core CML: FIPS 140-3 Self-Verify + Volatile Zeroize]
        C --> D[Change Guard: Strict Account xPub Derivation]
    end

    subgraph Channel["📷 Optical Air-Gap Channel"]
        E[Multipart QR Code: Adaptive Zlib + CRC32 Session Checksum + 64KB Bomb Guard]
    end

    subgraph HotVault["🌐 Hot Wallet (Android APK & Web PWA)"]
        F[Watch-Only: Only xPub / Public Addresses, NO Private Keys]
        G[Strict CSP: default-src 'self', script-src 'self' 'wasm-unsafe-eval']
        H[Conway TTL Guard: Network-specific slot calculation]
    end

    D <--> E
    E <--> F
```

---

### Trụ Cột 1: Rust Core & An Toàn Bộ Nhớ FFI (Rust Core & Memory Safety)

#### Điểm mạnh đã được xác nhận:
1. **Volatile Write & Compiler Fence (`secure_zeroize`):**
   Trong `rust_cardano_core/src/lib.rs` (L15-22), các mảng byte khóa trung gian được ghi đè bằng `std::ptr::write_volatile` kèm `compiler_fence(Ordering::SeqCst)`, loại bỏ hoàn toàn việc trình biên dịch tối ưu hóa bỏ qua lệnh xóa bộ nhớ (Dead-store elimination).
2. **FIPS 140-3 Fault Injection Self-Verification:**
   Trong `rust_cardano_core/src/tx_signer.rs` (L212-218 & L236-239), mọi chữ ký Ed25519 tạo ra (cả Payment Key và Stake Key) đều bắt buộc phải tự xác minh lại với khóa công khai trước khi xuất ra. Nếu phát hiện sai lệch (do phần cứng bị tấn công Rowhammer hoặc Glitch), hệ thống lập tức zeroize khóa và chặn đứng việc rò rỉ khóa riêng tư.
3. **Chốt chặn chống tráo mạng (Anti-Cross-Network):**
   Kiểm tra toàn bộ địa chỉ đầu ra (`addr1` vs `addr_test1`) đảm bảo không thể ký nhầm giao dịch Testnet trên mạng Mainnet.

#### Rủi ro tiềm ẩn (SEC-01):
- **Phân tích:** Trong `rust_cardano_core/src/api.rs`, các hàm xuất khẩu C-ABI nhận con trỏ `*const c_char` như:
  ```rust
  #[no_mangle]
  pub extern "C" fn cardano_core_validate_mnemonic(phrase: *const c_char) -> bool
  ```
  Trình phân tích Rust Clippy cảnh báo `not_unsafe_ptr_arg_deref`. Mặc dù hàm trợ giúp `c_char_to_str` đã kiểm tra `ptr.is_null()`, nhưng con trỏ thô có thể trỏ vào vùng nhớ không hợp lệ hoặc thiếu ký tự null kết thúc (`\0`) nếu thư viện gọi bên ngoài gặp lỗi bộ nhớ.
- **Khuyến nghị khắc phục:** Khai báo chuẩn `pub unsafe extern "C" fn` hoặc thêm `#[allow(clippy::not_unsafe_ptr_arg_deref)]` kèm kiểm tra độ dài an toàn tối đa cho chuỗi C-string.

---

### Trụ Cột 2: Mật Mã Học & Chống Kênh Phụ (Cryptographic Rigor & Side-Channels)

#### Điểm mạnh đã được xác nhận:
1. **Constant-Time Edwards Multiplication:**
   Trong `cardano_airgap_bridge/lib/src/cardano_pure.dart` (L216-240), thuật toán nhân điểm `_edwardsMul` đã được chuyển sang vòng lặp cố định 256 bước cho scalar 256-bit của Ed25519. Các phép tính luôn thực hiện đủ cả hai nhánh và dùng phép chọn giá trị không phụ thuộc thời gian, triệt tiêu nguy cơ rò rỉ khóa qua phân tích thời gian thực thi (Timing Attack).
2. **PBKDF2-HMAC-SHA256 100,000 Iterations:**
   Ví Lạnh bảo vệ mã PIN bằng 100.000 vòng băm kèm khóa muối ngẫu nhiên (Salt), kết hợp mã hóa xác thực AES-256-GCM.
3. **Cơ chế khóa chống dò PIN (Brute-Force Lockout):**
   Sau 5 lần nhập sai, hệ thống khóa tạm thời tăng dần theo cấp số nhân (Exponential Backoff), và có tính năng Duress PIN để xóa sạch dữ liệu khẩn cấp.

#### Rủi ro tiềm ẩn (SEC-02):
- **Phân tích:** Trên Dart VM, các đối tượng kiểu `String` (như biến `phrase` lưu cụm từ 24 từ) là bất biến (immutable) và được cấp phát trên heap do bộ gom rác (Garbage Collector) quản lý. Mặc dù vùng nhớ C-Heap của Native FFI đã được `_secureFreeUtf8` ghi đè số `0x00`, bản sao `String` trên Dart chỉ biến mất khi GC thu hồi.
- **Khuyến nghị khắc phục:** Sau khi khởi tạo ví và hiển thị cho người dùng ghi chép, lập tức gán `mnemonic = null` trong `WalletKeysInfo`, khuyến khích lưu giữ cụm từ hạt giống dưới dạng `Uint8List` trong các luồng xử lý nội bộ.

---

### Trụ Cột 3: Giao Thức Air-Gap QR & Chống Tráo Tiền Thừa (Change Guard)

#### Điểm mạnh đã được xác nhận:
1. **Change Guard Chống Tráo Tiền Thừa (Change Address Hijacking):**
   Trong `rust_cardano_core/src/change_guard.rs` và `tx_signer.rs` (L200-205):
   Khi phân tích giao dịch, hệ thống tự động đối chiếu các địa chỉ đầu ra với địa chỉ được dẫn xuất chính thức từ `account_xpub` (tại path `m/1852'/1815'/account'/1/i`). Nếu có địa chỉ tiền thừa giả mạo (không thuộc sở hữu của ví), hệ thống kích hoạt cờ `SECURITY_ALERT_CHANGE_HIJACKING` và **từ chối ký ngay lập tức**.
2. **Bảo vệ chống Decompression Bomb trên QR Code:**
   Trong `cardano_airgap_bridge/lib/src/multipart_qr.dart` (L30-41):
   Khi quét mã QR nén Zlib động, bộ giải nén giới hạn độ dài chuỗi Base64 tối đa 128 KB và dung lượng giải nén tối đa 64 KB. Điều này ngăn chặn kẻ tấn công tạo mã QR chứa dữ liệu nén khổng lồ gây tràn bộ nhớ (Out-Of-Memory Crash) trên điện thoại Samsung J7 Prime.
3. **Session ID & Checksum:**
   Mỗi chuỗi mã QR đa phần (Multipart QR) đều mang CRC-32 Checksum đóng vai trò Session ID, đảm bảo không bị lẫn lộn giữa các phiên quét hoặc bị tấn công ghép frame (Frame Injection).

---

### Trụ Cột 4: Bề Mặt Tấn Công Ví Nóng & An Ninh Mạng (Hot Wallet Attack Surface)

#### Điểm mạnh đã được xác nhận:
1. **Kiến trúc Watch-Only Tuyệt Đối:**
   Ví Nóng (cả bản Web PWA và Android APK) không lưu trữ bất kỳ khóa bí mật nào (Private Key / Seed Phrase), chỉ lưu trữ khóa công khai tài khoản (`account_xpub`) và các địa chỉ nhận tiền. Ngay cả khi thiết bị Ví Nóng bị chiếm quyền điều khiển hoàn toàn, kẻ tấn công cũng không thể đánh cắp tiền.
2. **Chính sách An toàn Nội dung Khắt khe (Strict CSP):**
   Trong `mobile_online/web/index.html` (L15-18):
   ```html
   <meta http-equiv="Content-Security-Policy" content="default-src 'self'; script-src 'self' 'wasm-unsafe-eval'; connect-src 'self' https://cardano-mainnet.blockfrost.io https://cardano-preprod.blockfrost.io https://cardano-preview.blockfrost.io https://api.koios.rest; font-src 'self' data:; style-src 'self' 'unsafe-inline'; img-src 'self' data: blob:;">
   ```
   Chặn đứng mọi nỗ lực tiêm mã JavaScript độc hại (XSS) và ngăn chặn việc gửi dữ liệu ra các máy chủ lạ ngoài Blockfrost/Koios.
3. **Conway Slot TTL Chuẩn Xác:**
   Tính toán thời hạn giao dịch (TTL) dựa trên Slot thực tế theo từng mạng (Mainnet: 4492799, Preprod: 86400, Preview: 0), ngăn chặn giao dịch bị treo vĩnh viễn trong Mempool.

#### Rủi ro tiềm ẩn (SEC-03 & SEC-04):
- **SEC-03:** Khóa API Blockfrost người dùng nhập vào lưu trong `localStorage` (trên trình duyệt) hoặc `SharedPreferences` (trên Android). Mặc dù không phải khóa tiền tệ, nếu người dùng sử dụng máy tính công cộng, khóa API có thể bị sao chép gây hao hụt hạn ngạch (Quota).
- **SEC-04:** Hàm `_post` trong `ffi_bridge_web.dart` sử dụng `HttpRequest` đồng bộ (`async: false`). Mặc dù nhánh này không được chạy trên thực tế do `isNativeAvailable = false`, nhưng nên được dọn dẹp để tránh cảnh báo từ trình duyệt.

---

### Trụ Cột 5: Đóng Băng Hệ Điều Hành & Khả Năng Kháng Tấn Công Vật Lý (Android OS Hardening)

#### Điểm mạnh đã được xác nhận:
1. **Không có quyền Internet (Zero Internet Footprint):**
   Tệp `mobile_cold/android/app/src/main/AndroidManifest.xml` không chứa quyền `android.permission.INTERNET`. Hệ điều hành Android từ chối mọi socket mạng của Ví Lạnh ở cấp độ nhân Linux (Kernel-level enforcement).
2. **Chặn sao lưu qua ADB (`allowBackup="false"`):**
   Ngăn chặn kẻ có quyền truy cập vật lý cắm cáp USB và dùng lệnh `adb backup` để trích xuất dữ liệu ví ra máy tính.
3. **Cách ly thư mục sao lưu cục bộ:**
   Tệp sao lưu mã hóa (`backup.json`) mặc định lưu trong vùng nhớ sandbox riêng tư của ứng dụng (`getApplicationDocumentsDirectory()`), thay vì thư mục công cộng `/sdcard/Download`.

#### Rủi ro tiềm ẩn (SEC-05):
- **Phân tích:** `AirGapDeviceAdminReceiver` yêu cầu quyền `BIND_DEVICE_ADMIN` để hỗ trợ cơ chế Kiosk Lock chặn bật WiFi/Bluetooth. Nếu người dùng cài đặt ứng dụng thử nghiệm trên điện thoại chính (thay vì máy phụ cách ly), việc gỡ ứng dụng sẽ cần vào *Cài đặt > Bảo mật > Quản trị viên thiết bị* để tắt quyền trước.

---

## 4. Bảng Kế Hoạch Khắc Phục Khuyến Nghị (Remediation Roadmap)

| Hạng mục | Giải pháp kỹ thuật | Độ ưu tiên | Mức độ phức tạp |
| :--- | :--- | :---: | :---: |
| **Vá SEC-01 (Rust FFI Pointer)** | Bổ sung `#[allow(clippy::not_unsafe_ptr_arg_deref)]` hoặc chuyển sang `pub unsafe extern "C"` và xác thực độ dài con trỏ | P1 | Rất thấp (10 dòng code) |
| **Vá SEC-02 (Dart Mnemonic Zeroize)** | Xóa bỏ trường `mnemonic` trong `WalletKeysInfo` sau khi hoàn tất màn hình sao lưu | P2 | Thấp |
| **Vá SEC-03 (API Key Web Encryption)** | Mã hóa xPub và API Key trong `localStorage` bằng khóa dẫn xuất từ mật khẩu phiên | P3 | Trung bình |
| **Dọn dẹp SEC-04 (Web Sync XHR)** | Chuyển hoàn toàn `ffi_bridge_web.dart` sang Pure-Dart Stub bất đồng bộ hoặc loại bỏ XHR | P2 | Thấp |
| **Tài liệu hóa SEC-05 (Device Admin Guide)** | Cập nhật hướng dẫn người dùng cách bật/tắt quyền Quản trị viên thiết bị an toàn | P3 | Rất thấp (Tài liệu) |

---

## 5. Kết Luận Kiểm Định

Hệ thống **Cardano Air-Gap Dual-Wallet System v2.0.17** thể hiện độ hoàn thiện an ninh xuất sắc với kiến trúc phân tách ranh giới rõ ràng, không phụ thuộc vào một lớp bảo vệ đơn lẻ (Defense-in-Depth). Toàn bộ các luồng giao dịch nhạy cảm đều được bảo vệ bởi các thuật toán mật mã chuẩn mực, kiểm tra tính toàn vẹn 2 chiều và cơ chế fail-closed chặt chẽ.

Hệ thống sẵn sàng và an toàn cho việc lưu trữ và ký duyệt giao dịch ngoại tuyến trong môi trường sản xuất.

# 🤖 Cardano & Midnight AI Sentinel & Auto-Trader

Hệ thống Bot Trí tuệ Nhân tạo Giám sát & Giao dịch Tự động Đa thị trường cho hệ sinh thái **Cardano (ADA)** và **Midnight Network (NIGHT)**.

---

## 🌟 Tính năng Nổi bật (Phiên bản 2.1 - Tích hợp Fimi Supply & Demand Engine)

1. **Động cơ Phân tích Vùng Cung - Cầu (Supply & Demand Engine):**
   * **Nhận diện 4 mô hình cốt lõi:** Drop-Base-Rally (DBR), Rally-Base-Drop (RBD), Rally-Base-Rally (RBR), Drop-Base-Drop (DBD).
   * **Bộ lọc Vùng Tươi Mới (Fresh vs Tested vs Violated):** Chỉ giữ lại các vùng có lực bứt phá mạnh (Extended Range Candle - ERC) và chưa bị quét thanh khoản.
   * **Tự động bóp chặt Stop-Loss & Tối ưu Take-Profit:** Điểm cắt lỗ ngoài Distal Line (+ đệm ATR), điểm chốt lời tại Proximal Line của Vùng Cung đối diện (R:R tối thiểu 1:2.0).

2. **Tra cứu & Vẽ Biểu đồ Nến Nhật Dark Theme qua Telegram (tương tự FimiSDbot):**
   * **Cú pháp gõ nhanh:** `?<coin>,<quote>,<tf>` (Ví dụ: `?btc,usdt,d1`, `?ada,usdt,h4`, `?night,ada,h4`).
   * **Lệnh Slash:** `/sd <cặp_tiền> [khung_thời_gian]` (Ví dụ: `/sd btc/usdt 1d`, `/sd ada 4h`).
   * **Biểu đồ nến chuyên nghiệp:** Vẽ trực tiếp nến xanh/đỏ, volume bar, các khối hộp bán trong suốt đánh dấu Vùng Cung (Supply) và Vùng Cầu (Demand) kèm mức giá biên và nút bấm đặt lệnh 1-click.

3. **Giám sát Đa thị trường (Multi-Market Data Collector):**
   * **CEX:** Thu thập nến OHLCV (15m, 1h, 4h) và Orderbook của `ADA/USDT` và `NIGHT/USDT` qua thư viện chuẩn hóa CCXT (Binance, OKX, MEXC, Gate.io).
   * **Cardano On-chain:** Quét biến động số dư các ví cá mập ADA (> 500,000 ADA) và dòng tiền token NIGHT qua **Blockfrost API** & **Koios REST**.
   * **Cardano DEX:** Giám sát độ sâu thanh khoản các Liquidity Pool `NIGHT/ADA` và `ADA/USDC` trên **Minswap** & **DexHunter**.
   * **Tin tức & Tâm lý:** Phân tích RSS chính thống (Cardano Foundation, IOHK, Midnight) và CryptoPanic.

2. **Lõi Trí tuệ Nhân tạo Hybrid AI:**
   * **LightGBM Predictor:** Dự đoán xu hướng giá dựa trên chỉ báo kỹ thuật (RSI, MACD, EMA, ATR, Bollinger Bands) kết hợp dữ liệu On-chain.
   * **Cross-Market Lead-Lag Feature for NIGHT:** Tận dụng phản ứng giá tức thời của `NIGHT/USDT` trên CEX làm tín hiệu sớm đón đầu xu hướng trên pool DEX `NIGHT/ADA` (vốn chịu độ trễ khối 20 - 40s của Cardano).
   * **Gemini AI Sentiment:** Tự động chấm điểm cảm xúc tin tức hệ sinh thái từ -1.0 đến +1.0.
   * **Whale Anomaly Detector:** Sử dụng thuật toán `Isolation Forest` phát hiện các đợt gom/xả bất thường.

3. **Mô phỏng Giao dịch Giả lập Chân thực (Realistic Paper Trading):**
   * CEX: Phí Taker thực tế (0.075%) + Trượt giá Orderbook.
   * Cardano DEX: Khấu trừ phí Batcher (2.0 ADA) + Phí mạng lưới (~0.2 ADA) + Độ trễ đóng block 20 - 40 giây + Trượt giá AMM Constant Product $x \cdot y = k$.

4. **Quản trị Rủi ro Nghiêm ngặt (Risk Management):**
   * Tối ưu quy mô vị thế theo công thức Kelly Criterion điều chỉnh (tối đa 1.5% NAV).
   * Stop-Loss & Take-Profit động theo chỉ số biến động ATR.
   * **Circuit Breaker:** Ngắt mạch an toàn tự động nếu Drawdown 24h vượt quá 5%.

5. **Kênh Điều khiển & Cảnh báo Telegram Bot 2 chiều:**
   * Gửi cảnh báo tức thời kèm biểu đồ mini tài chính khi có tín hiệu mạnh hoặc cá mập di chuyển.
   * Bộ lệnh: `/status`, `/pnl`, `/balance`, `/signals`, `/stop_all`.

---

## 🚀 Hướng dẫn Sử dụng & Vận hành

### Cách 1: Chạy 1-Click trên Windows (Đơn giản nhất)
Trong thư mục dự án `E:\Antigravity\3. Bot trade coin\`:
* **Kiểm tra kết nối & chạy thử nghiệm (Demo):** Nhấp đúp vào tệp **`test_bot.bat`**.
* **Khởi chạy Bot hoạt động 24/7:** Nhấp đúp vào tệp **`run_bot.bat`**.

---

### Cách 2: Chạy qua PowerShell / Command Prompt
```powershell
# Di chuyển vào thư mục dự án
cd "E:\Antigravity\3. Bot trade coin"

# Chạy kiểm tra nhanh 2 chu kỳ quét thị trường
.\venv\Scripts\python.exe run_demo.py

# Khởi chạy Bot giám sát & giao dịch giả lập 24/7
.\venv\Scripts\python.exe -m src.main
```

---

### Cách 3: Triển khai bằng Docker Compose (Khuyên dùng cho VPS 24/7)
```bash
docker compose up -d --build
```
Xem log hoạt động của bot:
```bash
docker compose logs -f
```

---

## ⚙️ Hướng dẫn Cấu hình API Keys (Tùy chọn)
Tệp cấu hình được đặt tại `config/.env` (được sao chép từ `config/config.env.example`):
1. **Blockfrost API (On-chain Cardano):**
   * Đăng ký miễn phí tại [blockfrost.io](https://blockfrost.io) tạo Project mạng `Cardano Mainnet`.
   * Điền: `BLOCKFROST_PROJECT_ID=mainnet...`
2. **Gemini API (AI Phân tích tin tức):**
   * Lấy API key miễn phí tại [Google AI Studio](https://aistudio.google.com).
   * Điền: `GEMINI_API_KEY=AIzaSy...`
3. **Telegram Bot (Nhận cảnh báo & Lệnh điều khiển):**
   * Nhắn tin cho `@BotFather` trên Telegram, gõ `/newbot` để tạo bot và nhận `BOT_TOKEN`.
   * Nhắn tin cho `@userinfobot` để lấy `CHAT_ID` của bạn.
   * Điền: `TELEGRAM_BOT_TOKEN=...` và `TELEGRAM_CHAT_ID=...`

*(Lưu ý: Nếu chưa điền API keys, hệ thống tự động kích hoạt chế độ Fallback/Mock thông minh để bạn vẫn có thể kiểm thử mượt mà toàn bộ chức năng).*

---

## 🔒 Quy chuẩn Bảo mật (Security Invariants)
Dự án tuân thủ quy tắc bảo mật của Monorepo:
* Tuyệt đối không commit tệp chứa private key hoặc API key thật lên Git repository.
* Chỉ lưu cấu hình thật trong tệp cục bộ `config/.env` (đã được cấu hình trong `.gitignore`).

# TÀI LIỆU ĐẶC TẢ YÊU CẦU KỸ THUẬT (SRS) - PHIÊN BẢN 2.0
**Tên dự án:** Hệ thống AI Bot Theo dõi & Giao dịch Tự động Hệ sinh thái Cardano & Midnight (Cardano & Midnight AI Sentinel & Auto-Trader)  
**Phiên bản:** 2.0 (Approved Architecture)  
**Ngày cập nhật:** 26/11/2026  
**Trạng thái:** Đã thống nhất thiết kế - Sẵn sàng triển khai (Ready for Development)  

---

## 1. TỔNG QUAN DỰ ÁN (PROJECT OVERVIEW)

### 1.1. Mục tiêu
Xây dựng một hệ thống Bot tự động ứng dụng Trí tuệ nhân tạo (AI/ML) nhằm mục đích:
1. **Theo dõi đa thị trường (Multi-Market Monitoring):** Giám sát thời gian thực biến động giá, thanh khoản, dữ liệu On-chain và tâm lý thị trường đối với:
   * **Cardano (ADA):** Tài sản nền tảng mạng lưới Cardano.
   * **Midnight (NIGHT):** Token tiện ích của mạng lưới partner-chain bảo vệ quyền riêng tư Midnight (Input Output Global).
2. **Phân tích thông minh (AI Hybrid Intelligence):**
   * Sử dụng mô hình Machine Learning bảng (LightGBM/XGBoost) kết hợp chỉ báo kỹ thuật và dữ liệu On-chain để dự đoán xu hướng giá.
   * Khai thác đặc trưng **Độ trễ liên thị trường (Cross-Market Lead-Lag):** Tận dụng phản ứng giá nhanh trên CEX để đón đầu xu hướng trên sàn Cardano DEX vốn có độ trễ khớp nến 20 - 40 giây.
   * Sử dụng mô hình ngôn ngữ lớn (Gemini / OpenAI API) để phân tích cảm xúc tin tức hệ sinh thái Cardano và Midnight.
   * Thuật toán **Isolation Forest** phát hiện dòng tiền bất thường từ các ví cá mập.
3. **Giao dịch giả lập chân thực (High-Fidelity Paper Trading):** Mô phỏng giao dịch chuẩn xác bao gồm trượt giá thực tế, phí sàn CEX, phí giao dịch mạng lưới Cardano, phí Batcher DEX và độ trễ đóng block.
4. **Cảnh báo & Điều khiển 2 chiều (Interactive Control):** Điều khiển khẩn cấp và nhận thông báo biến động, phân tích tín hiệu trực tiếp qua Telegram Bot 24/7.

### 1.2. Danh mục tài sản & Cặp giao dịch mục tiêu
Hệ thống tập trung tối ưu vào 2 đồng coin cốt lõi:
* **Cardano (ADA):**
  * **CEX:** Cặp `ADA/USDT` (Sàn Binance, OKX, Bybit).
  * **Cardano DEX:** Cặp `ADA/USDC`, `iUSD` (Minswap, DexHunter).
* **Midnight Token (NIGHT):**
  * **CEX:** Cặp `NIGHT/USDT` (Các sàn niêm yết thanh khoản cao nhất như Binance, OKX, MEXC qua thư viện CCXT).
  * **Cardano DEX:** Cặp `NIGHT/ADA` (Pool Minswap / DexHunter).

---

## 2. CHẾ ĐỘ HOẠT ĐỘNG VÀ QUY TẮC TRIỂN KHAI

### 2.1. Chế độ vận hành Giai đoạn 1 (Phase 1)
* **Alert-Only Mode:** Gửi tín hiệu phân tích, biến động ví cá mập và cảnh báo chênh lệch giá (Arbitrage Spread) qua Telegram.
* **Paper Trading Mode (Giao dịch giả lập thực tế):**
  * Mọi tín hiệu của AI sẽ được thực thi trên môi trường giả lập hạch toán riêng cho từng cặp.
  * **Tuyệt đối chưa kích hoạt Live Trading bằng tiền thật** cho đến khi hệ thống đạt đầy đủ KPI kiểm thử (tối thiểu 14 ngày, Win-rate > 55%, Sharpe Ratio > 1.5, Max Drawdown < 5%).

### 2.2. Khung thời gian & Phong cách giao dịch
* **Phong cách:** **Swing Trading / Trend Following**.
* **Khung nến chính:** **1h** và **4h** (Xác định cấu trúc sóng và xu hướng dòng tiền).
* **Khung nến phụ xác nhận:** **15m** (Tối ưu hóa điểm vào lệnh - Entry Timing).
* **Lý do lựa chọn:** Khung thời gian 1h/4h giúp triệt tiêu nhiễu ngắn hạn, hoàn toàn tương thích với tốc độ xác nhận giao dịch eUTxO (~20s - 40s) của mạng Cardano, đồng thời giảm thiểu tối đa chi phí phí giao dịch lặp lại.

---

## 3. KIẾN TRÚC HỆ THỐNG (SYSTEM ARCHITECTURE)

Hệ thống được tổ chức theo kiến trúc **Backend thuần Python 3.11+ Module hóa (Modular Architecture)** kết hợp giao tiếp bất đồng bộ (Asyncio + Redis Event Queue):

```text
[Nguồn Dữ Liệu]
  ├── CEX WebSocket/REST (CCXT)  ──> [ADA/USDT, NIGHT/USDT OHLCV & Orderbook]
  ├── Cloud On-chain APIs         ──> [Blockfrost/Koios: UTxO, Cá mập ADA & NIGHT]
  ├── DEX Aggregator API          ──> [DexHunter/Minswap: Pool Res, NIGHT/ADA, ADA/USDC]
  └── News & Social APIs          ──> [RSS IOHK/Cardano, Reddit, CryptoPanic, CoinGecko]
                                         |
                                         v
                            [Data Ingestion Engine] (Python Asyncio)
                                         |
                 +-----------------------+-----------------------+
                 |                                               |
                 v                                               v
        [Local Storage]                                 [Redis Message Bus]
     (SQLite/PostgreSQL)                                         |
                                         +-----------------------+-----------------------+
                                         |                                               |
                                         v                                               v
                             [AI & Analytics Engine]                           [Notification Engine]
                          - LightGBM / XGBoost Model                          - Telegram Interactive Bot
                          - Lead-Lag Feature Extractor                        - Mini Chart Generator
                          - Isolation Forest (Whale Detector)                 - Bi-directional Command Handler
                          - Gemini Sentiment Analyzer
                                         |
                                         v
                             [Risk Management Module]
                          - Dynamic ATR SL/TP
                          - Kelly Criterion Sizing (1-2%)
                          - Circuit Breaker (5% Drawdown)
                                         |
                                         v
                             [Paper Trading Simulator]
                          - CEX Fee (0.075%) & Slippage Sim
                          - Cardano DEX 2-ADA Batcher Fee
                          - Cardano 0.2-ADA Tx Fee Sim
                          - 20-40s Delay & AMM Slippage (x*y=k)
```

---

## 4. CHI TIẾT CÁC PHÂN HỆ CHỨC NĂNG

### 4.1. Phân hệ Thu thập Dữ liệu (Data Ingestion)
1. **CEX Ingestion (CCXT):**
   * Thu thập nến OHLCV (15m, 1h, 4h) và Orderbook cấp 2 cho `ADA/USDT` và `NIGHT/USDT`.
   * Cập nhật thời gian thực qua WebSocket để phục vụ tính toán chỉ số biến động tức thời.
2. **Cardano On-chain & DEX Ingestion (Adapter Pattern):**
   * **API nền tảng:** Sử dụng **Blockfrost API** (kết hợp fallback sang **Koios API**).
   * **Giám sát Ví cá mập ADA:** Theo dõi số dư và giao dịch chuyển tiền $> 500,000$ ADA của top ví cá mập và ví sàn CEX.
   * **Giám sát Token NIGHT:** Sử dụng Blockfrost Asset API để quét danh sách top ví nắm giữ token NIGHT, phát hiện sớm các đợt gom hàng hoặc xả token.
   * **Giám sát Pool DEX:** Đọc trạng thái thanh khoản (Reserves) của pool `NIGHT/ADA` và `ADA/USDC` trên Minswap thông qua DexHunter/Minswap API.
3. **News & Sentiment Ingestion:**
   * Tự động quét RSS chính thống từ Cardano Foundation, blog Input Output Global (IOG), Midnight Network blog.
   * Tích hợp CryptoPanic API và CoinGecko News API để lấy tin tức nhanh về Cardano và Midnight.
   * Đọc các bài thảo luận nổi bật trên Reddit `r/cardano`.

### 4.2. Phân hệ Trí tuệ Nhân tạo (Hybrid AI Engine)
1. **Dự đoán Xu hướng Giá (Price Trend Forecasting):**
   * **Thuật toán:** LightGBM / XGBoost Classifier & Regressor.
   * **Đặc trưng kỹ thuật (Technical Features):** RSI, MACD, EMA(9, 21, 50, 200), Bollinger Bands, ATR, On-Balance Volume (OBV).
   * **Đặc trưng On-chain:** Dòng tiền vào/ra ví cá mập (Net Whale Inflow/Outflow), thanh khoản biến động trên pool DEX.
2. **Đặc trưng Đón đầu Liên thị trường & Quy đổi Giá USD Chuẩn (True USD Parity):**
   * Do `NIGHT/USDT` giao dịch trên CEX với độ trễ tính bằng mili-giây, trong khi `NIGHT/ADA` trên Minswap chịu độ trễ khối Cardano (20 - 40s):
   * Tốc độ thay đổi giá (Price Velocity) và Volume Spike của `NIGHT/USDT` trên CEX được chuyển thành tín hiệu đầu vào cho mô hình dự đoán xu hướng của `NIGHT/ADA` trên DEX.
   * **True USD Parity:** So sánh giá USD thực tế giữa hai sàn bằng công thức $\text{Giá DEX quy USD} = (\text{NIGHT/ADA}) \times (\text{ADA/USD})$, triệt tiêu sai số do chênh lệch tỷ giá trung gian ADA/USDT.
3. **Chiến lược Tích lũy Cặp Tối ưu (NIGHT/ADA Pair Accumulation Engine):**
   * Sử dụng Z-score, dải Bollinger Bands và RSI trên tỷ giá giao dịch chéo $R = \text{NIGHT/ADA}$.
   * Tự động phát hiện vùng cực đại/cực tiểu để luân chuyển vốn (Dùng ADA mua NIGHT khi tỷ giá chạm đáy; Chốt NIGHT sang ADA khi tỷ giá chạm đỉnh) nhằm tối đa hóa số lượng nắm giữ cả 2 đồng token.
4. **Phát hiện Bất thường (Whale Anomaly Detection):**
   * Thuật toán **Isolation Forest** tính toán điểm số bất thường (Anomaly Score) khi có giao dịch lớn đột biến hoặc sự dịch chuyển token bất thường của dự án.
5. **Phân tích Cảm xúc (Sentiment Analysis):**
   * Sử dụng **Gemini API** (mô hình tốc độ cao, chi phí tối ưu) để đánh giá tiêu đề và tóm tắt tin tức, gán điểm cảm xúc $S \in [-1.0, +1.0]$.

### 4.3. Phân hệ Mô phỏng Khớp lệnh Giả lập (Realistic Paper Trading Engine)
Để phản ánh chính xác hiệu suất thực tế:
1. **Mô phỏng CEX (`ADA/USDT`, `NIGHT/USDT`):**
   * Phí giao dịch cố định: $0.075\% - 0.1\%$ mỗi chiều (Taker Fee).
   * Trượt giá (Slippage): Tính toán dựa trên độ sâu Orderbook (tối thiểu $0.05\%$).
2. **Mô phỏng Cardano DEX (`NIGHT/ADA`, `ADA/USDC`):**
   * **Phí mạng lưới Cardano (Network Fee):** $0.17 - 0.20$ ADA / giao dịch.
   * **Phí Batcher DEX:** Cố định $2.0$ ADA / lệnh hoán đổi (Swap).
   * **Độ trễ khớp lệnh (Batcher Execution Delay):** Lệnh không khớp ngay lập tức mà bị giữ trạng thái "Pending" từ $20 - 40$ giây (tương đương 1 - 2 block Cardano), khớp theo giá nến tiếp theo.
   * **Trượt giá AMM:** Tính toán trực tiếp dựa trên công thức hàm tích số không đổi $x \cdot y = k$ theo quy mô lệnh và thanh khoản thực của pool.

### 4.4. Phân hệ Quản trị Rủi ro (Risk Management)
* **Quy mô vị thế (Position Sizing):** Tối đa $1.0\% - 2.0\%$ vốn khả dụng cho một vị thế (Áp dụng tiêu chuẩn Kelly Criterion hiệu chỉnh).
* **Cắt lỗ & Chốt lời động (ATR SL/TP):**
  * Stop-Loss (SL) đặt ở mức $1.5 \times \text{ATR}(14)$.
  * Take-Profit (TP) theo tỷ lệ Risk:Reward tối thiểu $1:2$ hoặc Trailing Stop khi lợi nhuận đạt $> 1 \times \text{ATR}$.
* **Cơ chế ngắt mạch an toàn (Circuit Breaker):**
  * Tự động ngừng mở vị thế mới nếu tài khoản sụt giảm (Drawdown) vượt quá $5\%$ trong vòng 24 giờ.
  * Tạm dừng giao dịch DEX nếu phát hiện trượt giá bất thường $> 3\%$ hoặc mạng Cardano có dấu hiệu quá tải block.

### 4.5. Phân hệ Cảnh báo & Điều khiển Telegram Bot (Phase 1 UI)
* **Kênh gửi cảnh báo:**
  * Thông báo khi AI phát hiện điểm vào lệnh mạnh (kèm độ tin cậy, lý do, SL/TP gợi ý).
  * Cảnh báo biến động ví cá mập ADA và NIGHT.
  * Cảnh báo chênh lệch giá Arbitrage Spread giữa CEX và DEX đối với cặp NIGHT.
  * Thông báo khớp lệnh Paper Trading và trạng thái PnL theo thời gian thực.
* **Bộ lệnh điều khiển 2 chiều:**
  * `/status`: Xem trạng thái hoạt động của bot, kết nối CEX, DEX, Blockfrost.
  * `/pnl`: Báo cáo lời/lỗ chi tiết của các lệnh Paper Trading đang mở và lịch sử đóng lệnh.
  * `/signals`: Xem danh sách các tín hiệu AI gần nhất.
  * `/balance`: Xem số dư tài khoản giả lập (CEX USDT, Cardano ADA/NIGHT).
  * `/stop_all`: Lệnh khẩn cấp dừng toàn bộ hoạt động giao dịch giả lập mới.

---

## 5. NGĂN XẾP CÔNG NGHỆ (TECH STACK)

| Thành phần | Công nghệ lựa chọn | Ghi chú & Lý do |
| :--- | :--- | :--- |
| **Ngôn ngữ lõi** | **Python 3.11+** | Hệ sinh thái AI/ML và định lượng mạnh mẽ nhất, đồng bộ mã nguồn. |
| **Framework Backend** | **FastAPI + Asyncio** | Hiệu năng xử lý bất đồng bộ cao, cung cấp REST API cho Dashboard tương lai. |
| **CEX Gateway** | **CCXT (Python)** | Thư viện chuẩn hóa kết nối Binance, OKX, Bybit, MEXC. |
| **Cardano On-chain** | **Blockfrost Python SDK, Koios REST, PyCardano** | Đọc dữ liệu eUTxO, kiểm tra Asset Token và xây dựng adapter on-chain. |
| **Machine Learning** | **LightGBM, XGBoost, Scikit-learn, TA-Lib** | Huấn luyện nhanh, suy luận mili-giây, chống overfit. |
| **NLP & Sentiment** | **Google Gemini API (Flash/Pro)** | Phân tích ngữ cảnh tin tức thông minh, chi phí tối ưu, độ trễ thấp. |
| **Event Bus & Caching** | **Redis** | Đệm dữ liệu nến thời gian thực và hàng đợi tín hiệu. |
| **Cơ sở dữ liệu** | **SQLite (Dev) / PostgreSQL (Prod)** | Lưu trữ lịch sử nến, giao dịch cá mập, nhật ký Paper Trade. |
| **Telegram Bot** | **python-telegram-bot (v20+ Async)** | Thư viện chính thức, hỗ trợ menu inline button và xử lý lệnh bất đồng bộ. |
| **Container & Triển khai** | **Docker & Docker Compose** | Đóng gói 1-click chuyển giao từ máy cá nhân lên VPS Linux 24/7. |

---

## 6. CẤU TRÚC THƯ MỤC DỰ ÁN DỰ KIẾN (PROJECT STRUCTURE)

```text
E:\Antigravity\3. Bot trade coin\
├── config/
│   ├── settings.py               # Quản lý cấu hình Pydantic
│   └── config.env.example        # Mẫu biến môi trường (Blockfrost, CEX, Telegram, Gemini)
├── docs/
│   ├── tech-documentv1.md        # Tài liệu gốc ban đầu
│   └── tech-documentv2.md        # Tài liệu đặc tả kỹ thuật v2.0 (Tệp này)
├── src/
│   ├── collectors/               # Thu thập dữ liệu
│   │   ├── cex_collector.py      # CCXT WebSocket/REST (ADA/USDT, NIGHT/USDT)
│   │   ├── cardano_collector.py  # Blockfrost/Koios Adapter (ADA & NIGHT on-chain)
│   │   ├── dex_collector.py      # DexHunter/Minswap Pool Reserves
│   │   └── news_collector.py     # RSS, Reddit, CryptoPanic, CoinGecko
│   ├── ai/                       # Lõi trí tuệ nhân tạo
│   │   ├── features.py           # Tính toán TA-Lib + On-chain + Lead-Lag Features
│   │   ├── price_predictor.py    # Mô hình LightGBM / XGBoost
│   │   ├── whale_detector.py     # Isolation Forest Anomaly Detection
│   │   └── sentiment_analyzer.py # Gemini API News Scorer
│   ├── trading/                  # Chiến lược & Giả lập
│   │   ├── paper_cex.py          # Paper Trading Simulator cho CEX
│   │   ├── paper_dex.py          # Paper Trading Simulator cho Cardano DEX
│   │   ├── risk_manager.py       # ATR SL/TP, Position Sizing, Circuit Breaker
│   │   └── strategy_executor.py  # Điều phối tín hiệu và khớp lệnh giả lập
│   ├── bot/                      # Giao diện người dùng Phase 1
│   │   ├── telegram_bot.py       # Xử lý lệnh Telegram & Cảnh báo tương tác
│   │   └── charts.py             # Sinh biểu đồ mini trực quan gửi kèm cảnh báo
│   ├── database/                 # Lưu trữ
│   │   ├── models.py             # SQLAlchemy models (Signals, Trades, Whales)
│   │   └── db_session.py         # Kết nối Database SQLite/Postgres
│   └── main.py                   # Điểm khởi chạy hệ thống (Async Runner)
├── docker-compose.yml            # Kịch bản chạy VPS (App + Redis + Postgres)
├── Dockerfile                    # Đóng gói Python 3.11 Container
├── requirements.txt              # Danh sách thư viện Python
└── README.md                     # Hướng dẫn cài đặt và sử dụng
```

---

## 7. LỘ TRÌNH TRIỂN KHAI CHI TIẾT (IMPLEMENTATION ROADMAP)

* **Bước 1: Khởi tạo Hạ tầng & Thu thập Dữ liệu (Foundation & Data Ingestion)**
  * Khởi tạo cấu trúc dự án, môi trường ảo Python và `requirements.txt`.
  * Viết module `cex_collector.py` (Lấy dữ liệu nến `ADA/USDT`, `NIGHT/USDT`).
  * Viết module `cardano_collector.py` & `dex_collector.py` (Blockfrost SDK, pool `NIGHT/ADA`, `ADA/USDC`).
  * Viết module `news_collector.py` (RSS & CryptoPanic).
* **Bước 2: Xây dựng Lõi AI & Xử lý Đặc trưng (Feature Engineering & AI)**
  * Xây dựng bộ trích xuất đặc trưng: Chỉ báo kỹ thuật, On-chain Whale Flow và Cross-market Lead-lag Feature cho NIGHT.
  * Huấn luyện mô hình LightGBM trên dữ liệu lịch sử.
  * Tích hợp Gemini API phân tích cảm xúc tin tức và Isolation Forest lọc cá mập.
* **Bước 3: Công cụ Giả lập Khớp lệnh & Quản trị Rủi ro (Paper Trading & Risk Engine)**
  * Hiện thực hóa `paper_cex.py` (tính phí 0.075%, trượt giá).
  * Hiện thực hóa `paper_dex.py` (phí 2 ADA batcher, 0.2 ADA tx, delay 20-40s, trượt giá AMM).
  * Kiểm soát rủi ro với ATR Dynamic SL/TP và Circuit Breaker.
* **Bước 4: Tích hợp Telegram Bot & Chạy Thử nghiệm 24/7 (Interactive Alerts & Validation)**
  * Xây dựng Telegram Bot tương tác 2 chiều và báo cáo PnL định kỳ.
  * Chạy thử nghiệm Paper Trading liên tục 24/7 để đánh giá hiệu suất mô hình AI.
* **Bước 5: Đóng gói Docker & Web Dashboard (Phase 2)**
  * Hoàn thiện `Dockerfile` và `docker-compose.yml`.
  * Triển khai Web Dashboard quản trị với Next.js & TradingView Charts.

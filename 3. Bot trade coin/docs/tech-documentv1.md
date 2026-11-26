# TÀI LIỆU ĐẶC TẢ YÊU CẦU KỸ THUẬT (SRS)
**Tên dự án:** Hệ thống AI Bot Theo dõi & Giao dịch Tự động Hệ sinh thái Cardano (Cardano AI Sentinel & Auto-Trader)  
**Phiên bản:** 1.0  
**Ngày cập nhật:** 25/11/2026  
**Trạng thái:** Bản nháp hoàn chỉnh (Ready for Development)  

---

## 1. TỔNG QUAN DỰ ÁN (PROJECT OVERVIEW)

### 1.1. Mục tiêu
Xây dựng một hệ thống Bot tự động ứng dụng Trí tuệ nhân tạo (AI/ML) nhằm mục đích:
1. **Theo dõi (Monitoring):** Giám sát biến động giá, thanh khoản, dữ liệu On-chain và tâm lý thị trường theo thời gian thực đối với đồng tiền điện tử **Cardano (ADA)** và các **Cardano Native Tokens (CNT)** (ví dụ: SNEK, MIN, LENFI, IAG, WMTX...).
2. **Phân tích (Analysis):** Sử dụng các mô hình Học máy (Machine Learning) và Xử lý ngôn ngữ tự nhiên (NLP/LLM) để dự đoán xu hướng giá và phát hiện bất thường (cá mập gom/xả hàng, thay đổi thanh khoản đột ngột).
3. **Giao dịch tự động (Automated Trading):** Tự động thực thi lệnh mua/bán trên cả sàn giao dịch tập trung (CEX) và sàn giao dịch phi tập trung trên mạng lưới Cardano (DEX) dựa trên tín hiệu từ AI, đi kèm cơ chế quản trị rủi ro nghiêm ngặt.

### 1.2. Phạm vi hệ thống
* **Hỗ trợ mạng lưới:** Cardano Mainnet (và Preprod/Preview Testnet cho môi trường thử nghiệm).
* **Sàn giao dịch mục tiêu:**
  * **CEX:** Binance, Bybit, OKX (giao dịch cặp ADA/USDT, ADA/USDC, Futures).
  * **Cardano DEX:** Minswap, SundaeSwap, WingRiders, Spectrum Finance (thông qua các DEX Aggregators như DexHunter hoặc SteelSwap).
* **Kênh thông báo & Điều khiển:** Telegram Bot, Discord Webhook, và Web Dashboard quản trị.

---

## 2. KIẾN TRÚC HỆ THỐNG (SYSTEM ARCHITECTURE)

Hệ thống được thiết kế theo kiến trúc **Microservices** hướng sự kiện (Event-Driven Architecture) để đảm bảo tính mở rộng, độ trễ thấp và khả năng chịu lỗi cao.

### 2.1. Sơ đồ luồng dữ liệu tổng quan
```text
[Nguồn Dữ Liệu] ---> [Data Ingestion Engine] ---> [Message Broker (Kafka/Redis)]
                                                            |
        +---------------------------------------------------+-----------------------------------+
        |                                                   |                                   |
        v                                                   v                                   v
[Time-Series DB]                                   [AI & Analytics Engine]             [Alert & Notification]
(TimescaleDB/ClickHouse)                           (Price Pred / Sentiment)            (Telegram / Discord)
                                                            |
                                                            v
                                                [Risk Management Module]
                                                            |
                                                            v
                                                [Order Execution Engine]
                                                   /                \
                                                  v                  v
                                            [CEX APIs]        [Cardano Node / DEX]
```

### 2.2. Các phân hệ chính
1. **Data Collector (Thu thập dữ liệu):** Kết nối WebSocket/API để lấy dữ liệu giá, sổ lệnh (Orderbook), dữ liệu On-chain Cardano (UTxO, giao dịch ví lớn) và tin tức/mạng xã hội.
2. **AI Core Engine (Lõi trí tuệ nhân tạo):** Xử lý đặc trưng (Feature Engineering), chạy mô hình dự đoán chuỗi thời gian và phân tích cảm xúc.
3. **Strategy & Risk Engine (Chiến lược & Quản trị rủi ro):** Kết hợp tín hiệu từ AI với các chỉ báo kỹ thuật truyền thống, tính toán quy mô vị thế (Position Sizing) và kiểm tra điều kiện an toàn trước khi ra lệnh.
4. **Execution Engine (Thực thi lệnh):** Quản lý ví Cardano (ký giao dịch bằng Private Key mã hóa), tương tác Smart Contract trên DEX hoặc gửi lệnh qua API CEX.
5. **Monitoring & UI (Giám sát & Giao diện):** Cung cấp Dashboard theo dõi PnL (lời/lỗ), trạng thái bot và gửi cảnh báo tức thời.

---

## 3. YÊU CẦU CHỨC NĂNG (FUNCTIONAL REQUIREMENTS)

### 3.1. Phân hệ Thu thập Dữ liệu Đặc thù Cardano (Cardano Data Ingestion)
* **FR-01 (Dữ liệu thị trường CEX):** Thu thập dữ liệu nến (OHLCV) từ khung 1m đến 1D, dữ liệu Orderbook (L2), Funding Rate và Open Interest của cặp ADA/USDT theo thời gian thực qua WebSocket.
* **FR-02 (Dữ liệu On-chain Cardano):** 
  * Tích hợp **Blockfrost API**, **Koios**, hoặc tự vận hành **Cardano Node + Ogmios/Kupo** để quét các block mới nhất (trung bình 20 giây/block).
  * Theo dõi biến động số dư của danh sách các ví cá mập (Whale Wallets) và ví của các quỹ đầu tư/dự án lớn.
  * Theo dõi dòng tiền vào/ra (Inflow/Outflow) trên các Smart Contract của các DEX lớn (Minswap, Minswap V2, Liqwid Finance).
  * Giám sát các Pool thanh khoản mới tạo (New Liquidity Pools) để phát hiện cơ hội hoặc cảnh báo Rug-pull.
* **FR-03 (Dữ liệu Mạng xã hội & Hệ sinh thái):** Thu thập bài đăng từ X (Twitter) của các tài khoản cốt lõi (Charles Hoskinson, IOG, Cardano Foundation, các dự án DeFi), Reddit (`r/cardano`), và các đề xuất quản trị (Catalyst / CIPs) để đánh giá tâm lý thị trường.

### 3.2. Phân hệ Trí tuệ Nhân tạo (AI & Machine Learning Models)
* **FR-04 (Dự đoán xu hướng giá - Time-Series Forecasting):**
  * Sử dụng mô hình **LSTM / Temporal Fusion Transformer (TFT)** hoặc **XGBoost/LightGBM** kết hợp dữ liệu giá quá khứ, khối lượng giao dịch và chỉ số On-chain để dự đoán xác suất tăng/giảm giá của ADA trong các khung thời gian ngắn hạn (15m, 1h, 4h).
* **FR-05 (Phân tích cảm xúc - Sentiment Analysis):**
  * Sử dụng mô hình ngôn ngữ lớn (LLM qua API hoặc mô hình FinBERT/Llama tinh chỉnh cục bộ) để chấm điểm cảm xúc tin tức từ `-1.0` (Rất tiêu cực) đến `+1.0` (Rất tích cực).
* **FR-06 (Phát hiện bất thường - Anomaly Detection):**
  * Sử dụng thuật toán **Isolation Forest** hoặc **Autoencoders** để phát hiện các giao dịch gom hàng bất thường trên mạng Cardano hoặc sự tăng đột biến về khối lượng giao dịch mà chưa phản ánh vào giá.

### 3.3. Phân hệ Chiến lược & Giao dịch Tự động (Trading & Execution)
* **FR-07 (Chế độ hoạt động):**
  * *Alert-Only Mode:* Chỉ gửi tín hiệu và phân tích qua Telegram/Discord, không tự vào lệnh.
  * *Paper Trading Mode:* Giao dịch giả lập với dữ liệu thật để kiểm thử hiệu quả của AI.
  * *Live Trading Mode:* Giao dịch bằng tiền thật.
* **FR-08 (Thực thi trên CEX):** Hỗ trợ đặt lệnh Market, Limit, OCO (One-Cancels-the-Other) qua thư viện `CCXT`.
* **FR-09 (Thực thi trên Cardano DEX):**
  * Tích hợp API của **DexHunter** hoặc trực tiếp tương tác với hợp đồng thông minh của Minswap thông qua thư viện `PyCardano` hoặc `Lucid / MeshJS`.
  * Tự động xử lý cơ chế **eUTxO** (chọn UTxO tối ưu, xử lý batching/concurrency trên Cardano DEX, tính toán phí mạng lưới và trượt giá - Slippage).

### 3.4. Phân hệ Quản trị Rủi ro (Risk Management - Bắt buộc)
* **FR-10 (Giới hạn cắt lỗ/chốt lời):** Mọi lệnh giao dịch bắt buộc phải đi kèm tham số Stop-Loss (SL) và Take-Profit (TP) động (Trailing Stop) dựa trên chỉ số biến động ATR (Average True Range).
* **FR-11 (Quản lý vốn - Position Sizing):** Giới hạn rủi ro tối đa trên mỗi lệnh không quá $1\% - 2\%$ tổng tài sản (sử dụng công thức Kelly Criterion điều chỉnh).
* **FR-12 (Ngắt mạch tự động - Circuit Breaker):** Tự động tạm dừng toàn bộ hoạt động mua mới nếu:
  * Tài khoản sụt giảm (Drawdown) quá $X\%$ (ví dụ: $5\%$) trong vòng 24 giờ.
  * Mạng lưới Cardano gặp sự cố nghẽn mạch nghiêm trọng hoặc phí giao dịch tăng đột biến bất thường.
  * Chỉ số biến động thị trường vượt ngưỡng an toàn (Flash Crash).

### 3.5. Giao diện Giám sát & Cảnh báo (Monitoring & Alerts)
* **FR-13 (Telegram Bot):** Gửi thông báo tức thời kèm biểu đồ mini khi: AI phát hiện tín hiệu mua/bán mạnh, ví cá mập di chuyển $> 500,000$ ADA, hoặc khi bot khớp lệnh thành công. Cho phép người dùng gõ lệnh `/status`, `/pnl`, `/stop_all` để điều khiển khẩn cấp.
* **FR-14 (Web Dashboard):** Hiển thị tổng quan tài sản, lịch sử giao dịch, biểu đồ trực quan hóa điểm mua/bán của AI, độ chính xác của mô hình theo thời gian thực.

---

## 4. YÊU CẦU PHI CHỨC NĂNG (NON-FUNCTIONAL REQUIREMENTS)

* **NFR-01 (Hiệu năng & Độ trễ):**
  * Thời gian từ lúc nhận dữ liệu giá đến lúc AI đưa ra quyết định giao dịch trên CEX phải dưới $500\text{ ms}$.
  * Thời gian xây dựng và gửi giao dịch lên mạng Cardano (Transaction Submission) dưới $3\text{ giây}$ kể từ khi có tín hiệu.
* **NFR-02 (Bảo mật - Security):**
  * Tuyệt đối không lưu trữ **Seed Phrase / Private Key** của ví Cardano và **API Secret** của CEX dưới dạng văn bản thuần (Plaintext). Phải sử dụng **HashiCorp Vault**, **AWS KMS**, hoặc mã hóa chuẩn AES-256 trong biến môi trường bảo mật.
  * API Key trên CEX bắt buộc tắt quyền Rút tiền (Disable Withdrawals) và giới hạn địa chỉ IP (IP Whitelisting).
* **NFR-03 (Độ tin cậy & Sẵn sàng):** Hệ thống đạt Uptime $99.9\%$. Tự động khởi động lại (Auto-restart) các container khi gặp lỗi và có cơ chế lưu trạng thái (State Persistence) để không bị mất dấu các lệnh đang mở.

---

## 5. ĐỀ XUẤT CÔNG NGHỆ (RECOMMENDED TECH STACK)

| Thành phần | Công nghệ đề xuất | Lý do lựa chọn |
| :--- | :--- | :--- |
| **Ngôn ngữ chính** | Python 3.11+ & TypeScript (Node.js) | Python mạnh về AI/ML và CCXT; TypeScript mạnh về các thư viện Cardano Web3 (`Lucid`, `MeshJS`). |
| **Cardano Integration** | `PyCardano`, `Lucid-Evolution`, Blockfrost API, Ogmios | Hỗ trợ tốt nhất việc xây dựng giao dịch eUTxO và đọc dữ liệu trực tiếp từ Cardano Node. |
| **AI / Machine Learning** | PyTorch, Scikit-learn, HuggingFace Transformers, TA-Lib | Đầy đủ công cụ cho Deep Learning, xử lý chỉ báo kỹ thuật và NLP. |
| **Cơ sở dữ liệu** | PostgreSQL + TimescaleDB, Redis | TimescaleDB tối ưu cho dữ liệu chuỗi thời gian (nến giá); Redis làm hàng đợi (Message Queue) tốc độ cao. |
| **Backend & API** | FastAPI (Python) | Hiệu năng cao, bất đồng bộ (Async), tự động tạo tài liệu Swagger UI. |
| **Frontend Dashboard** | Next.js / React + TailwindCSS + TradingView Lightweight Charts | Giao diện hiện đại, hiển thị biểu đồ tài chính mượt mà. |
| **Hạ tầng & Triển khai** | Docker, Docker Compose, VPS Linux (Ubuntu 22.04 LTS) | Dễ dàng đóng gói, triển khai đồng nhất và mở rộng tài nguyên. |

---

## 6. CẤU TRÚC DỮ LIỆU CƠ BẢN (DATA MODELS)

### 6.1. Cấu trúc Tín hiệu AI (AI Signal Payload - JSON)
```json
{
  "signal_id": "sig_ada_20261125_083000",
  "timestamp": "2026-11-25T08:30:00Z",
  "asset": "ADA/USDT",
  "network": "CARDANO_MAINNET",
  "action": "BUY",
  "confidence_score": 0.87,
  "reasoning": {
    "technical_score": 0.82,
    "onchain_whale_accumulation": true,
    "sentiment_score": 0.65,
    "summary": "Phát hiện dòng tiền 2.5M ADA rút khỏi sàn CEX về ví lạnh, kết hợp mô hình TFT dự báo tăng 4.2% trong 4h tới."
  },
  "suggested_params": {
    "entry_price": 0.8500,
    "stop_loss": 0.8150,
    "take_profit": 0.9200,
    "position_size_pct": 1.5
  }
}
```

---

## 7. LỘ TRÌNH PHÁT TRIỂN ĐỀ XUẤT (DEVELOPMENT ROADMAP)

* **Giai đoạn 1: Nền tảng Dữ liệu & Giám sát (Tuần 1 - 2)**
  * Thiết lập hạ tầng Docker, TimescaleDB, Redis.
  * Viết module thu thập dữ liệu giá CEX và dữ liệu On-chain Cardano (Blockfrost/Koios).
  * Xây dựng Telegram Bot thông báo biến động giá và giao dịch cá mập.
* **Giai đoạn 2: Phát triển Mô hình AI & Backtesting (Tuần 3 - 5)**
  * Thu thập dữ liệu lịch sử tối thiểu 2 năm của ADA và các Native Tokens chính.
  * Huấn luyện mô hình dự đoán giá và tích hợp module phân tích cảm xúc.
  * Chạy Backtest trên dữ liệu quá khứ (tính toán Sharpe Ratio, Max Drawdown, Win-rate).
* **Giai đoạn 3: Tích hợp Giao dịch Tự động & Quản trị Rủi ro (Tuần 6 - 7)**
  * Kết nối CCXT cho CEX và tích hợp thư viện giao dịch Cardano DEX.
  * Xây dựng module Quản trị rủi ro và cơ chế ngắt mạch tự động.
  * Chạy thử nghiệm **Paper Trading** và trên mạng **Cardano Preprod Testnet** trong tối thiểu 2 tuần.
* **Giai đoạn 4: Triển khai Thực tế & Tối ưu (Tuần 8+)**
  * Hoàn thiện Web Dashboard quản trị.
  * Triển khai Live Trading với số vốn nhỏ để theo dõi độ trượt giá thực tế (Slippage) và tinh chỉnh mô hình định kỳ (Model Retraining).

---

## 8. LƯU Ý ĐẶC THÙ KHI LẬP TRÌNH TRÊN CARDANO
1. **Mô hình eUTxO (Extended UTxO):** Khác với mô hình Account-based của Ethereum, giao dịch trên Cardano tiêu thụ các UTxO đầu vào và tạo ra UTxO đầu ra mới. Nếu bot gửi nhiều lệnh liên tiếp quá nhanh bằng cùng một ví, giao dịch sau có thể bị từ chối do UTxO đang bị khóa (chờ xác nhận block). **Giải pháp:** Chia nhỏ quỹ trong ví thành nhiều UTxO độc lập (ví dụ: 5-10 UTxO) để bot có thể thực hiện giao dịch song song.
2. **Cơ chế Batcher trên DEX:** Hầu hết các DEX trên Cardano hoạt động theo mô hình bất đồng bộ (người dùng gửi lệnh vào Smart Contract, sau đó các Batcher sẽ gom và khớp lệnh). Bot cần có cơ chế theo dõi trạng thái của lệnh (Order UTxO) để biết khi nào lệnh được khớp hoàn toàn hoặc thực hiện hủy lệnh (Cancel Order) nếu giá chạy quá xa.
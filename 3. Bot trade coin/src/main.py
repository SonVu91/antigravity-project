import asyncio
import logging
import signal
import sys
from datetime import datetime, timezone
from typing import Optional
import pandas as pd
from telegram import InlineKeyboardButton

from config.settings import settings
from src.database.db_session import init_db
from src.collectors.cex_collector import CEXCollector
from src.collectors.cardano_collector import CardanoCollector
from src.collectors.dex_collector import DEXCollector
from src.collectors.news_collector import NewsCollector

from src.ai.features import FeatureExtractor
from src.ai.price_predictor import PricePredictor
from src.ai.whale_detector import WhaleAnomalyDetector
from src.ai.sentiment_analyzer import SentimentAnalyzer

from src.trading.strategy_executor import StrategyExecutor
from src.bot.telegram_bot import TelegramSentinelBot
from src.bot.charts import generate_mini_chart, generate_sd_chart
from src.ai.supply_demand import SupplyDemandDetector

# Configure logging
logging.basicConfig(
    level=getattr(logging, settings.LOG_LEVEL.upper(), logging.INFO),
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
    handlers=[logging.StreamHandler(sys.stdout)],
)
logger = logging.getLogger("CardanoMidnightSentinel")


class SentinelApplication:
    """
    Main Orchestrator for Cardano & Midnight AI Sentinel & Auto-Trader.
    Runs 24/7 background loops for:
    - Data Ingestion (CEX & Cardano DEX)
    - True USD Parity Arbitrage Comparison (same USD denominator)
    - Pair Trading / Ratio Accumulation Engine (NIGHT/ADA Mean-Reversion)
    - AI Price Prediction (LightGBM) & Whale Detection (Isolation Forest)
    - Paper Trading & Telegram Alerts with interactive 1-click execution.
    """

    def __init__(self):
        self.cex_collector = CEXCollector(settings.DEFAULT_CEX_EXCHANGE)
        self.cardano_collector = CardanoCollector()
        self.dex_collector = DEXCollector()
        self.news_collector = NewsCollector()

        self.price_predictor = PricePredictor()
        self.whale_detector = WhaleAnomalyDetector()
        self.sentiment_analyzer = SentimentAnalyzer()

        self.executor = StrategyExecutor()
        self.sd_detector = SupplyDemandDetector()
        self.telegram_bot = TelegramSentinelBot(self.executor, cex_collector=self.cex_collector)
        self.is_running = False

        # Arbitrage spam filter state (USD Parity)
        self.last_arbitrage_spread: Optional[float] = None
        self.last_arbitrage_alert_time: Optional[datetime] = None

        # Pair accumulation alert state (NIGHT/ADA Ratio)
        self.last_ratio_action: Optional[str] = None
        self.last_ratio_alert_time: Optional[datetime] = None

    async def initialize(self) -> None:
        """Initialize database and external connections"""
        logger.info("Khởi tạo Cơ sở dữ liệu SQLite/Postgres...")
        await init_db()

        logger.info("Khởi động Telegram Bot với tương tác 2 chiều...")
        await self.telegram_bot.start()

        self.is_running = True
        logger.info(f"Hệ thống đã sẵn sàng hoạt động ở chế độ: {self.executor.risk_manager.bot_mode.upper()}")

    async def run_market_cycle(self) -> None:
        """Execute a full market monitoring, AI inference, and execution cycle"""
        logger.info("--- BẮT ĐẦU CHU KỲ QUÉT THỊ TRƯỜNG ---")

        # 1. Thu thập dữ liệu nến CEX theo khung nến cấu hình
        rm = self.executor.risk_manager
        tf = rm.timeframe
        is_trading_time = rm.is_within_trading_hours()
        if not is_trading_time:
            logger.info(f"⏳ Ngoài khung giờ giao dịch ({rm.trading_hours}). Chế độ Standby: Chỉ theo dõi bảo vệ TP/SL, không mở lệnh mới.")

        ada_candles = await self.cex_collector.fetch_ohlcv(settings.CEX_ADA_PAIR, timeframe=tf, limit=50)
        night_candles = await self.cex_collector.fetch_ohlcv(settings.CEX_NIGHT_PAIR, timeframe=tf, limit=50)

        # 2. Thu thập dữ liệu Cardano On-chain & DEX
        latest_block = await self.cardano_collector.get_latest_block()
        whale_txs = await self.cardano_collector.scan_whale_transactions(min_ada_amount=500_000.0)
        dex_night_res = await self.dex_collector.fetch_pool_reserves(settings.DEX_NIGHT_PAIR)

        logger.info(f"Cardano Block hiện tại: #{latest_block.get('block_no')}, Phát hiện ví lớn: {len(whale_txs)}")

        # 3. Phân tích tin tức & cảm xúc AI
        headlines = await self.news_collector.get_latest_headlines()
        sentiment = await self.sentiment_analyzer.analyze_headlines(headlines)
        sentiment_score = sentiment.get("sentiment_score", 0.0)
        logger.info(f"Điểm cảm xúc tin tức (Gemini): {sentiment_score:+.2f} ({sentiment.get('summary')})")

        # 4. Chuẩn bị DataFrames
        df_ada = pd.DataFrame(ada_candles) if ada_candles else pd.DataFrame()
        df_night = pd.DataFrame(night_candles) if night_candles else pd.DataFrame()

        cex_night_usd = float(df_night["close"].iloc[-1]) if not df_night.empty else 0.10
        cex_ada_usd = float(df_ada["close"].iloc[-1]) if not df_ada.empty else 0.85
        dex_night_ada_ratio = float(dex_night_res.get("price", 0.125))

        now = datetime.now(timezone.utc)

        # =========================================================================
        # MODULE 1: SO SÁNH CHÊNH LỆCH GIÁ USD THỰC TẾ (CEX vs CARDANO DEX)
        # =========================================================================
        usd_parity = FeatureExtractor.calculate_usd_parity(
            cex_night_usd=cex_night_usd,
            cex_ada_usd=cex_ada_usd,
            dex_night_ada_ratio=dex_night_ada_ratio,
        )
        spread = usd_parity["spread_pct"]
        threshold = self.executor.risk_manager.arbitrage_threshold_pct
        is_dex_live = dex_night_res.get("is_live", True)

        if not is_dex_live:
            logger.warning("DEX Pool data đang ở chế độ dự phòng (fallback). Bỏ qua cảnh báo chênh lệch giá CEX vs DEX để tránh báo sai.")
        elif abs(spread) >= threshold:
            should_alert = False
            if self.last_arbitrage_alert_time is None:
                should_alert = True
            elif (now - self.last_arbitrage_alert_time).total_seconds() >= 900:  # 15 minutes
                should_alert = True
            elif abs(spread - (self.last_arbitrage_spread or 0.0)) >= 5.0:  # Delta >= 5%
                should_alert = True

            if should_alert:
                self.last_arbitrage_spread = spread
                self.last_arbitrage_alert_time = now

                cheaper = usd_parity["cheaper_market"]
                diff_usd = usd_parity["diff_usd"]
                comparison_note = "CEX đắt hơn DEX" if spread > 0 else "DEX đắt hơn CEX"

                alert_msg = (
                    f"⚖️ *CHÊNH LỆCH GIÁ USD THỰC TẾ (CEX vs CARDANO DEX)*\n\n"
                    f"• Giá CEX (NIGHT/USDT, USDC): `${usd_parity['cex_night_usd']:.4f}`\n"
                    f"• Giá DEX quy ra USD: `${usd_parity['dex_night_usd']:.4f}` (Dựa trên NIGHT/ADA x ADA/USD)\n"
                    f"• Độ lệch giá USD: `{spread:+.2f}%` ({comparison_note} `${abs(diff_usd):.4f}`)\n\n"
                    f"💡 _Nhận định:_ Token NIGHT trên sàn *{cheaper}* đang có giá rẻ hơn. Bạn có thể chọn sàn giá thấp để mua tối ưu!"
                )

                if cheaper == "DEX":
                    arb_btn = InlineKeyboardButton("⚡ MUA RẺ HƠN TRÊN DEX", callback_data="order_prep:NIGHT/ADA:BUY:DEX")
                else:
                    arb_btn = InlineKeyboardButton("⚡ MUA RẺ HƠN TRÊN CEX", callback_data="order_prep:NIGHT/USDT:BUY:CEX")

                arb_buttons = [[arb_btn, InlineKeyboardButton("❌ BỎ QUA", callback_data="cancel")]]
                await self.telegram_bot.send_alert("CHÊNH LỆCH GIÁ USD (CEX vs DEX)", alert_msg, buttons=arb_buttons)

        # =========================================================================
        # MODULE 2: TỐI ƯU TỶ GIÁ CẶP NIGHT/ADA (PAIR ACCUMULATION ENGINE)
        # =========================================================================
        ratio_analysis = FeatureExtractor.calculate_night_ada_ratio_analysis(
            cex_night_df=df_night,
            cex_ada_df=df_ada,
            dex_night_ada_price=dex_night_ada_ratio,
        )
        ratio_action = ratio_analysis["action"]
        logger.info(f"Tỷ giá NIGHT/ADA: 1 NIGHT = {ratio_analysis['current_ratio']:.4f} ADA (Z-score: {ratio_analysis['z_score']:+.2f}, Trạng thái: {ratio_action})")

        if ratio_action in ["ACCUMULATE_NIGHT", "ACCUMULATE_ADA"]:
            should_alert_ratio = False
            if self.last_ratio_alert_time is None or self.last_ratio_action != ratio_action:
                should_alert_ratio = True
            elif (now - self.last_ratio_alert_time).total_seconds() >= 1800:  # 30 minutes
                should_alert_ratio = True

            if should_alert_ratio:
                self.last_ratio_action = ratio_action
                self.last_ratio_alert_time = now

                if ratio_action == "ACCUMULATE_NIGHT":
                    action_title = "🟢 ĐIỂM ĐẸP TÍCH LŨY NIGHT"
                    action_button = InlineKeyboardButton("🟢 DÙNG ADA MUA GOM NIGHT", callback_data="order_prep:NIGHT/ADA:BUY:DEX")
                else:
                    action_title = "🔴 ĐIỂM ĐẸP TÍCH LŨY ADA"
                    action_button = InlineKeyboardButton("🔴 ĐỔI NIGHT THU VỀ ADA", callback_data="order_prep:NIGHT/ADA:SELL:DEX")

                ratio_msg = (
                    f"🔄 *TỐI ƯU TỶ GIÁ CẶP (PAIR ACCUMULATION: NIGHT/ADA)*\n\n"
                    f"• Tỷ giá hiện tại: `1 NIGHT = {ratio_analysis['current_ratio']:.4f} ADA` (`1 ADA = {ratio_analysis['inv_ratio']:.2f} NIGHT`)\n"
                    f"• Tỷ giá trung bình (SMA20): `1 NIGHT = {ratio_analysis['mean_ratio']:.4f} ADA`\n"
                    f"• Tín hiệu Định lượng: *{action_title}*\n"
                    f"• Z-score: `{ratio_analysis['z_score']:+.2f}` | RSI Tỷ giá: `{ratio_analysis['ratio_rsi']}`\n\n"
                    f"💡 _{ratio_analysis['recommendation']}_"
                )
                ratio_buttons = [[action_button, InlineKeyboardButton("❌ BỎ QUA", callback_data="cancel")]]
                await self.telegram_bot.send_alert("TỐI ƯU TỶ GIÁ CẶP NIGHT / ADA", ratio_msg, buttons=ratio_buttons)

        # 5. Khởi tạo bảng giá thị trường phục vụ tính toán và giám sát TP/SL
        current_prices = {
            settings.CEX_ADA_PAIR: cex_ada_usd,
            settings.CEX_NIGHT_PAIR: cex_night_usd,
            settings.DEX_NIGHT_PAIR: dex_night_ada_ratio,
        }

        # 6. Sinh tín hiệu AI cho ADA/USDT (🏦 CEX)
        if not df_ada.empty and len(df_ada) >= 14:
            if is_trading_time:
                ada_signal = self.price_predictor.generate_signal(
                    asset=settings.CEX_ADA_PAIR,
                    market_type="CEX",
                    df=df_ada,
                    sentiment_score=sentiment_score,
                    whale_inflow=sum(w["amount"] for w in whale_txs if w["asset"] == "ADA"),
                )
                await self._handle_signal_execution(ada_signal, ada_candles, market_data={})

        # 7. Sinh tín hiệu AI cho NIGHT/ADA (🥞 Cardano DEX) với tính năng Lead-Lag
        lead_lag_data = FeatureExtractor.calculate_lead_lag_features(
            cex_night_df=df_night,
            cex_ada_df=df_ada,
            dex_night_ada_price=dex_night_ada_ratio,
        )
        if not df_night.empty and len(df_night) >= 14:
            if is_trading_time:
                night_dex_signal = self.price_predictor.generate_signal(
                    asset=settings.DEX_NIGHT_PAIR,
                    market_type="DEX",
                    df=df_night,
                    sentiment_score=sentiment_score,
                    lead_lag_data=lead_lag_data,
                    whale_inflow=sum(w["amount"] for w in whale_txs if w["asset"] == "NIGHT"),
                )
                await self._handle_signal_execution(night_dex_signal, night_candles, market_data={"pool_reserves": dex_night_res})

        # 8. Quét các đồng coin bổ sung trong danh sách theo dõi (Watched Coins)
        for coin_pair in rm.watched_coins:
            if coin_pair in [settings.CEX_ADA_PAIR, settings.CEX_NIGHT_PAIR, settings.DEX_NIGHT_PAIR]:
                continue
            try:
                coin_candles = await self.cex_collector.fetch_ohlcv(coin_pair, timeframe=tf, limit=50)
                if coin_candles and len(coin_candles) >= 14:
                    df_coin = pd.DataFrame(coin_candles)
                    current_prices[coin_pair] = float(df_coin["close"].iloc[-1])
                    if is_trading_time:
                        coin_sig = self.price_predictor.generate_signal(
                            asset=coin_pair,
                            market_type="CEX",
                            df=df_coin,
                            sentiment_score=sentiment_score,
                        )
                        await self._handle_signal_execution(coin_sig, coin_candles, market_data={})
            except Exception as e:
                logger.debug(f"Bỏ qua quét phụ cho {coin_pair}: {e}")

        # 9. Kiểm tra đóng vị thế TP/SL các lệnh đang mở (Luôn chạy 24/7 để bảo vệ tài sản)
        closed_cex = self.executor.cex_sim.check_open_positions(current_prices)
        closed_dex = self.executor.dex_sim.check_open_positions(current_prices)

        for trade in closed_cex + closed_dex:
            await self.executor.reporter.record_closed_trade_in_db(trade)
            await self.executor.reporter.sync_database(current_prices)
            report_block = await self.executor.reporter.format_telegram_report(
                trigger_type="CLOSE",
                trade_info=trade,
                current_prices=current_prices,
            )
            market_badge = "🏦 CEX" if trade['market_type'] == "CEX" else "🥞 CARDANO DEX"
            pnl_msg = (
                f"Đã đóng vị thế {trade['asset']} trên {market_badge}:\n"
                f"• Lý do: `{trade.get('close_reason')}`\n"
                f"• Lời/Lỗ: `{trade.get('pnl'):+,.2f}` ({trade.get('pnl_pct'):+.2f}%)\n"
                f"• Giá thoát: `{trade.get('exit_price')}`\n\n"
                f"{report_block}"
            )
            await self.telegram_bot.send_alert("CHỐT VỊ THẾ PAPER TRADING", pnl_msg)

        logger.info("--- HOÀN TẤT CHU KỲ QUÉT THỊ TRƯỜNG ---")

    async def _handle_signal_execution(self, signal: dict, candles: list, market_data: dict) -> None:
        action = signal.get("action")
        asset = signal.get("asset")
        market_type = signal.get("market_type", "CEX")
        confidence = signal.get("confidence_score", 0.0)

        market_badge = "🏦 SÀN TẬP TRUNG (CEX: Binance)" if market_type == "CEX" else "🥞 SÀN PHI TẬP TRUNG (CARDANO DEX: Minswap eUTxO)"
        badge_short = "🏦 CEX" if market_type == "CEX" else "🥞 DEX"

        logger.info(f"Tín hiệu AI [{badge_short}]: {asset} => {action} (Độ tin cậy: {confidence*100:.0f}%)")

        if action in ["BUY", "SELL"] and confidence >= 0.60:
            tf = self.executor.risk_manager.timeframe
            # Phân tích Vùng Cung - Cầu (Supply & Demand Confluence)
            sd_signal = self.sd_detector.analyze(candles, symbol=asset, timeframe=tf)
            if sd_signal.active_zones:
                chart_file = generate_sd_chart(
                    candles=candles,
                    symbol=asset,
                    timeframe=tf,
                    zones=sd_signal.active_zones,
                    signal=sd_signal,
                )
                # Tối ưu hóa SL và TP theo Vùng S&D nếu có
                if action == "BUY" and sd_signal.nearest_demand and sd_signal.stop_loss > 0:
                    signal["suggested_params"]["stop_loss"] = sd_signal.stop_loss
                    if sd_signal.take_profit > 0:
                        signal["suggested_params"]["take_profit"] = sd_signal.take_profit
                elif action == "SELL" and sd_signal.nearest_supply and sd_signal.stop_loss > 0:
                    signal["suggested_params"]["stop_loss"] = sd_signal.stop_loss
                    if sd_signal.take_profit > 0:
                        signal["suggested_params"]["take_profit"] = sd_signal.take_profit
            else:
                chart_file = generate_mini_chart(
                    candles=candles,
                    symbol=asset,
                    action=action,
                    entry_price=signal["suggested_params"]["entry_price"],
                    stop_loss=signal["suggested_params"]["stop_loss"],
                    take_profit=signal["suggested_params"]["take_profit"],
                )

            sd_extra = ""
            if sd_signal.nearest_demand:
                d = sd_signal.nearest_demand
                sd_extra += f"• 🟢 Vùng Cầu (Demand): `[{d.distal:.4f} - {d.proximal:.4f}]` ({d.status.value})\n"
            if sd_signal.nearest_supply:
                s = sd_signal.nearest_supply
                sd_extra += f"• 🔴 Vùng Cung (Supply): `[{s.proximal:.4f} - {s.distal:.4f}]` ({s.status.value})\n"

            alert_text = (
                f"• Nền tảng thực thi: `{market_badge}`\n"
                f"• Cặp giao dịch: `{asset}`\n"
                f"• Hành động: *{action}*\n"
                f"• Độ tin cậy AI: `{confidence*100:.1f}%`\n"
                f"• Giá vào gợi ý: `{signal['suggested_params']['entry_price']}`\n"
                f"• Stop-Loss: `{signal['suggested_params']['stop_loss']}`\n"
                f"• Take-Profit: `{signal['suggested_params']['take_profit']}`\n"
                f"{sd_extra}\n"
                f"💡 _Phân tích:_ {signal['reasoning']['summary']}"
            )

            action_buttons = [
                [
                    InlineKeyboardButton(f"✅ MUA THEO AI ({badge_short})", callback_data=f"order_prep:{asset}:{action}:{market_type}"),
                    InlineKeyboardButton("❌ BỎ QUA", callback_data="cancel"),
                ]
            ]
            await self.telegram_bot.send_alert(
                f"TÍN HIỆU GIAO DỊCH AI [{asset}]",
                alert_text,
                image_path=chart_file,
                buttons=action_buttons,
            )

            exec_result = await self.executor.process_signal(signal, market_data)
            if exec_result.get("status") == "EXECUTED":
                trade = exec_result["trade"]
                exec_badge = "🥞 CARDANO DEX" if trade['market_type'] == "DEX" else "🏦 CEX"
                fee_unit = "ADA" if trade['market_type'] == "DEX" else "USDT"
                report_block = await self.executor.reporter.format_telegram_report(
                    trigger_type="EXECUTE",
                    trade_info=trade,
                )
                exec_msg = (
                    f"✅ Khớp lệnh Giả lập thành công trên {exec_badge}:\n"
                    f"• Mã lệnh: `{trade['trade_id']}`\n"
                    f"• {trade['side']} `{trade['quantity']:,.2f} {asset.split('/')[0]}`\n"
                    f"• Giá khớp: `{trade['entry_price']}`\n"
                    f"• Phí đã trừ: `{trade['fee_paid']} {fee_unit}`\n"
                    f"• Trượt giá: `{trade['slippage']}%\n\n`"
                    f"{report_block}"
                )
                await self.telegram_bot.send_alert("KHỚP LỆNH PAPER TRADING", exec_msg)

    async def start_loop(self, interval_seconds: int = 60) -> None:
        """Run continuous monitoring loop"""
        await self.initialize()

        # Run first cycle immediately
        await self.run_market_cycle()

        while self.is_running:
            try:
                await asyncio.sleep(interval_seconds)
                if self.is_running:
                    await self.run_market_cycle()
            except asyncio.CancelledError:
                break
            except Exception as e:
                logger.error(f"Lỗi trong vòng lặp thị trường: {e}", exc_info=True)
                await asyncio.sleep(10)

    async def shutdown(self) -> None:
        """Graceful shutdown"""
        logger.info("Đang tắt hệ thống an toàn...")
        self.is_running = False
        await self.cex_collector.close()
        await self.telegram_bot.stop()
        logger.info("Hệ thống đã dừng hoàn toàn.")


async def main():
    app = SentinelApplication()

    loop = asyncio.get_running_loop()
    for sig in (signal.SIGINT, signal.SIGTERM):
        try:
            loop.add_signal_handler(sig, lambda: asyncio.create_task(app.shutdown()))
        except (NotImplementedError, AttributeError):
            pass

    try:
        await app.start_loop(interval_seconds=60)
    except (KeyboardInterrupt, SystemExit):
        await app.shutdown()


if __name__ == "__main__":
    asyncio.run(main())

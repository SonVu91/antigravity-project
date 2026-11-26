import asyncio
import os
import sys
import unittest
from datetime import datetime, timezone
import pandas as pd
import numpy as np

# Ensure project root is in path
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from config.settings import settings
from src.database.db_session import init_db, get_session
from src.database.models import Candle, WhaleTransaction, AISignal, PaperTrade

from src.collectors.cex_collector import CEXCollector
from src.collectors.cardano_collector import CardanoCollector
from src.collectors.dex_collector import DEXCollector
from src.collectors.news_collector import NewsCollector

from src.ai.features import FeatureExtractor
from src.ai.price_predictor import PricePredictor
from src.ai.whale_detector import WhaleAnomalyDetector
from src.ai.sentiment_analyzer import SentimentAnalyzer

from src.trading.risk_manager import RiskManager
from src.trading.paper_cex import PaperCEXSimulator
from src.trading.paper_dex import PaperDEXSimulator
from src.trading.strategy_executor import StrategyExecutor

from src.bot.charts import generate_mini_chart
from src.main import SentinelApplication


class TestCardanoMidnightSentinel(unittest.IsolatedAsyncioTestCase):

    async def asyncSetUp(self):
        await init_db()

    async def test_01_database_operations(self):
        """Test database connection, insertion and query"""
        async with get_session() as session:
            test_candle = Candle(
                exchange="binance",
                symbol="ADA/USDT",
                timeframe="1h",
                timestamp=datetime.now(timezone.utc),
                open=0.85,
                high=0.87,
                low=0.84,
                close=0.86,
                volume=1500000.0,
            )
            session.add(test_candle)

        # Verify query
        async with get_session() as session:
            from sqlalchemy import select
            result = await session.execute(select(Candle).filter_by(symbol="ADA/USDT"))
            candles = result.scalars().all()
            self.assertGreaterEqual(len(candles), 1)
            self.assertEqual(candles[-1].exchange, "binance")

    async def test_02_cex_collector(self):
        """Test CEX Collector OHLCV fetching and ticker"""
        collector = CEXCollector(primary_exchange="binance")
        candles = await collector.fetch_ohlcv("ADA/USDT", timeframe="1h", limit=20)
        await collector.close()

        self.assertIsInstance(candles, list)
        self.assertGreater(len(candles), 0, "Should successfully fetch ADA/USDT candles from CEX")
        self.assertIn("close", candles[0])
        self.assertIn("volume", candles[0])

    async def test_03_cardano_and_dex_collectors(self):
        """Test Cardano on-chain tip and DEX pool reserves"""
        cardano_col = CardanoCollector()
        block_info = await cardano_col.get_latest_block()
        self.assertIn("block_no", block_info)
        self.assertGreater(block_info["block_no"], 0)

        dex_col = DEXCollector()
        reserves = await dex_col.fetch_pool_reserves("NIGHT/ADA")
        self.assertIn("price", reserves)
        self.assertIn("reserve_base", reserves)
        self.assertIn("reserve_quote", reserves)
        self.assertGreater(reserves["price"], 0.0)

        # Test AMM slippage calculation
        amm_calc = dex_col.calculate_amm_slippage(
            reserve_in=2_500_000.0,
            reserve_out=2_500_000.0 * 0.125,
            amount_in=1000.0,
        )
        self.assertGreater(amm_calc["amount_out"], 0.0)
        self.assertGreaterEqual(amm_calc["slippage_pct"], 0.0)

    async def test_04_news_and_sentiment(self):
        """Test News Collector and Sentiment Analyzer"""
        news_col = NewsCollector()
        headlines = await news_col.get_latest_headlines()
        self.assertIsInstance(headlines, list)
        self.assertGreater(len(headlines), 0)

        analyzer = SentimentAnalyzer()
        res = await analyzer.analyze_headlines(headlines)
        self.assertIn("sentiment_score", res)
        self.assertIn("summary", res)
        self.assertTrue(-1.0 <= res["sentiment_score"] <= 1.0)

    def test_05_ai_feature_engineering_and_lead_lag(self):
        """Test technical features calculation and NIGHT Cross-market Lead-Lag feature"""
        # Create dummy OHLCV series
        np.random.seed(42)
        n = 30
        prices = np.cumprod(1 + np.random.normal(0, 0.01, n)) * 0.85
        df = pd.DataFrame({
            "open": prices * 0.99,
            "high": prices * 1.01,
            "low": prices * 0.98,
            "close": prices,
            "volume": np.random.uniform(50000, 200000, n),
        })

        feats = FeatureExtractor.calculate_technical_features(df)
        self.assertIn("rsi_14", feats.columns)
        self.assertIn("macd", feats.columns)
        self.assertIn("atr_14", feats.columns)
        self.assertIn("trend_bias", feats.columns)

        # Test Lead-Lag
        night_prices = np.cumprod(1 + np.random.normal(0, 0.02, n)) * 0.10
        df_night = pd.DataFrame({
            "close": night_prices,
            "volume": np.random.uniform(100000, 300000, n),
        })
        lead_lag = FeatureExtractor.calculate_lead_lag_features(
            cex_night_df=df_night,
            cex_ada_df=df,
            dex_night_ada_price=0.125,
        )
        self.assertIn("night_cex_velocity_1h", lead_lag)
        self.assertIn("arbitrage_spread_pct", lead_lag)
        self.assertIn("lead_signal", lead_lag)

    def test_06_whale_anomaly_detection(self):
        """Test Isolation Forest whale anomaly detector"""
        detector = WhaleAnomalyDetector()
        normal_tx = detector.detect_anomaly(amount=15_000.0, tx_frequency=1)
        self.assertEqual(normal_tx["is_anomaly"], False)

        whale_tx = detector.detect_anomaly(amount=2_500_000.0, tx_frequency=10, pool_impact_pct=3.5)
        self.assertEqual(whale_tx["is_anomaly"], True)
        self.assertIn(whale_tx["level"], ["HIGH", "CRITICAL"])

    def test_07_price_predictor_and_signal_generation(self):
        """Test LightGBM / GradientBoosting signal generator"""
        predictor = PricePredictor()
        np.random.seed(42)
        n = 25
        df = pd.DataFrame({
            "open": [0.80 + i * 0.005 for i in range(n)],
            "high": [0.82 + i * 0.005 for i in range(n)],
            "low": [0.79 + i * 0.005 for i in range(n)],
            "close": [0.81 + i * 0.005 for i in range(n)],
            "volume": [100000.0] * n,
        })
        signal = predictor.generate_signal(
            asset="ADA/USDT",
            market_type="CEX",
            df=df,
            sentiment_score=0.45,
            whale_inflow=600_000.0,
        )
        self.assertIn("signal_id", signal)
        self.assertIn("action", signal)
        self.assertIn("confidence_score", signal)
        self.assertIn("suggested_params", signal)
        self.assertGreater(signal["suggested_params"]["entry_price"], 0)
        self.assertGreater(signal["suggested_params"]["stop_loss"], 0)
        self.assertGreater(signal["suggested_params"]["take_profit"], 0)

    def test_08_risk_manager_and_circuit_breaker(self):
        """Test Kelly Criterion position sizing and Circuit Breaker"""
        rm = RiskManager()
        # Normal position sizing
        sizing = rm.calculate_position_size(
            capital=10000.0,
            entry_price=0.85,
            stop_loss=0.82,
            confidence_score=0.80,
        )
        self.assertTrue(sizing["allowed"])
        self.assertGreater(sizing["quantity"], 0)
        self.assertLessEqual(sizing["cost_basis"], 2500.0)  # Capped at 25% NAV

        # Test Circuit Breaker trigger (Drawdown > 5%)
        is_breaker, msg = rm.check_circuit_breaker(current_nav=9400.0, peak_nav_24h=10000.0)
        self.assertTrue(is_breaker)
        self.assertTrue(rm.is_circuit_breaker_active)

        # Blocked when breaker is active
        sizing_blocked = rm.calculate_position_size(10000.0, 0.85, 0.82)
        self.assertFalse(sizing_blocked["allowed"])

    def test_09_paper_cex_simulator(self):
        """Test CEX Paper Trading simulator execution and TP/SL close"""
        cex = PaperCEXSimulator()
        init_usdt = cex.usdt_balance

        # Buy order
        res = cex.execute_order(
            symbol="ADA/USDT",
            side="BUY",
            price=0.85,
            quantity=1000.0,
            stop_loss=0.80,
            take_profit=0.95,
        )
        self.assertTrue(res["success"])
        trade = res["trade"]
        self.assertEqual(trade["status"], "OPEN")
        self.assertGreater(trade["fee_paid"], 0.0)
        self.assertGreater(cex.holdings["ADA"], 0.0)
        self.assertLess(cex.usdt_balance, init_usdt)

        # Test Take-Profit trigger
        closed = cex.check_open_positions({"ADA/USDT": 0.96})
        self.assertEqual(len(closed), 1)
        self.assertEqual(closed[0]["close_reason"], "TAKE_PROFIT")
        self.assertGreater(closed[0]["pnl"], 0.0)
        self.assertEqual(len(cex.open_trades), 0)

    async def test_10_paper_dex_simulator(self):
        """Test Cardano DEX Paper Trading simulator with batcher & tx fees"""
        dex = PaperDEXSimulator()
        init_ada = dex.ada_balance

        # Swap ADA to NIGHT
        res = await dex.execute_swap(
            pair="NIGHT/ADA",
            side="BUY",
            amount_in=500.0,
            pool_reserves={"reserve_base": 2_500_000.0, "reserve_quote": 312_500.0},
            stop_loss=0.10,
            take_profit=0.20,
        )
        self.assertTrue(res["success"])
        trade = res["trade"]
        self.assertEqual(trade["status"], "OPEN")
        self.assertEqual(trade["fee_paid"], 2.20)  # 2.0 Batcher + 0.20 Network
        self.assertGreater(dex.night_balance, 0.0)
        self.assertLess(dex.ada_balance, init_ada - 500.0)

        # Test Stop-Loss trigger
        closed = dex.check_open_positions({"NIGHT/ADA": 0.09})
        self.assertEqual(len(closed), 1)
        self.assertEqual(closed[0]["close_reason"], "STOP_LOSS")
        self.assertEqual(len(dex.open_positions), 0)

    async def test_11_strategy_executor_end_to_end(self):
        """Test central StrategyExecutor processing signal and saving to DB"""
        executor = StrategyExecutor()
        signal = {
            "signal_id": f"sig_test_{int(datetime.now().timestamp())}",
            "asset": "ADA/USDT",
            "market_type": "CEX",
            "action": "BUY",
            "confidence_score": 0.85,
            "reasoning": {"summary": "Strong technical breakout with whale accumulation", "technical_score": 0.8, "sentiment_score": 0.5},
            "suggested_params": {
                "entry_price": 0.85,
                "stop_loss": 0.81,
                "take_profit": 0.93,
                "position_size_pct": 1.5,
            }
        }
        res = await executor.process_signal(signal, market_data={})
        self.assertEqual(res["status"], "EXECUTED")
        self.assertIn("trade", res)

    def test_12_chart_generator(self):
        """Test mini chart generation"""
        candles = [
            {"close": 0.80 + i * 0.01} for i in range(20)
        ]
        chart_path = generate_mini_chart(
            candles=candles,
            symbol="ADA/USDT",
            action="BUY",
            entry_price=0.85,
            stop_loss=0.82,
            take_profit=0.92,
        )
        self.assertIsNotNone(chart_path)
        self.assertTrue(os.path.exists(chart_path))

    async def test_13_sentinel_full_market_cycle(self):
        """Test running a complete Sentinel Market Cycle"""
        app = SentinelApplication()
        await app.initialize()
        await app.run_market_cycle()
        await app.shutdown()

    def test_14_dynamic_settings_update(self):
        """Test updating risk and trading settings dynamically via /set and /settings"""
        rm = RiskManager()
        # Test updating risk
        ok, msg = rm.update_setting("risk", 2.0)
        self.assertTrue(ok)
        self.assertEqual(rm.max_risk_pct, 2.0)

        # Test updating SL & TP
        ok, msg = rm.update_setting("sl", 1.8)
        self.assertTrue(ok)
        self.assertEqual(rm.atr_sl_multiplier, 1.8)

        ok, msg = rm.update_setting("tp", 3.0)
        self.assertTrue(ok)
        self.assertEqual(rm.tp_rr_ratio, 3.0)

        # Test updating mode
        ok, msg = rm.update_setting("mode", "alert_only")
        self.assertTrue(ok)
        self.assertEqual(rm.bot_mode, "alert_only")

        # Test invalid setting
        ok, msg = rm.update_setting("risk", -5)
        self.assertFalse(ok)

        all_s = rm.get_all_settings()
        self.assertEqual(all_s["max_risk_pct"], 2.0)
        self.assertEqual(all_s["bot_mode"], "alert_only")

    async def test_15_manual_order_execution_and_categorized_pnl(self):
        """Test manual /buy on CEX and DEX, categorized PnL display, and manual close"""
        executor = StrategyExecutor()

        # 1. Manual Buy on CEX
        res_cex = await executor.execute_manual_trade(
            symbol="ADA/USDT",
            side="BUY",
            amount=500.0,
            market_type="CEX",
            current_price=0.85,
        )
        self.assertEqual(res_cex["status"], "EXECUTED")
        cex_trade = res_cex["trade"]
        self.assertEqual(cex_trade["market_type"], "CEX")

        # 2. Manual Buy on DEX
        res_dex = await executor.execute_manual_trade(
            symbol="NIGHT/ADA",
            side="BUY",
            amount=200.0,
            market_type="DEX",
            current_price=0.125,
        )
        self.assertEqual(res_dex["status"], "EXECUTED")
        dex_trade = res_dex["trade"]
        self.assertEqual(dex_trade["market_type"], "DEX")

        # 3. Check categorized PnL separation
        categorized = executor.get_open_positions_categorized({"ADA/USDT": 0.86, "NIGHT/ADA": 0.13})
        self.assertEqual(len(categorized["cex"]), 1)
        self.assertEqual(len(categorized["dex"]), 1)
        self.assertEqual(categorized["cex"][0]["asset"], "ADA/USDT")
        self.assertEqual(categorized["dex"][0]["asset"], "NIGHT/ADA")

        # 4. Close single trade
        ok, close_msg = executor.close_single_trade(cex_trade["trade_id"], current_price=0.86)
        self.assertTrue(ok)
        self.assertEqual(len(executor.cex_sim.open_trades), 0)

        # 5. Close all remaining trades
        close_all_msgs = executor.close_all_trades({"NIGHT/ADA": 0.13})
        self.assertEqual(len(close_all_msgs), 1)
        self.assertEqual(len(executor.dex_sim.open_positions), 0)

    async def test_16_arbitrage_spam_filter(self):
        """Test that Arbitrage Spam Filter suppresses alerts unless spread changes significantly or time elapses"""
        app = SentinelApplication()
        app.last_arbitrage_alert_time = datetime.now(timezone.utc)
        app.last_arbitrage_spread = 150.0

        # Small change (151.0% vs 150.0%) within 15 minutes -> should NOT alert
        now = datetime.now(timezone.utc)
        delta = abs(151.0 - app.last_arbitrage_spread)
        elapsed = (now - app.last_arbitrage_alert_time).total_seconds()
        should_alert = elapsed >= 900 or delta >= 5.0
        self.assertFalse(should_alert, "Spam filter should suppress minor spread changes")

        # Big change (156.0% vs 150.0% => delta 6%) -> should alert
        delta_big = abs(156.0 - app.last_arbitrage_spread)
        should_alert_big = elapsed >= 900 or delta_big >= 5.0
        self.assertTrue(should_alert_big, "Spam filter should allow significant spread changes")

    def test_17_usd_parity_calculation(self):
        """Test standardized USD parity calculation between CEX and DEX"""
        parity = FeatureExtractor.calculate_usd_parity(
            cex_night_usd=0.10,
            cex_ada_usd=0.85,
            dex_night_ada_ratio=0.125,  # 1 NIGHT = 0.125 ADA
        )
        # DEX NIGHT in USD = 0.125 * 0.85 = 0.10625 USD
        self.assertAlmostEqual(parity["cex_night_usd"], 0.10, places=4)
        self.assertAlmostEqual(parity["dex_night_usd"], 0.10625, places=4)
        self.assertEqual(parity["cheaper_market"], "CEX")

    def test_18_night_ada_ratio_accumulation(self):
        """Test Pair Trading / Ratio Accumulation Engine (Z-score + Bollinger Bands + RSI on ratio)"""
        n = 25
        night_prices = [0.10 - i * 0.002 for i in range(n)]  # Dropping
        ada_prices = [0.85 + i * 0.002 for i in range(n)]    # Rising
        df_night = pd.DataFrame({"close": night_prices})
        df_ada = pd.DataFrame({"close": ada_prices})

        analysis = FeatureExtractor.calculate_night_ada_ratio_analysis(
            cex_night_df=df_night,
            cex_ada_df=df_ada,
            dex_night_ada_price=0.03,  # Deep bottom ratio
        )
        self.assertIn("current_ratio", analysis)
        self.assertIn("inv_ratio", analysis)
        self.assertIn("z_score", analysis)
        self.assertIn("action", analysis)
        self.assertEqual(analysis["action"], "ACCUMULATE_NIGHT")
        self.assertLessEqual(analysis["z_score"], -1.5)
        self.assertIn("🟢 ĐIỂM ĐẸP TÍCH LŨY NIGHT", analysis["recommendation"])


if __name__ == "__main__":
    unittest.main()

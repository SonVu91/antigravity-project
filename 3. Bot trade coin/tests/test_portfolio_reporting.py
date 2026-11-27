import os
import unittest
import asyncio
from datetime import datetime, timezone

# Use isolated test database so production sentinel.db is never polluted
os.environ["DATABASE_URL"] = "sqlite+aiosqlite:///./data/test_sentinel.db"

from src.database.db_session import init_db, get_session
from src.database.models import PaperTrade, PortfolioBalance
from src.trading.strategy_executor import StrategyExecutor
from src.trading.portfolio_reporter import PortfolioReporter


class TestPortfolioReporting(unittest.TestCase):
    def setUp(self):
        self.loop = asyncio.new_event_loop()
        asyncio.set_event_loop(self.loop)
        async def clean():
            await init_db()
            async with get_session() as session:
                from sqlalchemy import text
                await session.execute(text("DELETE FROM paper_trades"))
                await session.execute(text("DELETE FROM portfolio_balances"))
        self.loop.run_until_complete(clean())
        self.executor = StrategyExecutor()
        self.reporter = PortfolioReporter(self.executor)

    def tearDown(self):
        self.loop.close()

    def test_01_initial_portfolio_summary(self):
        """Test initial portfolio summary with default balances"""
        summary = self.loop.run_until_complete(self.reporter.get_portfolio_summary())

        # CEX initial: 10,000 USDT
        self.assertEqual(summary["cex"]["usdt_available"], 10000.0)
        self.assertEqual(summary["cex"]["ada_holding"], 0.0)
        self.assertEqual(summary["cex"]["night_holding"], 0.0)
        self.assertEqual(summary["cex"]["nav_usdt"], 10000.0)

        # DEX initial: 10,000 ADA
        self.assertEqual(summary["dex"]["ada_available"], 10000.0)
        self.assertEqual(summary["dex"]["night_holding"], 0.0)
        self.assertEqual(summary["dex"]["nav_ada"], 10000.0)
        # 10,000 ADA * 0.150 USD = 1,500 USD
        self.assertEqual(summary["dex"]["nav_usd"], 1500.0)

        # Combined Total NAV: 10,000 + 1,500 = 11,500 USD
        self.assertEqual(summary["combined"]["total_nav_usd"], 11500.0)

    def test_02_format_telegram_report_on_execute(self):
        """Test formatting report after executing a manual trade"""
        res = self.loop.run_until_complete(
            self.executor.execute_manual_trade("ADA/USDT", side="BUY", amount=1000.0)
        )
        self.assertEqual(res["status"], "EXECUTED")
        trade = res["trade"]

        report = self.loop.run_until_complete(
            self.reporter.format_telegram_report(trigger_type="EXECUTE", trade_info=trade)
        )

        self.assertIn("📊 *TỔNG QUAN TÀI SẢN & HIỆU SUẤT*", report)
        self.assertIn("🏦 *CEX:*", report)
        self.assertIn("1,000.0 ADA", report)  # Coin holding breakdown
        self.assertIn("🥞 *Cardano DEX:*", report)
        self.assertIn("🌐 *Tổng NAV hợp nhất:*", report)
        self.assertIn("⏳ *PnL tạm tính (Unrealized):*", report)
        self.assertIn("🎯 *Lãi/Lỗ đã chốt (Realized):*", report)

    def test_03_format_telegram_report_on_close(self):
        """Test formatting report when closing a position"""
        # 1. Open trade
        res = self.loop.run_until_complete(
            self.executor.execute_manual_trade("ADA/USDT", side="BUY", amount=500.0)
        )
        trade = res["trade"]

        # 2. Close trade at profit
        ok, msg = self.executor.close_single_trade(trade["trade_id"], current_price=1.00)
        self.assertTrue(ok)
        closed_trade = self.executor.last_closed_trade
        self.assertIsNotNone(closed_trade)
        self.assertGreater(closed_trade["pnl"], 0)

        # Sync to DB
        self.loop.run_until_complete(self.reporter.record_closed_trade_in_db(closed_trade))

        report = self.loop.run_until_complete(
            self.reporter.format_telegram_report(trigger_type="CLOSE", trade_info=closed_trade)
        )

        self.assertIn("Lệnh vừa chốt", report)
        self.assertIn("Win Rate:", report)
        self.assertIn("W - ", report)

    def test_04_database_balances_sync(self):
        """Test synchronizing balances to portfolio_balances DB table"""
        self.loop.run_until_complete(
            self.executor.execute_manual_trade("ADA/USDT", side="BUY", amount=200.0)
        )
        self.loop.run_until_complete(self.reporter.sync_database())

        async def check_db():
            async with get_session() as session:
                from sqlalchemy import select
                stmt = select(PortfolioBalance)
                res = await session.execute(stmt)
                records = res.scalars().all()
                self.assertGreaterEqual(len(records), 5)
                currencies = {r.currency: r.total_balance for r in records if r.account_type == "CEX"}
                self.assertEqual(currencies["ADA"], 200.0)

        self.loop.run_until_complete(check_db())

    def test_05_btc_holdings_and_nav_accuracy(self):
        """Test buying BTC, ensuring it appears under Giữ (Holdings) and NAV is fully valued"""
        # Execute manual BTC buy
        res = self.loop.run_until_complete(
            self.executor.execute_manual_trade(
                symbol="BTC/USDT",
                side="BUY",
                amount=0.02,
                current_price=60000.0,
            )
        )
        self.assertEqual(res["status"], "EXECUTED")
        self.assertAlmostEqual(self.executor.cex_sim.holdings.get("BTC", 0.0), 0.02, places=4)

        current_prices = {"BTC/USDT": 60000.0, "ADA/USDT": 0.85, "NIGHT/ADA": 0.125}
        summary = self.loop.run_until_complete(self.reporter.get_portfolio_summary(current_prices))

        # CEX NAV must reflect free cash + 0.02 * 60,000 (~1,200 USDT)
        self.assertIn("0.02", summary["cex"]["holdings_str"])
        self.assertIn("BTC", summary["cex"]["holdings_str"])
        # Free USDT cash is ~8,799 USDT + 1,200 BTC value = ~9,999 USDT (minus fee)
        self.assertGreater(summary["cex"]["nav_usdt"], 9990.0)

        report = self.loop.run_until_complete(
            self.reporter.format_telegram_report(trigger_type="EXECUTE", trade_info=res["trade"], current_prices=current_prices)
        )
        self.assertIn("0.02", report)
        self.assertIn("BTC", report)
        self.assertNotIn("0.0 ADA", report)  # Unheld assets are hidden

    def test_06_detailed_orders_report(self):
        """Test detailed orders book card formatting and action buttons"""
        # Open BTC position
        self.loop.run_until_complete(
            self.executor.execute_manual_trade(
                symbol="BTC/USDT",
                side="BUY",
                amount=0.02,
                current_price=60000.0,
            )
        )
        # Price increases to 61,000 -> Unrealized profit with slippage = (61,000 - 60,030) * 0.02 = +$19.40
        current_prices = {"BTC/USDT": 61000.0, "ADA/USDT": 0.85}
        msg, keyboard = self.executor.format_detailed_orders_report(current_prices)

        self.assertIn("SỔ LỆNH CHI TIẾT CÁC VỊ THẾ ĐANG CHẠY", msg)
        self.assertIn("BTC/USDT", msg)
        self.assertIn("0.0200 BTC", msg)
        self.assertIn("+$19.40", msg)
        self.assertIn("🟢", msg)

        # Check action buttons
        btn_texts = [btn.text for row in keyboard for btn in row]
        self.assertTrue(any("Đóng #1 BTC/USDT" in t for t in btn_texts))
        self.assertTrue(any("ĐÓNG TẤT CẢ VỊ THẾ" in t for t in btn_texts))
        self.assertTrue(any("LÀM MỚI SỔ LỆNH" in t for t in btn_texts))


if __name__ == "__main__":
    unittest.main()

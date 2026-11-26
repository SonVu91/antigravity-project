import unittest
import asyncio
from datetime import datetime, timezone
from src.database.db_session import init_db, get_session
from src.database.models import PaperTrade, PortfolioBalance
from src.trading.strategy_executor import StrategyExecutor
from src.trading.portfolio_reporter import PortfolioReporter


class TestPortfolioReporting(unittest.TestCase):
    def setUp(self):
        self.loop = asyncio.new_event_loop()
        asyncio.set_event_loop(self.loop)
        self.loop.run_until_complete(init_db())
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
        # 10,000 ADA * 0.85 USD = 8,500 USD
        self.assertEqual(summary["dex"]["nav_usd"], 8500.0)

        # Combined Total NAV: 10,000 + 8,500 = 18,500 USD
        self.assertEqual(summary["combined"]["total_nav_usd"], 18500.0)

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
        self.assertIn("1W - 0L", report)

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


if __name__ == "__main__":
    unittest.main()

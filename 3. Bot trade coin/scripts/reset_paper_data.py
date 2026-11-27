import asyncio
import logging
from datetime import datetime, timezone
from sqlalchemy import text
from config.settings import settings
from src.database.db_session import get_session
from src.database.models import PortfolioBalance, PaperTrade

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("ResetPaperData")


async def reset_paper_trading_data():
    """Reset all paper trades and balances to a clean initial state"""
    async with get_session() as session:
        # 1. Delete all old paper trades
        await session.execute(text("DELETE FROM paper_trades"))
        await session.execute(text("DELETE FROM portfolio_balances"))

        # 2. Insert clean initial balances
        now = datetime.now(timezone.utc)
        initial_balances = [
            PortfolioBalance(account_type="CEX", currency="USDT", total_balance=settings.PAPER_INITIAL_USDT, available_balance=settings.PAPER_INITIAL_USDT, locked_balance=0.0, updated_at=now),
            PortfolioBalance(account_type="DEX", currency="ADA", total_balance=settings.PAPER_INITIAL_ADA, available_balance=settings.PAPER_INITIAL_ADA, locked_balance=0.0, updated_at=now),
            PortfolioBalance(account_type="DEX", currency="NIGHT", total_balance=0.0, available_balance=0.0, locked_balance=0.0, updated_at=now),
        ]
        session.add_all(initial_balances)
        await session.commit()
        logger.info(f"✅ Đã đặt lại dữ liệu Paper Trading về trạng thái ban đầu sạch sẽ: ${settings.PAPER_INITIAL_USDT:,.0f} USDT (CEX), {settings.PAPER_INITIAL_ADA:,.0f} ADA (DEX), 0 lệnh cũ.")


if __name__ == "__main__":
    asyncio.run(reset_paper_trading_data())

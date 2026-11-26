import logging
from datetime import datetime, timezone
from typing import Dict, Any, Optional, List
from sqlalchemy import select, update
from config.settings import settings
from src.database.db_session import get_session
from src.database.models import PaperTrade, PortfolioBalance

logger = logging.getLogger("PortfolioReporter")


class PortfolioReporter:
    """
    Centralized Portfolio and Performance Reporter.
    Provides:
    - Accurate asset valuation across CEX (USDT) and Cardano DEX (ADA)
    - Total Combined NAV unified in USD
    - Detailed coin holdings breakdown (ADA, NIGHT, USDT)
    - Realized PnL, Unrealized PnL, and Win Rate calculation
    - Real-time synchronization to SQLite/PostgreSQL Database
    - Standardized Markdown reports for Telegram alerts
    """

    def __init__(self, strategy_executor):
        self.executor = strategy_executor

    async def get_portfolio_summary(
        self,
        current_prices: Optional[Dict[str, float]] = None,
    ) -> Dict[str, Any]:
        """
        Aggregate full financial state across CEX, DEX, and Database records.
        """
        prices = dict(current_prices or {})
        ada_usd = prices.get(settings.CEX_ADA_PAIR, prices.get("ADA/USDT", 0.85))
        night_ada = prices.get(settings.DEX_NIGHT_PAIR, prices.get("NIGHT/ADA", 0.125))
        night_usd = prices.get(settings.CEX_NIGHT_PAIR, prices.get("NIGHT/USDT", night_ada * ada_usd))

        full_prices = {
            "ADA/USDT": ada_usd,
            "NIGHT/USDT": night_usd,
            "NIGHT/ADA": night_ada,
            settings.CEX_ADA_PAIR: ada_usd,
            settings.CEX_NIGHT_PAIR: night_usd,
            settings.DEX_NIGHT_PAIR: night_ada,
        }
        full_prices.update(prices)

        cex = self.executor.cex_sim
        dex = self.executor.dex_sim

        # Ensure full_prices has pricing for all coins currently held
        for asset in cex.holdings.keys():
            sym = f"{asset}/USDT"
            if sym not in full_prices:
                for t in cex.open_trades.values():
                    if t.get("asset") == sym or t.get("asset") == asset:
                        full_prices[sym] = t.get("entry_price", 0.0)
                        break

        # 1. CEX Assets & Dynamic Holdings
        cex_usdt_avail = cex.usdt_balance
        cex_nav_usdt = cex.get_portfolio_nav(full_prices)

        cex_holdings_display = []
        for asset, qty in sorted(cex.holdings.items()):
            if qty > 1e-6:
                if qty == int(qty):
                    cex_holdings_display.append(f"{qty:,.1f} {asset}")
                elif qty >= 1.0:
                    cex_holdings_display.append(f"{qty:,.2f} {asset}")
                else:
                    cex_holdings_display.append(f"{qty:.4f} {asset}")
        cex_holdings_str = ", ".join(cex_holdings_display) if cex_holdings_display else "Trống"

        # 2. DEX Assets
        dex_ada_avail = dex.ada_balance
        dex_night_holding = dex.night_balance
        dex_nav_ada = dex.get_portfolio_nav_in_ada({"NIGHT/ADA": night_ada})
        dex_nav_usd = dex_nav_ada * ada_usd

        dex_holdings_display = []
        if dex_night_holding > 1e-4:
            dex_holdings_display.append(f"{dex_night_holding:,.0f} NIGHT")
        dex_holdings_str = ", ".join(dex_holdings_display) if dex_holdings_display else "Trống"

        # 3. Total Combined Portfolio Value
        total_nav_usd = cex_nav_usdt + dex_nav_usd

        # 4. Open positions & Unrealized PnL
        open_pos = self.executor.get_open_positions_categorized(full_prices)
        cex_open = open_pos.get("cex", [])
        dex_open = open_pos.get("dex", [])

        unrealized_cex_usdt = sum(t.get("unrealized_pnl", 0.0) for t in cex_open)
        unrealized_dex_ada = sum(t.get("unrealized_pnl", 0.0) for t in dex_open)
        unrealized_usd = unrealized_cex_usdt + (unrealized_dex_ada * ada_usd)

        total_open_cost_usd = sum(t.get("cost_basis", 0.0) for t in cex_open) + (
            sum(t.get("cost_basis", 0.0) for t in dex_open) * ada_usd
        )
        unrealized_pct = (
            (unrealized_usd / total_open_cost_usd) * 100.0 if total_open_cost_usd > 0 else 0.0
        )

        # 5. Database performance history (Realized PnL & Win Rate)
        win_count = 0
        loss_count = 0
        total_closed = 0
        realized_cex_usdt = 0.0
        realized_dex_ada = 0.0

        try:
            async with get_session() as session:
                stmt = select(PaperTrade).where(PaperTrade.status == "CLOSED")
                result = await session.execute(stmt)
                closed_trades = result.scalars().all()

                total_closed = len(closed_trades)
                for t in closed_trades:
                    pnl = t.pnl or 0.0
                    if pnl > 0:
                        win_count += 1
                    elif pnl < 0:
                        loss_count += 1

                    if t.market_type == "CEX":
                        realized_cex_usdt += pnl
                    else:
                        realized_dex_ada += pnl
        except Exception as e:
            logger.warning(f"Không thể đọc lịch sử paper_trades từ DB: {e}")

        realized_usd = realized_cex_usdt + (realized_dex_ada * ada_usd)
        win_rate = (win_count / total_closed * 100.0) if total_closed > 0 else 0.0

        return {
            "ada_usd_price": ada_usd,
            "night_ada_price": night_ada,
            "cex": {
                "usdt_available": cex_usdt_avail,
                "ada_holding": cex.holdings.get("ADA", 0.0),
                "night_holding": cex.holdings.get("NIGHT", 0.0),
                "holdings_str": cex_holdings_str,
                "holdings": dict(cex.holdings),
                "nav_usdt": cex_nav_usdt,
                "open_count": len(cex_open),
                "unrealized_usdt": unrealized_cex_usdt,
                "realized_usdt": realized_cex_usdt,
            },
            "dex": {
                "ada_available": dex_ada_avail,
                "holdings_str": dex_holdings_str,
                "night_holding": dex_night_holding,
                "nav_ada": dex_nav_ada,
                "nav_usd": dex_nav_usd,
                "open_count": len(dex_open),
                "unrealized_ada": unrealized_dex_ada,
                "realized_ada": realized_dex_ada,
            },
            "combined": {
                "total_nav_usd": total_nav_usd,
                "unrealized_usd": unrealized_usd,
                "unrealized_pct": unrealized_pct,
                "realized_usd": realized_usd,
                "win_rate": win_rate,
                "win_count": win_count,
                "loss_count": loss_count,
                "total_closed": total_closed,
            },
        }

    async def format_telegram_report(
        self,
        trigger_type: str = "EXECUTE",
        trade_info: Optional[Dict[str, Any]] = None,
        current_prices: Optional[Dict[str, float]] = None,
    ) -> str:
        """
        Build standardized Markdown portfolio and performance section for Telegram messages.
        """
        summary = await self.get_portfolio_summary(current_prices)
        cex = summary["cex"]
        dex = summary["dex"]
        comb = summary["combined"]

        lines = [
            "───────────────────────",
            "📊 *TỔNG QUAN TÀI SẢN & HIỆU SUẤT*",
        ]

        # Specific closed trade highlight if closing
        if trigger_type == "CLOSE" and trade_info:
            pnl_val = trade_info.get("pnl", 0.0)
            pnl_pct = trade_info.get("pnl_pct", 0.0)
            unit = "ADA" if trade_info.get("market_type") == "DEX" else "USDT"
            pnl_icon = "🟢" if pnl_val >= 0 else "🔴"
            reason = trade_info.get("close_reason", "MANUAL")
            lines.append(
                f"{pnl_icon} *Lệnh vừa chốt ({reason}):* `{pnl_val:+,.2f} {unit}` (`{pnl_pct:+.2f}%`)"
            )

        # CEX overview
        lines.append(
            f"• 🏦 *CEX:* `${cex['nav_usdt']:,.2f} USDT` "
            f"(Rảnh: `${cex['usdt_available']:,.2f}` | Giữ: `{cex['holdings_str']}`)"
        )

        # Cardano DEX overview
        lines.append(
            f"• 🥞 *Cardano DEX:* `{dex['nav_ada']:,.2f} ADA` (~`${dex['nav_usd']:,.2f}`) "
            f"(Rảnh: `{dex['ada_available']:,.2f} ADA` | Giữ: `{dex['holdings_str']}`)"
        )

        # Combined Total NAV
        lines.append(f"• 🌐 *Tổng NAV hợp nhất:* `${comb['total_nav_usd']:,.2f} USD`")

        # PnL stats
        unrealized_sign = "+" if comb["unrealized_usd"] >= 0 else ""
        lines.append(
            f"• ⏳ *PnL tạm tính (Unrealized):* `{unrealized_sign}${comb['unrealized_usd']:,.2f}` (`{comb['unrealized_pct']:+.2f}%`)"
        )

        realized_sign = "+" if comb["realized_usd"] >= 0 else ""
        lines.append(
            f"• 🎯 *Lãi/Lỗ đã chốt (Realized):* `{realized_sign}${comb['realized_usd']:,.2f}` | "
            f"Win Rate: `{comb['win_rate']:.1f}%` ({comb['win_count']}W - {comb['loss_count']}L)"
        )

        return "\n".join(lines)

    async def sync_database(self, current_prices: Optional[Dict[str, float]] = None) -> None:
        """
        Persist current CEX and DEX cash & coin balances into PortfolioBalance table.
        """
        cex = self.executor.cex_sim
        dex = self.executor.dex_sim
        now = datetime.now(timezone.utc)

        balances_to_sync = [
            ("CEX", "USDT", cex.usdt_balance, cex.usdt_balance, 0.0),
            ("DEX", "ADA", dex.ada_balance, dex.ada_balance, 0.0),
            ("DEX", "NIGHT", dex.night_balance, dex.night_balance, 0.0),
        ]
        # Dynamically record all non-USDT coins in CEX holdings
        for asset, qty in cex.holdings.items():
            if asset != "USDT":
                balances_to_sync.append(("CEX", asset, qty, qty, 0.0))

        try:
            async with get_session() as session:
                for acct, curr, total, avail, locked in balances_to_sync:
                    stmt = select(PortfolioBalance).where(
                        PortfolioBalance.account_type == acct,
                        PortfolioBalance.currency == curr,
                    )
                    res = await session.execute(stmt)
                    record = res.scalars().first()

                    if record:
                        record.total_balance = total
                        record.available_balance = avail
                        record.locked_balance = locked
                        record.updated_at = now
                    else:
                        new_record = PortfolioBalance(
                            account_type=acct,
                            currency=curr,
                            total_balance=total,
                            available_balance=avail,
                            locked_balance=locked,
                            updated_at=now,
                        )
                        session.add(new_record)
        except Exception as e:
            logger.warning(f"Lỗi khi đồng bộ portfolio_balances vào DB: {e}")

    async def record_closed_trade_in_db(self, trade: Dict[str, Any]) -> None:
        """
        Update closed trade information in paper_trades database table.
        """
        trade_id = trade.get("trade_id")
        if not trade_id:
            return

        now = trade.get("exit_time") or datetime.now(timezone.utc)
        pnl = trade.get("pnl", 0.0)
        pnl_pct = trade.get("pnl_pct", 0.0)
        exit_price = trade.get("exit_price", trade.get("entry_price", 0.0))
        reason = trade.get("close_reason", "MANUAL_CLOSE")

        try:
            async with get_session() as session:
                stmt = select(PaperTrade).where(PaperTrade.trade_id == trade_id)
                res = await session.execute(stmt)
                db_trade = res.scalars().first()

                if db_trade:
                    db_trade.exit_price = exit_price
                    db_trade.exit_time = now
                    db_trade.status = "CLOSED"
                    db_trade.pnl = pnl
                    db_trade.pnl_pct = pnl_pct
                    db_trade.close_reason = reason
                else:
                    # If not created before, create new closed record
                    new_trade = PaperTrade(
                        trade_id=trade_id,
                        market_type=trade.get("market_type", "CEX"),
                        asset=trade.get("asset", "ADA/USDT"),
                        side=trade.get("side", "BUY"),
                        entry_price=trade.get("entry_price", exit_price),
                        exit_price=exit_price,
                        quantity=trade.get("quantity", 0.0),
                        cost_basis=trade.get("cost_basis", 0.0),
                        stop_loss=trade.get("stop_loss", 0.0),
                        take_profit=trade.get("take_profit", 0.0),
                        fee_paid=trade.get("fee_paid", 0.0),
                        slippage=trade.get("slippage", 0.0),
                        pnl=pnl,
                        pnl_pct=pnl_pct,
                        status="CLOSED",
                        entry_time=trade.get("entry_time", now),
                        exit_time=now,
                        close_reason=reason,
                    )
                    session.add(new_trade)
        except Exception as e:
            logger.warning(f"Lỗi khi cập nhật paper_trade closed trong DB ({trade_id}): {e}")

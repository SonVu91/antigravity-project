import logging
import uuid
from datetime import datetime, timezone
from typing import Dict, Any, List, Optional
from config.settings import settings
from src.database.db_session import get_session
from src.database.models import PaperTrade, PortfolioBalance

logger = logging.getLogger("PaperCEX")


class PaperCEXSimulator:
    """
    Realistic Centralized Exchange (CEX) Paper Trading Simulator.
    Applies 0.075% Taker fee and orderbook-based slippage.
    """

    def __init__(self):
        self.usdt_balance = settings.PAPER_INITIAL_USDT
        self.holdings: Dict[str, float] = {
            "ADA": 0.0,
            "NIGHT": 0.0,
        }
        self.taker_fee_pct = settings.CEX_TAKER_FEE_PCT  # 0.075%
        self.open_trades: Dict[str, Dict[str, Any]] = {}

    def get_portfolio_nav(self, current_prices: Dict[str, float]) -> float:
        """Calculate total Net Asset Value (NAV) in USDT"""
        nav = self.usdt_balance
        for asset, qty in self.holdings.items():
            if qty <= 1e-6:
                continue
            price = current_prices.get(f"{asset}/USDT", current_prices.get(asset, 0.0))
            if price <= 0.0:
                # Fallback to entry_price of open trade for this asset
                for t in self.open_trades.values():
                    if t.get("asset", "").startswith(f"{asset}/"):
                        price = t.get("entry_price", 0.0)
                        break
            nav += qty * price
        return nav

    def execute_order(
        self,
        symbol: str,  # e.g., ADA/USDT or NIGHT/USDT
        side: str,    # BUY or SELL
        price: float,
        quantity: float,
        stop_loss: float,
        take_profit: float,
        orderbook_depth: Optional[Dict[str, Any]] = None,
    ) -> Dict[str, Any]:
        """
        Execute paper trade on CEX with fee and slippage modeling.
        """
        base_asset = symbol.split("/")[0]

        # Calculate realistic slippage (0.05% default + depth factor)
        slippage_pct = 0.0005  # 0.05%
        if orderbook_depth:
            # If large quantity, increase slippage slightly
            slippage_pct = min(0.003, 0.0005 + (quantity * price / 50000.0) * 0.0005)

        fill_price = price * (1.0 + slippage_pct) if side == "BUY" else price * (1.0 - slippage_pct)
        gross_cost = fill_price * quantity
        fee = gross_cost * self.taker_fee_pct

        trade_id = f"cex_{uuid.uuid4().hex[:10]}"

        if side == "BUY":
            total_required = gross_cost + fee
            if self.usdt_balance < total_required:
                return {
                    "success": False,
                    "error": f"Số dư USDT không đủ. Cần {total_required:.2f} USDT, hiện có {self.usdt_balance:.2f} USDT.",
                }

            self.usdt_balance -= total_required
            self.holdings[base_asset] = self.holdings.get(base_asset, 0.0) + quantity

            trade_record = {
                "trade_id": trade_id,
                "market_type": "CEX",
                "asset": symbol,
                "side": "BUY",
                "entry_price": round(fill_price, 4),
                "quantity": quantity,
                "cost_basis": round(gross_cost, 2),
                "stop_loss": round(stop_loss, 4),
                "take_profit": round(take_profit, 4),
                "fee_paid": round(fee, 4),
                "slippage": round(slippage_pct * 100.0, 3),
                "status": "OPEN",
                "entry_time": datetime.now(timezone.utc),
            }
            self.open_trades[trade_id] = trade_record
            return {"success": True, "trade": trade_record}

        elif side == "SELL":
            current_held = self.holdings.get(base_asset, 0.0)
            if current_held < quantity:
                return {
                    "success": False,
                    "error": f"Số lượng {base_asset} không đủ để bán. Cần {quantity}, hiện có {current_held}.",
                }

            net_revenue = gross_cost - fee
            self.holdings[base_asset] -= quantity
            self.usdt_balance += net_revenue

            trade_record = {
                "trade_id": trade_id,
                "market_type": "CEX",
                "asset": symbol,
                "side": "SELL",
                "entry_price": round(fill_price, 4),
                "quantity": quantity,
                "cost_basis": round(gross_cost, 2),
                "stop_loss": round(stop_loss, 4),
                "take_profit": round(take_profit, 4),
                "fee_paid": round(fee, 4),
                "slippage": round(slippage_pct * 100.0, 3),
                "status": "CLOSED",
                "entry_time": datetime.now(timezone.utc),
                "exit_time": datetime.now(timezone.utc),
            }
            return {"success": True, "trade": trade_record}

        return {"success": False, "error": f"Invalid side {side}"}

    def check_open_positions(self, current_prices: Dict[str, float]) -> List[Dict[str, Any]]:
        """
        Evaluate open positions against latest market prices for Take-Profit or Stop-Loss.
        """
        closed_trades = []
        for trade_id, trade in list(self.open_trades.items()):
            symbol = trade["asset"]
            cur_price = current_prices.get(symbol)
            if not cur_price:
                continue

            entry = trade["entry_price"]
            sl = trade["stop_loss"]
            tp = trade["take_profit"]
            qty = trade["quantity"]
            side = trade["side"]

            hit_reason = None
            if side == "BUY":
                if cur_price >= tp:
                    hit_reason = "TAKE_PROFIT"
                elif cur_price <= sl:
                    hit_reason = "STOP_LOSS"
            elif side == "SELL":
                if cur_price <= tp:
                    hit_reason = "TAKE_PROFIT"
                elif cur_price >= sl:
                    hit_reason = "STOP_LOSS"

            if hit_reason:
                # Close trade
                pnl = (cur_price - entry) * qty if side == "BUY" else (entry - cur_price) * qty
                fee = (cur_price * qty) * self.taker_fee_pct
                net_pnl = pnl - fee - trade["fee_paid"]
                pnl_pct = (net_pnl / trade["cost_basis"]) * 100.0

                base_asset = symbol.split("/")[0]
                self.holdings[base_asset] = max(0.0, self.holdings.get(base_asset, 0.0) - qty)
                self.usdt_balance += (cur_price * qty) - fee

                trade["exit_price"] = cur_price
                trade["exit_time"] = datetime.now(timezone.utc)
                trade["status"] = "CLOSED"
                trade["close_reason"] = hit_reason
                trade["pnl"] = round(net_pnl, 2)
                trade["pnl_pct"] = round(pnl_pct, 2)

                closed_trades.append(trade)
                del self.open_trades[trade_id]

        return closed_trades

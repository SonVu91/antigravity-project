import logging
import uuid
import asyncio
from datetime import datetime, timezone
from typing import Dict, Any, List, Optional
from config.settings import settings

logger = logging.getLogger("PaperDEX")


class PaperDEXSimulator:
    """
    High-Fidelity Cardano DEX Paper Trading Simulator.
    Models:
    - Fixed 2.0 ADA Batcher fee
    - Fixed 0.20 ADA Cardano network fee
    - 20-40 second eUTxO block confirmation delay
    - AMM Constant Product Slippage (x * y = k)
    """

    def __init__(self):
        self.ada_balance = settings.PAPER_INITIAL_ADA
        self.usdc_balance = 0.0
        self.night_balance = settings.PAPER_INITIAL_NIGHT
        self.batcher_fee_ada = settings.CARDANO_DEX_BATCHER_FEE_ADA  # 2.0 ADA
        self.network_fee_ada = settings.CARDANO_NETWORK_FEE_ADA      # 0.20 ADA
        self.open_positions: Dict[str, Dict[str, Any]] = {}

    def get_portfolio_nav_in_ada(self, current_prices_in_ada: Dict[str, float]) -> float:
        """Calculate total wallet portfolio value in ADA"""
        nav = self.ada_balance
        # USDC in ADA
        ada_usdc_price = current_prices_in_ada.get("ADA/USDC", 0.85)
        if ada_usdc_price > 0:
            nav += self.usdc_balance / ada_usdc_price
        # NIGHT in ADA
        night_ada_price = current_prices_in_ada.get("NIGHT/ADA", 0.125)
        nav += self.night_balance * night_ada_price
        return nav

    async def execute_swap(
        self,
        pair: str,              # NIGHT/ADA or ADA/USDC
        side: str,              # BUY (spend ADA to get NIGHT) or SELL (spend NIGHT to get ADA)
        amount_in: float,
        pool_reserves: Dict[str, Any],
        stop_loss: float,
        take_profit: float,
        simulate_delay: bool = False,
    ) -> Dict[str, Any]:
        """
        Execute AMM swap on Cardano DEX.
        Deducts batcher fee + network fee and computes AMM slippage.
        """
        total_fee_ada = self.batcher_fee_ada + self.network_fee_ada

        if self.ada_balance < total_fee_ada:
            return {
                "success": False,
                "error": f"Ví Cardano không đủ {total_fee_ada} ADA để trả phí mạng và Batcher.",
            }

        # Deduct transaction fees
        self.ada_balance -= total_fee_ada

        # Constant Product AMM calculation
        reserve_in = pool_reserves.get("reserve_quote", 2_500_000.0)
        reserve_out = pool_reserves.get("reserve_base", 2_500_000.0)
        fee_factor = 0.997  # 0.3% pool fee

        amount_in_with_fee = amount_in * fee_factor
        amount_out = (amount_in_with_fee * reserve_out) / (reserve_in + amount_in_with_fee)

        ideal_out = amount_in * (reserve_out / reserve_in)
        slippage_pct = ((ideal_out - amount_out) / ideal_out) * 100.0 if ideal_out > 0 else 0.0
        effective_price = amount_in / amount_out if amount_out > 0 else 0.0

        if simulate_delay:
            # Simulate Cardano block time (e.g. 2s for testing instead of full 20s)
            await asyncio.sleep(2.0)

        trade_id = f"dex_{uuid.uuid4().hex[:10]}"

        if side == "BUY":  # Spend ADA, get NIGHT
            if self.ada_balance < amount_in:
                self.ada_balance += total_fee_ada  # Refund fee on failure
                return {"success": False, "error": f"Số dư ADA không đủ: Cần {amount_in} ADA, có {self.ada_balance} ADA."}

            self.ada_balance -= amount_in
            self.night_balance += amount_out

            position = {
                "trade_id": trade_id,
                "market_type": "DEX",
                "asset": pair,
                "side": "BUY",
                "entry_price": round(effective_price, 4),
                "quantity": round(amount_out, 2),
                "cost_basis": round(amount_in, 2),
                "stop_loss": round(stop_loss, 4),
                "take_profit": round(take_profit, 4),
                "fee_paid": total_fee_ada,
                "slippage": round(slippage_pct, 3),
                "status": "OPEN",
                "entry_time": datetime.now(timezone.utc),
            }
            self.open_positions[trade_id] = position
            return {"success": True, "trade": position}

        elif side == "SELL":  # Spend NIGHT, get ADA
            if self.night_balance < amount_in:
                self.ada_balance += total_fee_ada
                return {"success": False, "error": f"Số dư NIGHT không đủ: Cần {amount_in} NIGHT, có {self.night_balance}."}

            self.night_balance -= amount_in
            self.ada_balance += amount_out

            position = {
                "trade_id": trade_id,
                "market_type": "DEX",
                "asset": pair,
                "side": "SELL",
                "entry_price": round(effective_price, 4),
                "quantity": round(amount_in, 2),
                "cost_basis": round(amount_out, 2),
                "stop_loss": round(stop_loss, 4),
                "take_profit": round(take_profit, 4),
                "fee_paid": total_fee_ada,
                "slippage": round(slippage_pct, 3),
                "status": "CLOSED",
                "entry_time": datetime.now(timezone.utc),
                "exit_time": datetime.now(timezone.utc),
            }
            return {"success": True, "trade": position}

        return {"success": False, "error": f"Invalid side {side}"}

    def check_open_positions(self, current_prices: Dict[str, float]) -> List[Dict[str, Any]]:
        """Evaluate open DEX positions for TP/SL triggers"""
        closed_trades = []
        for trade_id, trade in list(self.open_positions.items()):
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

            if hit_reason:
                # Sell tokens back to ADA
                revenue_ada = cur_price * qty
                total_fee = self.batcher_fee_ada + self.network_fee_ada
                net_ada = revenue_ada - total_fee
                pnl_ada = net_ada - trade["cost_basis"]
                pnl_pct = (pnl_ada / trade["cost_basis"]) * 100.0

                self.night_balance = max(0.0, self.night_balance - qty)
                self.ada_balance += net_ada

                trade["exit_price"] = cur_price
                trade["exit_time"] = datetime.now(timezone.utc)
                trade["status"] = "CLOSED"
                trade["close_reason"] = hit_reason
                trade["pnl"] = round(pnl_ada, 2)
                trade["pnl_pct"] = round(pnl_pct, 2)

                closed_trades.append(trade)
                del self.open_positions[trade_id]

        return closed_trades

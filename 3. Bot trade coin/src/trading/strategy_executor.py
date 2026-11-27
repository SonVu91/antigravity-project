import logging
import uuid
from datetime import datetime, timezone
from typing import Dict, Any, List, Optional, Tuple
from config.settings import settings
from src.database.db_session import get_session
from src.database.models import AISignal, PaperTrade
from src.trading.risk_manager import RiskManager
from src.trading.paper_cex import PaperCEXSimulator
from src.trading.paper_dex import PaperDEXSimulator

logger = logging.getLogger("StrategyExecutor")


class StrategyExecutor:
    """
    Central Execution Engine:
    - Receives AI signals or Manual User Orders
    - Validates with RiskManager
    - Routes to PaperCEX (🏦 CEX) or PaperDEX (🥞 CARDANO DEX)
    - Saves execution history to Database
    - Emits event notifications
    """

    def __init__(self):
        self.risk_manager = RiskManager()
        self.cex_sim = PaperCEXSimulator()
        self.dex_sim = PaperDEXSimulator()
        self.peak_nav_cex = settings.PAPER_INITIAL_USDT
        self.peak_nav_dex = settings.PAPER_INITIAL_ADA
        from src.trading.portfolio_reporter import PortfolioReporter
        self.reporter = PortfolioReporter(self)
        self.last_closed_trade: Optional[Dict[str, Any]] = None

    async def process_signal(
        self,
        signal: Dict[str, Any],
        market_data: Dict[str, Any],
    ) -> Dict[str, Any]:
        """
        Process incoming AI signal, validate risk, and execute trade.
        """
        # If bot is in alert_only mode, don't execute
        if self.risk_manager.bot_mode == "alert_only":
            return {"status": "SKIPPED", "reason": "Bot đang ở chế độ ALERT ONLY (Chỉ gửi cảnh báo, không vào lệnh)."}

        action = signal.get("action")
        asset = signal.get("asset")
        market_type = signal.get("market_type", "CEX")
        confidence = signal.get("confidence_score", 0.0)
        suggested = signal.get("suggested_params", {})

        entry_price = suggested.get("entry_price", 0.0)
        stop_loss = suggested.get("stop_loss", 0.0)
        take_profit = suggested.get("take_profit", 0.0)

        # 1. Record signal in DB
        async with get_session() as session:
            signal_obj = AISignal(
                signal_id=signal["signal_id"],
                asset=asset,
                market_type=market_type,
                action=action,
                confidence=confidence,
                reasoning=signal.get("reasoning", {}).get("summary"),
                technical_score=signal.get("reasoning", {}).get("technical_score", 0.0),
                sentiment_score=signal.get("reasoning", {}).get("sentiment_score", 0.0),
                lead_lag_score=signal.get("reasoning", {}).get("lead_lag_score", 0.0),
                suggested_entry=entry_price,
                suggested_sl=stop_loss,
                suggested_tp=take_profit,
                position_size_pct=self.risk_manager.max_risk_pct,
            )
            session.add(signal_obj)

        if action not in ["BUY", "SELL"]:
            return {"status": "SKIPPED", "reason": f"Signal action is {action}"}

        if self.risk_manager.bot_mode == "MONITOR":
            return {"status": "SKIPPED", "reason": "Bot đang ở chế độ CHỈ THEO DÕI (MONITOR), không tự động vào lệnh."}

        if not self.risk_manager.is_within_trading_hours():
            return {"status": "BLOCKED", "reason": f"Ngoài khung giờ giao dịch ({self.risk_manager.trading_hours})"}

        # 2. Risk check & Execution
        if market_type == "CEX":
            current_prices = {asset: entry_price}
            current_nav = self.cex_sim.get_portfolio_nav(current_prices)
            self.peak_nav_cex = max(self.peak_nav_cex, current_nav)

            is_breaker, breaker_msg = self.risk_manager.check_circuit_breaker(current_nav, self.peak_nav_cex)
            if is_breaker:
                return {"status": "BLOCKED", "reason": breaker_msg}

            sizing = self.risk_manager.calculate_position_size(
                capital=self.cex_sim.usdt_balance,
                entry_price=entry_price,
                stop_loss=stop_loss,
                confidence_score=confidence,
                fixed_order_size=self.risk_manager.cex_order_size_usdt,
            )
            if not sizing["allowed"]:
                return {"status": "REJECTED", "reason": sizing["reason"]}

            result = self.cex_sim.execute_order(
                symbol=asset,
                side=action,
                price=entry_price,
                quantity=sizing["quantity"],
                stop_loss=stop_loss,
                take_profit=take_profit,
                orderbook_depth=market_data.get("orderbook"),
            )

        else:  # DEX
            current_nav_ada = self.dex_sim.get_portfolio_nav_in_ada({"NIGHT/ADA": entry_price})
            self.peak_nav_dex = max(self.peak_nav_dex, current_nav_ada)

            ada_amount_in = min(self.dex_sim.ada_balance, self.risk_manager.dex_order_size_ada)
            pool_reserves = market_data.get("pool_reserves", {})

            result = await self.dex_sim.execute_swap(
                pair=asset,
                side=action,
                amount_in=ada_amount_in,
                pool_reserves=pool_reserves,
                stop_loss=stop_loss,
                take_profit=take_profit,
            )

        # 3. Save paper trade to DB if successful
        if result.get("success"):
            trade_info = result["trade"]
            async with get_session() as session:
                trade_obj = PaperTrade(
                    trade_id=trade_info["trade_id"],
                    market_type=trade_info["market_type"],
                    asset=trade_info["asset"],
                    side=trade_info["side"],
                    entry_price=trade_info["entry_price"],
                    quantity=trade_info["quantity"],
                    cost_basis=trade_info["cost_basis"],
                    stop_loss=trade_info["stop_loss"],
                    take_profit=trade_info["take_profit"],
                    fee_paid=trade_info.get("fee_paid", 0.0),
                    slippage=trade_info.get("slippage", 0.0),
                    status=trade_info["status"],
                )
                session.add(trade_obj)
            await self.reporter.sync_database()
            return {"status": "EXECUTED", "trade": trade_info}

        return {"status": "FAILED", "error": result.get("error")}

    async def execute_manual_trade(
        self,
        symbol: str,
        side: str = "BUY",
        amount: Optional[float] = None,
        market_type: Optional[str] = None,
        current_price: Optional[float] = None,
    ) -> Dict[str, Any]:
        """
        Execute a user-initiated trade from Telegram chat (/buy, /sell or inline button).
        """
        symbol_upper = symbol.upper().strip()
        side_upper = side.upper().strip()

        # Deduce standard pair and market type if not explicitly passed
        if symbol_upper in ["ADA", "ADA/USDT"]:
            norm_symbol = "ADA/USDT"
            norm_market = "CEX" if not market_type else market_type.upper()
            ref_price = current_price or 0.150
        elif symbol_upper in ["NIGHT", "NIGHT/ADA"]:
            norm_symbol = "NIGHT/ADA"
            norm_market = "DEX" if not market_type else market_type.upper()
            ref_price = current_price or 0.125
        elif symbol_upper == "NIGHT/USDT":
            norm_symbol = "NIGHT/USDT"
            norm_market = "CEX" if not market_type else market_type.upper()
            ref_price = current_price or 0.10
        else:
            norm_symbol = symbol_upper
            norm_market = market_type.upper() if market_type else ("DEX" if "ADA" in symbol_upper else "CEX")
            ref_price = current_price or 1.0

        # Calculate SL/TP based on dynamic risk settings
        sl_dist = ref_price * (0.015 * self.risk_manager.atr_sl_multiplier)
        tp_dist = sl_dist * self.risk_manager.tp_rr_ratio
        sl = ref_price - sl_dist if side_upper == "BUY" else ref_price + sl_dist
        tp = ref_price + tp_dist if side_upper == "BUY" else ref_price - tp_dist

        if norm_market == "CEX":
            if amount and amount > 0:
                qty = amount
            else:
                sizing = self.risk_manager.calculate_position_size(
                    capital=self.cex_sim.usdt_balance,
                    entry_price=ref_price,
                    stop_loss=sl,
                    confidence_score=0.85,
                    fixed_order_size=self.risk_manager.cex_order_size_usdt,
                )
                qty = sizing["quantity"] if sizing["allowed"] else round(self.risk_manager.cex_order_size_usdt / ref_price, 4)

            res = self.cex_sim.execute_order(
                symbol=norm_symbol,
                side=side_upper,
                price=ref_price,
                quantity=qty,
                stop_loss=sl,
                take_profit=tp,
            )
        else:  # DEX
            ada_amount = amount if amount and amount > 0 else self.risk_manager.dex_order_size_ada
            ada_amount = min(self.dex_sim.ada_balance, max(10.0, ada_amount))

            res = await self.dex_sim.execute_swap(
                pair=norm_symbol,
                side=side_upper,
                amount_in=ada_amount,
                pool_reserves={"reserve_base": 2_500_000.0, "reserve_quote": 312_500.0},
                stop_loss=sl,
                take_profit=tp,
            )

        if res.get("success"):
            trade_info = res["trade"]
            async with get_session() as session:
                trade_obj = PaperTrade(
                    trade_id=trade_info["trade_id"],
                    market_type=trade_info["market_type"],
                    asset=trade_info["asset"],
                    side=trade_info["side"],
                    entry_price=trade_info["entry_price"],
                    quantity=trade_info["quantity"],
                    cost_basis=trade_info["cost_basis"],
                    stop_loss=trade_info["stop_loss"],
                    take_profit=trade_info["take_profit"],
                    fee_paid=trade_info.get("fee_paid", 0.0),
                    slippage=trade_info.get("slippage", 0.0),
                    status=trade_info["status"],
                )
                session.add(trade_obj)
            await self.reporter.sync_database()
            return {"status": "EXECUTED", "trade": trade_info}

        return {"status": "FAILED", "error": res.get("error")}

    def close_single_trade(self, trade_id: str, current_price: Optional[float] = None) -> Tuple[bool, str]:
        """Close a specific open trade on CEX or DEX"""
        import asyncio

        # Check CEX
        if trade_id in self.cex_sim.open_trades:
            trade = self.cex_sim.open_trades[trade_id]
            symbol = trade["asset"]
            price = current_price or trade.get("entry_price", 0.0)
            qty = trade["quantity"]
            pnl = (price - trade["entry_price"]) * qty if trade["side"] == "BUY" else (trade["entry_price"] - price) * qty
            fee = (price * qty) * self.cex_sim.taker_fee_pct
            net_pnl = pnl - fee - trade["fee_paid"]
            self.cex_sim.usdt_balance += (price * qty) - fee
            base_asset = symbol.split("/")[0]
            self.cex_sim.holdings[base_asset] = max(0.0, self.cex_sim.holdings.get(base_asset, 0.0) - qty)
            trade["exit_price"] = price
            trade["exit_time"] = datetime.now(timezone.utc)
            trade["status"] = "CLOSED"
            trade["pnl"] = round(net_pnl, 2)
            trade["pnl_pct"] = round((net_pnl / trade["cost_basis"]) * 100.0, 2) if trade.get("cost_basis", 0) > 0 else 0.0
            trade["close_reason"] = "MANUAL_CLOSE"
            self.last_closed_trade = trade
            del self.cex_sim.open_trades[trade_id]
            self._dispatch_db_sync(trade)
            return True, f"Đã đóng vị thế CEX `{trade['asset']}` (Lời/Lỗ: ${net_pnl:+,.2f})."

        # Check DEX
        if trade_id in self.dex_sim.open_positions:
            trade = self.dex_sim.open_positions[trade_id]
            price = current_price or trade.get("entry_price", 0.125)
            qty = trade["quantity"]
            net_ada = (price * qty) - (self.dex_sim.batcher_fee_ada + self.dex_sim.network_fee_ada)
            pnl_ada = net_ada - trade["cost_basis"]
            self.dex_sim.ada_balance += net_ada
            self.dex_sim.night_balance = max(0.0, self.dex_sim.night_balance - qty)
            trade["exit_price"] = price
            trade["exit_time"] = datetime.now(timezone.utc)
            trade["status"] = "CLOSED"
            trade["pnl"] = round(pnl_ada, 2)
            trade["pnl_pct"] = round((pnl_ada / trade["cost_basis"]) * 100.0, 2) if trade.get("cost_basis", 0) > 0 else 0.0
            trade["close_reason"] = "MANUAL_CLOSE"
            self.last_closed_trade = trade
            del self.dex_sim.open_positions[trade_id]
            self._dispatch_db_sync(trade)
            return True, f"Đã đóng vị thế DEX `{trade['asset']}` (Lời/Lỗ: {pnl_ada:+,.2f} ADA)."

        return False, f"Không tìm thấy vị thế `{trade_id}`."

    def _dispatch_db_sync(self, trade: Dict[str, Any]) -> None:
        """Schedule database sync in background if an event loop is running"""
        import asyncio
        try:
            loop = asyncio.get_running_loop()
            loop.create_task(self.reporter.record_closed_trade_in_db(trade))
            loop.create_task(self.reporter.sync_database())
        except RuntimeError:
            pass

    def close_all_trades(self, current_prices: Dict[str, float]) -> List[str]:
        """Close all open positions on both CEX and DEX"""
        messages = []
        for t_id in list(self.cex_sim.open_trades.keys()):
            trade = self.cex_sim.open_trades[t_id]
            p = current_prices.get(trade["asset"], trade["entry_price"])
            ok, msg = self.close_single_trade(t_id, p)
            if ok:
                messages.append(msg)

        for t_id in list(self.dex_sim.open_positions.keys()):
            trade = self.dex_sim.open_positions[t_id]
            p = current_prices.get(trade["asset"], trade["entry_price"])
            ok, msg = self.close_single_trade(t_id, p)
            if ok:
                messages.append(msg)

        return messages

    def get_open_positions_categorized(self, current_prices: Dict[str, float]) -> Dict[str, List[Dict[str, Any]]]:
        """Return separated open positions for CEX and DEX with live unrealized PnL"""
        cex_list = []
        for t_id, t in self.cex_sim.open_trades.items():
            sym = t["asset"]
            cur_p = current_prices.get(sym, t["entry_price"])
            unrealized = (cur_p - t["entry_price"]) * t["quantity"] if t["side"] == "BUY" else (t["entry_price"] - cur_p) * t["quantity"]
            unrealized_pct = (unrealized / t["cost_basis"]) * 100.0 if t["cost_basis"] > 0 else 0.0
            cex_list.append({
                **t,
                "current_price": cur_p,
                "unrealized_pnl": round(unrealized, 2),
                "unrealized_pnl_pct": round(unrealized_pct, 2),
            })

        dex_list = []
        for t_id, t in self.dex_sim.open_positions.items():
            sym = t["asset"]
            cur_p = current_prices.get(sym, t["entry_price"])
            unrealized_ada = (cur_p * t["quantity"]) - t["cost_basis"] - 2.20
            unrealized_pct = (unrealized_ada / t["cost_basis"]) * 100.0 if t["cost_basis"] > 0 else 0.0
            dex_list.append({
                **t,
                "current_price": cur_p,
                "unrealized_pnl": round(unrealized_ada, 2),
                "unrealized_pnl_pct": round(unrealized_pct, 2),
            })

        return {"cex": cex_list, "dex": dex_list}

    # Alias for compatibility
    get_open_trades_categorized = get_open_positions_categorized

    def format_detailed_orders_report(self, current_prices: Optional[Dict[str, float]] = None) -> Tuple[str, List[List[Any]]]:
        """
        Format comprehensive order book for all open positions across CEX and DEX.
        Returns:
            (formatted_markdown_text, inline_keyboard_buttons)
        """
        from datetime import timedelta
        from telegram import InlineKeyboardButton

        prices = current_prices or {}
        categorized = self.get_open_positions_categorized(prices)
        cex_list = categorized["cex"]
        dex_list = categorized["dex"]
        total_open = len(cex_list) + len(dex_list)

        if total_open == 0:
            msg = (
                "📋 *SỔ LỆNH CHI TIẾT CÁC VỊ THẾ ĐANG CHẠY*\n\n"
                "ℹ️ _Hiện tại không có vị thế nào đang mở._\n"
                "Toàn bộ vốn đang ở trạng thái tiền rảnh (Cash) sẵn sàng đón nhận cơ hội mới!"
            )
            keyboard = [
                [InlineKeyboardButton("🔄 LÀM MỚI SỔ LỆNH", callback_data="menu:orders")],
                [InlineKeyboardButton("🔙 MENU CHÍNH", callback_data="main_menu")],
            ]
            return msg, keyboard

        lines = [
            "📋 *SỔ LỆNH CHI TIẾT CÁC VỊ THẾ ĐANG CHẠY*\n",
        ]
        keyboard = []
        total_unrealized_usd = 0.0

        ada_price = prices.get(settings.CEX_ADA_PAIR, prices.get("ADA/USDT", 0.150))

        order_idx = 1
        if cex_list:
            lines.append("🏦 *SÀN TẬP TRUNG (CEX - Tài khoản USDT):*")
            for t in cex_list:
                sym = t["asset"]
                side_badge = "🟢 BUY" if t["side"] == "BUY" else "🔴 SELL"
                pnl = t["unrealized_pnl"]
                pnl_pct = t["unrealized_pnl_pct"]
                total_unrealized_usd += pnl
                pnl_icon = "🟢" if pnl >= 0 else "🔴"
                pnl_sign = "+" if pnl >= 0 else ""

                t_time = t.get("entry_time")
                if isinstance(t_time, datetime):
                    time_str = (t_time + timedelta(hours=7)).strftime("%H:%M %d/%m")
                else:
                    time_str = "Vừa mở"

                cur_p = t["current_price"]
                entry_p = t["entry_price"]
                qty = t["quantity"]
                cost = t.get("cost_basis", cur_p * qty)

                card = (
                    f"*{order_idx}. {side_badge} `{sym}`* `(#{t['trade_id']})`\n"
                    f"• Khối lượng: `{qty:,.4f} {sym.split('/')[0]}` (~`${cost:,.2f} USDT`)\n"
                    f"• Giá mua: `${entry_p:,.4f}` ➔ Hiện tại: `${cur_p:,.4f}`\n"
                    f"• Stop-Loss: `${t['stop_loss']:,.4f}` | Take-Profit: `${t['take_profit']:,.4f}`\n"
                    f"• Lãi/Lỗ tạm tính: {pnl_icon} `{pnl_sign}${pnl:,.2f}` (`{pnl_pct:+.2f}%`)\n"
                    f"• Thời gian vào: `{time_str}` (UTC+7)"
                )
                lines.append(card)
                keyboard.append([InlineKeyboardButton(f"🛑 Đóng #{order_idx} {sym} ({pnl_sign}${pnl:,.2f})", callback_data=f"close:{t['trade_id']}")])
                order_idx += 1

        if dex_list:
            lines.append("\n🥞 *SÀN PHI TẬP TRUNG (CARDANO DEX - eUTxO):*")
            for t in dex_list:
                sym = t["asset"]
                side_badge = "🟢 BUY" if t["side"] == "BUY" else "🔴 SELL"
                pnl_ada = t["unrealized_pnl"]
                pnl_pct = t["unrealized_pnl_pct"]
                pnl_usd = pnl_ada * ada_price
                total_unrealized_usd += pnl_usd
                pnl_icon = "🟢" if pnl_ada >= 0 else "🔴"
                pnl_sign = "+" if pnl_ada >= 0 else ""

                t_time = t.get("entry_time")
                if isinstance(t_time, datetime):
                    time_str = (t_time + timedelta(hours=7)).strftime("%H:%M %d/%m")
                else:
                    time_str = "Vừa mở"

                cur_p = t["current_price"]
                entry_p = t["entry_price"]
                qty = t["quantity"]
                cost = t.get("cost_basis", cur_p * qty)

                card = (
                    f"*{order_idx}. {side_badge} `{sym}`* `(#{t['trade_id']})`\n"
                    f"• Khối lượng: `{qty:,.2f} {sym.split('/')[0]}` (~`{cost:,.2f} ADA`)\n"
                    f"• Tỷ giá mua: `{entry_p:.4f} ADA` ➔ Hiện tại: `{cur_p:.4f} ADA`\n"
                    f"• Stop-Loss: `{t['stop_loss']:.4f}` | Take-Profit: `{t['take_profit']:.4f}`\n"
                    f"• Lãi/Lỗ tạm tính: {pnl_icon} `{pnl_sign}{pnl_ada:,.2f} ADA` (~`${pnl_usd:+,.2f}`) (`{pnl_pct:+.2f}%`)\n"
                    f"• Thời gian vào: `{time_str}` (UTC+7)"
                )
                lines.append(card)
                keyboard.append([InlineKeyboardButton(f"🛑 Đóng #{order_idx} {sym} ({pnl_sign}{pnl_ada:,.1f} ADA)", callback_data=f"close:{t['trade_id']}")])
                order_idx += 1

        unr_sign = "+" if total_unrealized_usd >= 0 else ""
        unr_icon = "🟢" if total_unrealized_usd >= 0 else "🔴"
        lines.append(
            f"\n───────────────────────\n"
            f"📊 *TỔNG KẾT:* `{total_open} vị thế đang mở` | PnL tạm tính: {unr_icon} *{unr_sign}${total_unrealized_usd:,.2f} USD*"
        )

        keyboard.append([InlineKeyboardButton("🛑 ĐÓNG TẤT CẢ VỊ THẾ", callback_data="close_all")])
        keyboard.append([
            InlineKeyboardButton("🔄 LÀM MỚI SỔ LỆNH", callback_data="menu:orders"),
            InlineKeyboardButton("🔙 MENU CHÍNH", callback_data="main_menu"),
        ])

        return "\n".join(lines), keyboard

import os
import logging
import asyncio
import re
from typing import Dict, Any, Optional, List
from datetime import datetime
from config.settings import settings
from src.database.db_session import get_session
from src.database.models import AISignal, PaperTrade, WhaleTransaction
from src.ai.supply_demand import SupplyDemandDetector, ZoneStatus, SDSignal
from src.bot.charts import generate_sd_chart, generate_mini_chart
from src.collectors.cex_collector import CEXCollector

logger = logging.getLogger("TelegramBot")


class TelegramSentinelBot:
    """
    Bi-directional Interactive Telegram Bot for Cardano & Midnight Sentinel.
    Supports:
    - Institutional Supply & Demand (Fimi SD) chart query (?btc,usdt,d1 or /sd btc/usdt 1d)
    - Distinct CEX (🏦) vs Cardano DEX (🥞) labeling
    - 1-click Inline Order Buttons & Confirmation Dialogues
    - Manual Commands: /buy, /sell, /close, /sd
    - Dynamic Parameter Tuning: /settings and /set
    """

    def __init__(self, strategy_executor=None, cex_collector=None):
        self.token = settings.TELEGRAM_BOT_TOKEN
        self.chat_id = settings.TELEGRAM_CHAT_ID
        self.executor = strategy_executor
        self.cex_collector = cex_collector or CEXCollector(settings.DEFAULT_CEX_EXCHANGE)
        self.sd_detector = SupplyDemandDetector()
        self.app = None
        self._is_running = False

    async def start(self) -> None:
        """Start Telegram bot listener if token is provided"""
        if not self.token:
            logger.info("Telegram Bot Token chưa cấu hình. Cảnh báo sẽ xuất hiện trực tiếp trên Console và Database.")
            return

        try:
            from telegram.ext import (
                ApplicationBuilder,
                CommandHandler,
                CallbackQueryHandler,
                MessageHandler,
                filters,
            )

            self.app = ApplicationBuilder().token(self.token).build()

            # Command Handlers
            self.app.add_handler(CommandHandler("start", self.cmd_start))
            self.app.add_handler(CommandHandler("status", self.cmd_status))
            self.app.add_handler(CommandHandler("pnl", self.cmd_pnl))
            self.app.add_handler(CommandHandler("balance", self.cmd_balance))
            self.app.add_handler(CommandHandler("signals", self.cmd_signals))
            self.app.add_handler(CommandHandler("settings", self.cmd_settings))
            self.app.add_handler(CommandHandler("set", self.cmd_set))
            self.app.add_handler(CommandHandler("sd", self.cmd_supply_demand))
            self.app.add_handler(CommandHandler("buy", self.cmd_buy))
            self.app.add_handler(CommandHandler("sell", self.cmd_sell))
            self.app.add_handler(CommandHandler("close", self.cmd_close))
            self.app.add_handler(CommandHandler("stop_all", self.cmd_stop_all))

            # Callback Query Handler for Inline Buttons
            self.app.add_handler(CallbackQueryHandler(self.handle_callback))

            # Text query handler for Fimi-style queries: ?btc,usdt,d1
            self.app.add_handler(MessageHandler(filters.TEXT & ~filters.COMMAND, self.handle_text_query))

            await self.app.initialize()
            await self.app.start()
            await self.app.updater.start_polling()
            self._is_running = True
            logger.info("Telegram Bot đã khởi động với đầy đủ tính năng tương tác 2 chiều và Supply & Demand Engine.")
        except Exception as e:
            logger.warning(f"Không thể khởi động Telegram Bot (Kiểm tra token hoặc mạng): {e}")

    async def stop(self) -> None:
        """Stop Telegram bot polling"""
        if self.app and self._is_running:
            try:
                await self.app.updater.stop()
                await self.app.stop()
                await self.app.shutdown()
            except Exception as e:
                logger.debug(f"Error stopping Telegram bot: {e}")

    async def send_alert(
        self,
        title: str,
        text: str,
        image_path: Optional[str] = None,
        buttons: Optional[List[List[Any]]] = None,
    ) -> None:
        """Broadcast alert to Telegram with optional inline buttons and image"""
        logger.info(f"[ALERT] {title}: {text}")

        if not self.app or not self.chat_id or not self._is_running:
            return

        try:
            from telegram import InlineKeyboardMarkup

            reply_markup = InlineKeyboardMarkup(buttons) if buttons else None
            caption = f"🚨 *{title}*\n\n{text}"

            if image_path:
                with open(image_path, "rb") as photo:
                    try:
                        await self.app.bot.send_photo(
                            chat_id=self.chat_id,
                            photo=photo,
                            caption=caption,
                            parse_mode="Markdown",
                            reply_markup=reply_markup,
                        )
                    except Exception as pe:
                        logger.warning(f"Telegram alert photo Markdown parse failed: {pe}, fallback to plain text")
                        photo.seek(0)
                        plain_caption = caption.replace("*", "").replace("`", "").replace("_", "")
                        await self.app.bot.send_photo(
                            chat_id=self.chat_id,
                            photo=photo,
                            caption=plain_caption,
                            reply_markup=reply_markup,
                        )
            else:
                try:
                    await self.app.bot.send_message(
                        chat_id=self.chat_id,
                        text=caption,
                        parse_mode="Markdown",
                        reply_markup=reply_markup,
                    )
                except Exception as me:
                    plain_caption = caption.replace("*", "").replace("`", "").replace("_", "")
                    await self.app.bot.send_message(
                        chat_id=self.chat_id,
                        text=plain_caption,
                        reply_markup=reply_markup,
                    )
        except Exception as e:
            logger.warning(f"Lỗi gửi cảnh báo qua Telegram: {e}")

    # ==================== COMMAND HANDLERS ====================

    async def cmd_start(self, update, context) -> None:
        msg = (
            "🤖 *Cardano & Midnight AI Sentinel Bot*\n\n"
            "📈 *TRA CỨU VÙNG CUNG - CẦU (SUPPLY & DEMAND):*\n"
            "• Cú pháp nhanh Fimi: `?<coin>,<quote>,<tf>`\n"
            "  _Ví dụ:_ `?btc,usdt,d1` hoặc `?ada,usdt,h4` hoặc `?night,ada,h4`\n"
            "• Lệnh Slash: `/sd <cặp_tiền> [khung]`\n"
            "  _Ví dụ:_ `/sd btc/usdt 1d` hoặc `/sd ada 4h`\n\n"
            "⚙️ *LỆNH ĐIỀU KHIỂN & VẬN HÀNH:*\n"
            "• `/status`: Trạng thái hệ thống & kết nối CEX/DEX\n"
            "• `/pnl`: Báo cáo vị thế & PnL realtime kèm nút đóng lệnh\n"
            "• `/balance`: Số dư tài khoản CEX & Ví Cardano\n"
            "• `/settings`: Menu chỉnh sửa thông số rủi ro & chế độ bot\n"
            "• `/set <tên> <giá_trị>`: Chỉnh nhanh thông số (ví dụ: `/set risk 2.0`)\n"
            "• `/buy <cặp> [số_lượng]`: Đặt lệnh mua\n"
            "• `/sell <cặp> [số_lượng]`: Đặt lệnh bán\n"
            "• `/close all`: Đóng toàn bộ các vị thế đang mở\n"
            "• `/stop_all`: Ngắt mạch an toàn khẩn cấp"
        )
        await update.message.reply_text(msg, parse_mode="Markdown")

    async def cmd_status(self, update, context) -> None:
        rm = self.executor.risk_manager if self.executor else None
        mode = rm.bot_mode.upper() if rm else settings.BOT_MODE.upper()
        circuit = "⚠️ ACTIVE (Ngắt giao dịch)" if (rm and rm.is_circuit_breaker_active) else "✅ Normal"

        msg = (
            "📊 *TRẠNG THÁI HỆ THỐNG*\n"
            f"• Chế độ: `{mode}`\n"
            f"• 🏛️ Engine: `Supply & Demand (Fimi/SMC)` + `LightGBM AI`\n"
            f"• 🏦 CEX Gateway: `Binance / OKX (CCXT)`\n"
            f"• 🥞 Cardano DEX: `Minswap / DexHunter (eUTxO)`\n"
            f"• 🔗 Cardano On-chain: `{'Connected' if settings.BLOCKFROST_PROJECT_ID else 'Koios/Mock Fallback'}`\n"
            f"• ⚡ Circuit Breaker: `{circuit}`\n"
            f"• 🎯 Rủi ro/lệnh: `{rm.max_risk_pct if rm else 1.5}% NAV`\n"
            f"• 🛡️ Stop-Loss: `{rm.atr_sl_multiplier if rm else 1.5}x ATR` | Chốt lời: `1:{rm.tp_rr_ratio if rm else 2.0} R:R`\n"
            f"• 📈 Cặp theo dõi: `ADA/USDT`, `NIGHT/USDT`, `NIGHT/ADA`, `BTC/USDT`"
        )
        await update.message.reply_text(msg, parse_mode="Markdown")

    async def cmd_supply_demand(self, update, context) -> None:
        """Command /sd <pair> [timeframe]"""
        args = context.args
        if not args:
            await update.message.reply_text(
                "ℹ️ Cú pháp lệnh Supply & Demand:\n"
                "• `/sd <cặp_tiền> [khung_thời_gian]`\n"
                "Ví dụ:\n"
                "• `/sd btc/usdt 1d`\n"
                "• `/sd ada/usdt 4h`\n"
                "• `/sd night/ada 4h`\n\n"
                "Hoặc dùng cú pháp gõ nhanh như FimiSDbot: `?btc,usdt,d1`",
                parse_mode="Markdown",
            )
            return

        pair_arg = args[0].strip()
        tf_arg = args[1].strip() if len(args) > 1 else "4h"

        if "/" in pair_arg:
            parts = pair_arg.split("/")
            symbol = parts[0]
            quote = parts[1]
        elif "," in pair_arg:
            parts = pair_arg.split(",")
            symbol = parts[0]
            quote = parts[1]
        else:
            symbol = pair_arg
            quote = "USDT"

        await self.process_supply_demand_request(update, symbol=symbol, quote=quote, timeframe=tf_arg)

    async def handle_text_query(self, update, context) -> None:
        """
        Catches text queries formatted like:
        ?btc,usdt,d1 or ?night,ada,h4 or ?ada,usdt,1h
        """
        text = update.message.text.strip() if update.message and update.message.text else ""
        if not text.startswith("?"):
            return

        # Pattern: ?symbol,quote,timeframe
        m3 = re.match(r"^\?([a-zA-Z0-9]+)\s*,\s*([a-zA-Z0-9]+)\s*,\s*([a-zA-Z0-9]+)$", text)
        if m3:
            symbol = m3.group(1)
            quote = m3.group(2)
            timeframe = m3.group(3)
            await self.process_supply_demand_request(update, symbol=symbol, quote=quote, timeframe=timeframe)
            return

        # Pattern: ?symbol,timeframe (default quote USDT)
        m2 = re.match(r"^\?([a-zA-Z0-9]+)\s*,\s*([a-zA-Z0-9]+)$", text)
        if m2:
            symbol = m2.group(1)
            timeframe = m2.group(2)
            quote = "ADA" if symbol.upper() == "NIGHT" else "USDT"
            await self.process_supply_demand_request(update, symbol=symbol, quote=quote, timeframe=timeframe)
            return

    async def process_supply_demand_request(
        self,
        update,
        symbol: str,
        quote: str,
        timeframe: str,
    ) -> None:
        """
        Fetch candles, run institutional S&D detector, render dark mode chart and reply.
        """
        from telegram import InlineKeyboardButton, InlineKeyboardMarkup

        tf_map = {
            "d1": "1d", "1d": "1d", "daily": "1d",
            "h4": "4h", "4h": "4h",
            "h1": "1h", "1h": "1h",
            "m15": "15m", "15m": "15m",
            "m30": "30m", "30m": "30m",
            "m5": "5m", "5m": "5m",
        }
        norm_tf = tf_map.get(timeframe.lower(), "4h")
        pair = f"{symbol.upper()}/{quote.upper()}"

        wait_msg = await update.message.reply_text(
            f"⏳ Đang tải dữ liệu nến và phân tích Vùng Cung - Cầu cho `{pair}` [{norm_tf.upper()}]...",
            parse_mode="Markdown",
        )

        try:
            # 1. Fetch candles
            candles = await self.cex_collector.fetch_ohlcv(pair, timeframe=norm_tf, limit=80)
            if not candles or len(candles) < 10:
                await wait_msg.edit_text(f"❌ Không thể tải đủ dữ liệu nến cho `{pair}` ({norm_tf}). Vui lòng thử lại sau.")
                return

            # 2. Analyze Supply & Demand zones
            signal: SDSignal = self.sd_detector.analyze(candles, symbol=pair, timeframe=norm_tf)

            # 3. Generate chart
            chart_path = generate_sd_chart(
                candles=candles,
                symbol=pair,
                timeframe=norm_tf,
                zones=signal.active_zones,
                signal=signal,
            )

            # 4. Construct Markdown caption
            caption_parts = [
                f"🏛️ *PHÂN TÍCH VÙNG CUNG - CẦU (SUPPLY & DEMAND)*",
                f"• Cặp: `{pair}` | Khung: `{norm_tf.upper()}`",
                f"• Giá hiện tại: `{signal.current_price:,.4f}`\n",
            ]

            if signal.nearest_demand:
                d = signal.nearest_demand
                dist_d = ((signal.current_price - d.proximal) / signal.current_price) * 100
                caption_parts.append(
                    f"🟢 *VÙNG CẦU GẦN NHẤT (DEMAND / HỖ TRỢ):*\n"
                    f"• Vùng giá: `[{d.distal:.4f} - {d.proximal:.4f}]`\n"
                    f"• Cấu trúc: `{d.pattern.value}` | Trạng thái: `{d.status.value}` (Score: {d.score:.0f}/100)\n"
                    f"• Khoảng cách tới giá: `{dist_d:+.2f}%`\n"
                )
            else:
                caption_parts.append("🟢 *VÙNG CẦU (DEMAND):* _Chưa phát hiện vùng cầu rõ rệt bên dưới._\n")

            if signal.nearest_supply:
                s = signal.nearest_supply
                dist_s = ((s.proximal - signal.current_price) / signal.current_price) * 100
                caption_parts.append(
                    f"🔴 *VÙNG CUNG GẦN NHẤT (SUPPLY / KHÁNG CỰ):*\n"
                    f"• Vùng giá: `[{s.proximal:.4f} - {s.distal:.4f}]`\n"
                    f"• Cấu trúc: `{s.pattern.value}` | Trạng thái: `{s.status.value}` (Score: {s.score:.0f}/100)\n"
                    f"• Khoảng cách tới giá: `{dist_s:+.2f}%`\n"
                )
            else:
                caption_parts.append("🔴 *VÙNG CUNG (SUPPLY):* _Chưa phát hiện vùng cung rõ rệt bên trên._\n")

            action_emoji = "🟢" if signal.action == "BUY" else ("🔴" if signal.action == "SELL" else "🟡")
            caption_parts.append(
                f"💡 *TÍN HIỆU & KHUYẾN NGHỊ:*\n"
                f"• Hành động: {action_emoji} *{signal.action}*\n"
                f"• Diễn giải: _{signal.reason}_"
            )

            if signal.action in ["BUY", "SELL"] and signal.entry_price > 0:
                caption_parts.append(
                    f"• Entry: `{signal.entry_price:.4f}` | SL: `{signal.stop_loss:.4f}` | TP: `{signal.take_profit:.4f}`\n"
                    f"• Tỷ lệ R:R: `1:{signal.risk_reward}`"
                )

            caption = "\n".join(caption_parts)

            # 5. Interactive inline buttons
            keyboard = []
            action_buttons = []
            market_type = "DEX" if ("NIGHT" in pair and "ADA" in pair) else "CEX"

            if signal.action == "BUY":
                action_buttons.append(
                    InlineKeyboardButton(
                        f"🛒 MUA TẠI DEMAND ({signal.entry_price:.4f})",
                        callback_data=f"order_prep:{pair}:BUY:{market_type}",
                    )
                )
            elif signal.action == "SELL":
                action_buttons.append(
                    InlineKeyboardButton(
                        f"💰 BÁN TẠI SUPPLY ({signal.entry_price:.4f})",
                        callback_data=f"order_prep:{pair}:SELL:{market_type}",
                    )
                )

            if action_buttons:
                keyboard.append(action_buttons)

            keyboard.append([
                InlineKeyboardButton("🔄 Làm mới biểu đồ", callback_data=f"sd_refresh:{pair}:{norm_tf}"),
                InlineKeyboardButton("⚙️ Menu Bot", callback_data="cancel"),
            ])

            reply_markup = InlineKeyboardMarkup(keyboard)

            # 6. Send photo
            if chart_path and os.path.exists(chart_path):
                with open(chart_path, "rb") as photo:
                    try:
                        await update.message.reply_photo(
                            photo=photo,
                            caption=caption,
                            parse_mode="Markdown",
                            reply_markup=reply_markup,
                        )
                    except Exception as pe:
                        logger.warning(f"Telegram Markdown parse failed: {pe}, fallback to plain text caption")
                        photo.seek(0)
                        plain_caption = caption.replace("*", "").replace("`", "").replace("_", "")
                        await update.message.reply_photo(
                            photo=photo,
                            caption=plain_caption,
                            reply_markup=reply_markup,
                        )
                try:
                    await wait_msg.delete()
                except Exception:
                    pass
            else:
                try:
                    await wait_msg.edit_text(caption, parse_mode="Markdown", reply_markup=reply_markup)
                except Exception:
                    plain_caption = caption.replace("*", "").replace("`", "").replace("_", "")
                    await wait_msg.edit_text(plain_caption, reply_markup=reply_markup)

        except Exception as e:
            logger.error(f"Lỗi khi xử lý tra cứu S&D cho {pair}: {e}", exc_info=True)
            await wait_msg.edit_text(f"❌ Đã xảy ra lỗi trong quá trình phân tích S&D: `{e}`", parse_mode="Markdown")

    async def cmd_settings(self, update, context) -> None:
        """Display interactive settings menu with inline buttons"""
        if not self.executor:
            await update.message.reply_text("Executor chưa khởi tạo.")
            return

        from telegram import InlineKeyboardButton, InlineKeyboardMarkup

        s = self.executor.risk_manager.get_all_settings()
        mode_icon = "🟢" if s["bot_mode"] == "paper_trading" else "🟡"
        mode_text = "PAPER TRADING" if s["bot_mode"] == "paper_trading" else "ALERT ONLY"

        msg = (
            "⚙️ *CẤU HÌNH HỆ THỐNG VÀ THÔNG SỐ LỆNH*\n\n"
            f"• Chế độ: {mode_icon} `{mode_text}`\n"
            f"• Tỷ lệ Rủi ro / Vị thế: `{s['max_risk_pct']}% NAV`\n"
            f"• Cắt lỗ (SL): `{s['atr_sl_multiplier']}x ATR`\n"
            f"• Chốt lời (TP): `1:{s['tp_rr_ratio']} R:R`\n"
            f"• Ngưỡng Circuit Breaker: `{s['circuit_breaker_limit_pct']}% Drawdown`\n"
            f"• Ngưỡng Cảnh báo Arbitrage: `{s['arbitrage_threshold_pct']}% Spread`\n\n"
            "Chạm vào các nút bên dưới để đổi nhanh thông số:"
        )

        next_mode = "alert_only" if s["bot_mode"] == "paper_trading" else "paper_trading"
        next_mode_label = "Chuyển sang: ALERT ONLY 🟡" if s["bot_mode"] == "paper_trading" else "Chuyển sang: PAPER TRADING 🟢"

        keyboard = [
            [InlineKeyboardButton(next_mode_label, callback_data=f"set:mode:{next_mode}")],
            [
                InlineKeyboardButton("Rủi ro 1.0%", callback_data="set:risk:1.0"),
                InlineKeyboardButton("Rủi ro 1.5%", callback_data="set:risk:1.5"),
                InlineKeyboardButton("Rủi ro 2.0%", callback_data="set:risk:2.0"),
            ],
            [
                InlineKeyboardButton("Cắt lỗ 1.0x ATR", callback_data="set:sl:1.0"),
                InlineKeyboardButton("Cắt lỗ 1.5x ATR", callback_data="set:sl:1.5"),
                InlineKeyboardButton("Cắt lỗ 2.0x ATR", callback_data="set:sl:2.0"),
            ],
            [
                InlineKeyboardButton("Chốt lời 1:1.5", callback_data="set:tp:1.5"),
                InlineKeyboardButton("Chốt lời 1:2.0", callback_data="set:tp:2.0"),
                InlineKeyboardButton("Chốt lời 1:3.0", callback_data="set:tp:3.0"),
            ],
            [
                InlineKeyboardButton("❌ ĐÓNG MENU", callback_data="cancel"),
            ],
        ]
        await update.message.reply_text(msg, parse_mode="Markdown", reply_markup=InlineKeyboardMarkup(keyboard))

    async def cmd_set(self, update, context) -> None:
        """Manual set command: /set <param> <value>"""
        if not self.executor:
            await update.message.reply_text("Executor chưa khởi tạo.")
            return

        args = context.args
        if len(args) < 2:
            await update.message.reply_text(
                "ℹ️ Cú pháp: `/set <tên_thông_số> <giá_trị>`\n"
                "Ví dụ:\n"
                "• `/set risk 2.0` (Đổi rủi ro thành 2.0% NAV)\n"
                "• `/set sl 1.8` (Đổi Stop-Loss thành 1.8x ATR)\n"
                "• `/set tp 2.5` (Đổi Chốt lời thành R:R 1:2.5)\n"
                "• `/set mode alert_only` (Chuyển sang chế độ chỉ cảnh báo)\n"
                "• `/set mode paper_trading` (Kích hoạt lại paper trading)",
                parse_mode="Markdown",
            )
            return

        key, val = args[0], args[1]
        ok, msg = self.executor.risk_manager.update_setting(key, val)
        prefix = "✅" if ok else "❌"
        await update.message.reply_text(f"{prefix} {msg}")

    async def cmd_signals(self, update, context) -> None:
        from sqlalchemy import select

        async with get_session() as session:
            stmt = select(AISignal).order_by(AISignal.timestamp.desc()).limit(5)
            res = await session.execute(stmt)
            signals = res.scalars().all()

        if not signals:
            await update.message.reply_text("Chưa ghi nhận tín hiệu AI nào gần đây.")
            return

        lines = ["📡 *5 TÍN HIỆU AI GẦN NHẤT:*"]
        for s in signals:
            time_str = s.timestamp.strftime("%H:%M:%S")
            lines.append(f"• [{time_str}] `{s.asset}` ({s.market_type}) ➔ *{s.action}* | Confidence: `{s.confidence_score:.2f}`")

        await update.message.reply_text("\n".join(lines), parse_mode="Markdown")

    async def cmd_pnl(self, update, context) -> None:
        if not self.executor:
            await update.message.reply_text("Chưa khởi tạo Strategy Executor.")
            return

        from telegram import InlineKeyboardButton, InlineKeyboardMarkup

        # Mock current prices for PnL calculation
        current_prices = {"ADA/USDT": 0.85, "NIGHT/ADA": 0.125, "NIGHT/USDT": 0.10}
        categorized = self.executor.get_open_trades_categorized(current_prices)

        cex_trades = categorized["cex"]
        dex_trades = categorized["dex"]

        lines = ["📈 *BÁO CÁO HIỆU SUẤT VỊ THẾ PAPER TRADING*\n"]
        keyboard = []

        lines.append("🏦 *VỊ THẾ SÀN TẬP TRUNG (CEX - Tài khoản USDT):*")
        if cex_trades:
            for i, t in enumerate(cex_trades, 1):
                pnl_str = f"{t['unrealized_pnl']:+,.2f} USDT ({t['unrealized_pnl_pct']:+.2f}%)"
                lines.append(f"• #{i} `{t['asset']}` ({t['side']}): Giá vào `{t['entry_price']}` | PnL: `{pnl_str}`")
                keyboard.append([InlineKeyboardButton(f"🛑 Đóng CEX #{i} ({t['asset']})", callback_data=f"close:{t['trade_id']}")])
        else:
            lines.append("_(Chưa có vị thế CEX nào đang mở)_")

        lines.append("\n🥞 *VỊ THẾ SÀN PHI TẬP TRUNG (CARDANO DEX - Ví Cardano):*")
        if dex_trades:
            for i, t in enumerate(dex_trades, 1):
                pnl_str = f"{t['unrealized_pnl']:+,.2f} ADA ({t['unrealized_pnl_pct']:+.2f}%)"
                lines.append(f"• #{i} `{t['asset']}` ({t['side']}): Giá vào `{t['entry_price']}` | PnL: `{pnl_str}`")
                keyboard.append([InlineKeyboardButton(f"🛑 Đóng DEX #{i} ({t['asset']})", callback_data=f"close:{t['trade_id']}")])
        else:
            lines.append("_(Chưa có vị thế Cardano DEX nào đang mở)_")

        lines.append(f"\n💰 *Số dư:* CEX `${self.executor.cex_sim.usdt_balance:,.2f}` | DEX `{self.executor.dex_sim.ada_balance:,.2f} ADA`")

        if cex_trades or dex_trades:
            keyboard.append([InlineKeyboardButton("🚨 ĐÓNG TẤT CẢ VỊ THẾ", callback_data="close_all")])

        reply_markup = InlineKeyboardMarkup(keyboard) if keyboard else None
        await update.message.reply_text("\n".join(lines), parse_mode="Markdown", reply_markup=reply_markup)

    async def cmd_balance(self, update, context) -> None:
        if not self.executor:
            await update.message.reply_text("Chưa khởi tạo Strategy Executor.")
            return

        msg = (
            "💰 *SỐ DƯ TÀI KHOẢN GIẢ LẬP PHÂN ĐỊNH*\n\n"
            "🏦 *SÀN TẬP TRUNG (CEX ACCOUNT):*\n"
            f"• USDT Khả dụng: `${self.executor.cex_sim.usdt_balance:,.2f}`\n"
            f"• ADA Nắm giữ: `{self.executor.cex_sim.holdings.get('ADA', 0.0):,.2f} ADA`\n"
            f"• NIGHT Nắm giữ: `{self.executor.cex_sim.holdings.get('NIGHT', 0.0):,.2f} NIGHT`\n\n"
            "🥞 *CARDANO NATIVE WALLET (DEX):*\n"
            f"• ADA Khả dụng: `{self.executor.dex_sim.ada_balance:,.2f} ADA`\n"
            f"• NIGHT Nắm giữ: `{self.executor.dex_sim.night_balance:,.2f} NIGHT`"
        )
        await update.message.reply_text(msg, parse_mode="Markdown")

    async def cmd_buy(self, update, context) -> None:
        """Command to buy: /buy <symbol> [amount]"""
        args = context.args
        if not args:
            await update.message.reply_text(
                "ℹ️ Cú pháp: `/buy <cặp_tiền> [số_lượng]`\n"
                "Ví dụ:\n"
                "• `/buy ADA 1000`: Mua 1,000 ADA trên 🏦 CEX\n"
                "• `/buy NIGHT 500`: Mua 500 ADA tiền NIGHT trên 🥞 CARDANO DEX\n"
                "• `/buy ADA`: Tự động tính khối lượng an toàn theo Kelly 1.5% NAV",
                parse_mode="Markdown",
            )
            return

        symbol = args[0].strip()
        amount = float(args[1]) if len(args) > 1 else None
        await self._prompt_manual_order(update, symbol=symbol, side="BUY", amount=amount)

    async def cmd_sell(self, update, context) -> None:
        """Command to sell: /sell <symbol> [amount]"""
        args = context.args
        if not args:
            await update.message.reply_text(
                "ℹ️ Cú pháp: `/sell <cặp_tiền> [số_lượng]`\n"
                "Ví dụ:\n"
                "• `/sell ADA 1000`: Bán 1,000 ADA trên 🏦 CEX\n"
                "• `/sell NIGHT 500`: Bán 500 NIGHT trên 🥞 CARDANO DEX",
                parse_mode="Markdown",
            )
            return

        symbol = args[0].strip()
        amount = float(args[1]) if len(args) > 1 else None
        await self._prompt_manual_order(update, symbol=symbol, side="SELL", amount=amount)

    async def cmd_close(self, update, context) -> None:
        """Command to close trade: /close all or /close <trade_id>"""
        if not self.executor:
            await update.message.reply_text("Executor chưa khởi tạo.")
            return

        args = context.args
        if not args or args[0].lower() == "all":
            msgs = self.executor.close_all_trades({"ADA/USDT": 0.85, "NIGHT/ADA": 0.125, "NIGHT/USDT": 0.10})
            if msgs:
                report_block = await self.executor.reporter.format_telegram_report(trigger_type="CLOSE")
                await update.message.reply_text("🛑 " + "\n".join(msgs) + f"\n\n{report_block}", parse_mode="Markdown")
            else:
                await update.message.reply_text("Không có vị thế nào đang mở để đóng.")
            return

        trade_id = args[0].strip()
        ok, msg = self.executor.close_single_trade(trade_id)
        if ok:
            closed_trade = getattr(self.executor, "last_closed_trade", None)
            report_block = await self.executor.reporter.format_telegram_report(
                trigger_type="CLOSE",
                trade_info=closed_trade,
            )
            await update.message.reply_text(f"✅ {msg}\n\n{report_block}", parse_mode="Markdown")
        else:
            await update.message.reply_text(f"❌ {msg}")

    async def cmd_stop_all(self, update, context) -> None:
        """Emergency circuit breaker trigger"""
        if self.executor:
            self.executor.risk_manager.is_circuit_breaker_active = True
        await update.message.reply_text(
            "🛑 *NGẮT MẠCH KHẨN CẤP (CIRCUIT BREAKER)!*\n\n"
            "Toàn bộ giao dịch tự động đã tạm dừng. Không có lệnh mới nào được thực thi.\n"
            "Gõ `/set mode paper_trading` khi muốn khôi phục giao dịch.",
            parse_mode="Markdown",
        )

    async def _prompt_manual_order(self, update, symbol: str, side: str, amount: Optional[float] = None) -> None:
        """Show confirmation dialog before executing a manual order"""
        if not self.executor:
            await update.message.reply_text("Chưa khởi tạo Strategy Executor.")
            return

        from telegram import InlineKeyboardButton, InlineKeyboardMarkup

        symbol_upper = symbol.upper()
        market_type = "DEX" if ("NIGHT" in symbol_upper and "USDT" not in symbol_upper) else "CEX"
        market_badge = "🥞 CARDANO DEX (Minswap)" if market_type == "DEX" else "🏦 CEX (Binance)"

        ref_price = 0.85 if "ADA" in symbol_upper else (0.125 if market_type == "DEX" else 0.10)
        cost_desc = f"{amount:,.0f} đơn vị" if amount else "Tự động tính theo Kelly 1.5% NAV"

        msg = (
            "⚠️ *XÁC NHẬN ĐẶT LỆNH PAPER TRADING*\n\n"
            f"• Nền tảng: `{market_badge}`\n"
            f"• Cặp giao dịch: `{symbol_upper}`\n"
            f"• Hành động: *{side}*\n"
            f"• Khối lượng: `{cost_desc}`\n"
            f"• Giá tham chiếu: `{ref_price}`\n"
            f"• Phí dự kiến: `{'2.20 ADA (Batcher+Tx)' if market_type == 'DEX' else '0.075% Taker'}`\n\n"
            "Chạm xác nhận để bot thực thi ngay:"
        )

        amount_tag = str(amount) if amount else "auto"
        keyboard = [
            [
                InlineKeyboardButton("👉 XÁC NHẬN KHỚP LỆNH", callback_data=f"exec:{symbol_upper}:{side}:{market_type}:{amount_tag}"),
                InlineKeyboardButton("❌ HỦY LỆNH", callback_data="cancel"),
            ]
        ]
        await update.message.reply_text(msg, parse_mode="Markdown", reply_markup=InlineKeyboardMarkup(keyboard))

    async def handle_callback(self, update, context) -> None:
        """Handle inline keyboard button clicks"""
        query = update.callback_query
        await query.answer()

        data = query.data
        if not data:
            return

        # 1. Cancel
        if data == "cancel":
            await query.edit_message_text("❌ Đã hủy bỏ thao tác.")
            return

        # 2. Dynamic Settings Update: set:key:val
        if data.startswith("set:") and self.executor:
            parts = data.split(":")
            if len(parts) >= 3:
                key, val = parts[1], parts[2]
                ok, msg = self.executor.risk_manager.update_setting(key, val)
                await query.edit_message_text(f"⚙️ {msg}\n\n_Gõ /settings để xem lại toàn bộ cấu hình._", parse_mode="Markdown")
            return

        # 3. Supply & Demand Chart Refresh: sd_refresh:<pair>:<timeframe>
        if data.startswith("sd_refresh:"):
            parts = data.split(":")
            if len(parts) >= 3:
                pair = parts[1]
                timeframe = parts[2]
                candles = await self.cex_collector.fetch_ohlcv(pair, timeframe=timeframe, limit=80)
                if candles:
                    sig = self.sd_detector.analyze(candles, symbol=pair, timeframe=timeframe)
                    chart_path = generate_sd_chart(candles, symbol=pair, timeframe=timeframe, zones=sig.active_zones, signal=sig)
                    if chart_path and os.path.exists(chart_path):
                        from telegram import InputMediaPhoto
                        with open(chart_path, "rb") as photo:
                            await query.edit_message_media(
                                media=InputMediaPhoto(media=photo, caption=f"🔄 *Biểu đồ S&D `{pair}` ({timeframe.upper()}) đã được làm mới*", parse_mode="Markdown")
                            )
            return

        # 4. Close Single Trade: close:<trade_id>
        if data.startswith("close:") and self.executor:
            trade_id = data.split(":", 1)[1]
            ok, msg = self.executor.close_single_trade(trade_id)
            if ok:
                closed_trade = getattr(self.executor, "last_closed_trade", None)
                report_block = await self.executor.reporter.format_telegram_report(
                    trigger_type="CLOSE",
                    trade_info=closed_trade,
                )
                await query.edit_message_text(f"✅ {msg}\n\n{report_block}", parse_mode="Markdown")
            else:
                await query.edit_message_text(f"❌ {msg}")
            return

        # 5. Close All: close_all
        if data == "close_all" and self.executor:
            msgs = self.executor.close_all_trades({"ADA/USDT": 0.85, "NIGHT/ADA": 0.125, "NIGHT/USDT": 0.10})
            if msgs:
                report_block = await self.executor.reporter.format_telegram_report(trigger_type="CLOSE")
                await query.edit_message_text("🛑 " + "\n".join(msgs) + f"\n\n{report_block}", parse_mode="Markdown")
            else:
                await query.edit_message_text("Không có vị thế nào đang mở để đóng.")
            return

        # 6. Order Prep: order_prep:<symbol>:<side>:<market>
        if data.startswith("order_prep:") and self.executor:
            from telegram import InlineKeyboardButton, InlineKeyboardMarkup

            parts = data.split(":")
            symbol, side, market = parts[1], parts[2], parts[3]
            badge = "🥞 CARDANO DEX (Minswap)" if market == "DEX" else "🏦 CEX (Binance)"
            ref_price = 0.85 if "ADA" in symbol else (0.125 if market == "DEX" else 0.10)

            confirm_msg = (
                "⚠️ *XÁC NHẬN THỰC THI LỆNH TÍN HIỆU*\n\n"
                f"• Nền tảng: `{badge}`\n"
                f"• Cặp giao dịch: `{symbol}`\n"
                f"• Chiều: *{side}*\n"
                f"• Giá tham chiếu: `{ref_price}`\n"
                f"• Quản lý vốn: `Kelly {self.executor.risk_manager.max_risk_pct}% NAV`\n"
                f"• SL/TP: `ATR {self.executor.risk_manager.atr_sl_multiplier}x / R:R 1:{self.executor.risk_manager.tp_rr_ratio}`\n\n"
                "Bạn có muốn thực thi lệnh giả lập ngay bây giờ?"
            )
            keyboard = [
                [
                    InlineKeyboardButton("👉 XÁC NHẬN THỰC THI", callback_data=f"exec:{symbol}:{side}:{market}:auto"),
                    InlineKeyboardButton("❌ HỦY", callback_data="cancel"),
                ]
            ]
            await query.edit_message_text(confirm_msg, parse_mode="Markdown", reply_markup=InlineKeyboardMarkup(keyboard))
            return

        # 7. Execute Order: exec:<symbol>:<side>:<market>:<amount>
        if data.startswith("exec:") and self.executor:
            parts = data.split(":")
            symbol, side, market = parts[1], parts[2], parts[3]
            amount_str = parts[4] if len(parts) > 4 else "auto"
            amount = float(amount_str) if amount_str != "auto" else None

            res = await self.executor.execute_manual_trade(
                symbol=symbol,
                side=side,
                amount=amount,
                market_type=market,
            )

            if res.get("status") == "EXECUTED":
                t = res["trade"]
                badge = "🥞 CARDANO DEX" if t["market_type"] == "DEX" else "🏦 CEX"
                fee_unit = "ADA" if t["market_type"] == "DEX" else "USDT"
                report_block = await self.executor.reporter.format_telegram_report(
                    trigger_type="EXECUTE",
                    trade_info=t,
                )
                fill_msg = (
                    f"✅ *KHỚP LỆNH THÀNH CÔNG TRÊN {badge}*\n\n"
                    f"• Mã lệnh: `{t['trade_id']}`\n"
                    f"• {t['side']} `{t['quantity']:,.2f} {t['asset']}`\n"
                    f"• Giá khớp: `{t['entry_price']}`\n"
                    f"• Stop-Loss: `{t['stop_loss']}` | Take-Profit: `{t['take_profit']}`\n"
                    f"• Phí đã trừ: `{t['fee_paid']} {fee_unit}`\n"
                    f"• Trượt giá: `{t['slippage']}%\n\n`"
                    f"{report_block}"
                )
                await query.edit_message_text(fill_msg, parse_mode="Markdown")
            else:
                await query.edit_message_text(f"❌ Khớp lệnh thất bại: `{res.get('error') or res.get('reason')}`", parse_mode="Markdown")

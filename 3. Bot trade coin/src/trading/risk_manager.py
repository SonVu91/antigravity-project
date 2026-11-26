import json
import logging
import re
from datetime import datetime, timezone, timedelta, time
from pathlib import Path
from typing import Dict, Any, Tuple, List
from config.settings import settings

logger = logging.getLogger("RiskManager")


class RiskManager:
    """
    Risk Management & Bot Configuration Module:
    - Position Sizing (Kelly Criterion adjusted: 1% - 2% max risk per trade)
    - Dynamic ATR Stop-Loss & Take-Profit
    - 24-Hour Circuit Breaker (halts on > 5% drawdown)
    - Dynamic Parameter Tuning & Persistence (Timeframe, Watched Coins, Trading Hours)
    """

    def __init__(self):
        self.bot_mode = settings.BOT_MODE  # paper_trading or alert_only
        self.max_risk_pct = settings.MAX_RISK_PER_TRADE_PCT  # e.g., 1.5%
        self.circuit_breaker_limit_pct = settings.CIRCUIT_BREAKER_DRAWDOWN_PCT  # e.g., 5.0%
        self.atr_sl_multiplier = settings.ATR_SL_MULTIPLIER  # e.g., 1.5
        self.tp_rr_ratio = settings.TAKE_PROFIT_RR_RATIO  # e.g., 2.0
        self.arbitrage_threshold_pct = 3.0  # 3.0%
        self.is_circuit_breaker_active = False
        self.breaker_reason = ""

        # Timeframe, trading hours & watched assets
        self.timeframe: str = "1h"
        self.trading_hours: str = "24/7"  # e.g. "24/7" or "07:00-23:00"
        self.watched_coins: List[str] = [
            settings.CEX_ADA_PAIR,
            settings.CEX_NIGHT_PAIR,
            "BTC/USDT",
            settings.DEX_NIGHT_PAIR,
        ]

        self.config_file = Path(__file__).resolve().parent.parent.parent / "config" / "bot_settings.json"
        self.load_settings_from_file()

    def normalize_coin_symbol(self, symbol: str) -> str:
        """Auto-standardize coin symbol: BTC -> BTC/USDT, etc."""
        s = symbol.upper().strip().replace(" ", "")
        if "/" in s:
            return s
        if s == "NIGHT":
            return "NIGHT/USDT"
        return f"{s}/USDT"

    def is_within_trading_hours(self) -> bool:
        """
        Check if current Vietnam Time (UTC+7) falls within configured trading hours.
        Returns True if 24/7 or within window.
        """
        if self.trading_hours.upper() in ["24/7", "ALL", "ALWAYS"]:
            return True

        match = re.match(r"^(\d{1,2}):(\d{2})-(\d{1,2}):(\d{2})$", self.trading_hours)
        if not match:
            return True

        h_start, m_start, h_end, m_end = map(int, match.groups())
        start_t = time(h_start, m_start)
        end_t = time(h_end, m_end)

        # Vietnam time is UTC+7
        now_vn = datetime.now(timezone.utc) + timedelta(hours=7)
        cur_t = now_vn.time()

        if start_t <= end_t:
            return start_t <= cur_t <= end_t
        else:  # Overnight session, e.g., 22:00-06:00
            return cur_t >= start_t or cur_t <= end_t

    def save_settings_to_file(self) -> None:
        """Persist current configuration to JSON file"""
        data = {
            "bot_mode": self.bot_mode,
            "max_risk_pct": self.max_risk_pct,
            "atr_sl_multiplier": self.atr_sl_multiplier,
            "tp_rr_ratio": self.tp_rr_ratio,
            "circuit_breaker_limit_pct": self.circuit_breaker_limit_pct,
            "arbitrage_threshold_pct": self.arbitrage_threshold_pct,
            "timeframe": self.timeframe,
            "trading_hours": self.trading_hours,
            "watched_coins": self.watched_coins,
            "updated_at": datetime.now(timezone.utc).isoformat(),
        }
        try:
            self.config_file.parent.mkdir(parents=True, exist_ok=True)
            with open(self.config_file, "w", encoding="utf-8") as f:
                json.dump(data, f, indent=2, ensure_ascii=False)
            logger.info("Đã lưu cấu hình tham số bot vào bot_settings.json.")
        except Exception as e:
            logger.warning(f"Lỗi khi lưu tệp cấu hình bot_settings.json: {e}")

    def load_settings_from_file(self) -> None:
        """Load persisted configuration from JSON file if present"""
        if not self.config_file.exists():
            return
        try:
            with open(self.config_file, "r", encoding="utf-8") as f:
                data = json.load(f)
            self.bot_mode = data.get("bot_mode", self.bot_mode)
            self.max_risk_pct = float(data.get("max_risk_pct", self.max_risk_pct))
            self.atr_sl_multiplier = float(data.get("atr_sl_multiplier", self.atr_sl_multiplier))
            self.tp_rr_ratio = float(data.get("tp_rr_ratio", self.tp_rr_ratio))
            self.circuit_breaker_limit_pct = float(data.get("circuit_breaker_limit_pct", self.circuit_breaker_limit_pct))
            self.arbitrage_threshold_pct = float(data.get("arbitrage_threshold_pct", self.arbitrage_threshold_pct))
            self.timeframe = data.get("timeframe", self.timeframe)
            self.trading_hours = data.get("trading_hours", self.trading_hours)
            if "watched_coins" in data and isinstance(data["watched_coins"], list):
                self.watched_coins = data["watched_coins"]
            logger.info("Đã nạp thành công cấu hình tham số tùy chỉnh từ bot_settings.json.")
        except Exception as e:
            logger.warning(f"Lỗi nạp cấu hình từ bot_settings.json: {e}")

    def update_setting(self, key: str, value: Any) -> Tuple[bool, str]:
        """Dynamically update a trading or risk parameter and persist"""
        key_lower = key.lower().strip()
        try:
            if key_lower in ["risk", "max_risk", "risk_pct"]:
                val = float(value)
                if val <= 0 or val > 20:
                    return False, "Rủi ro phải nằm trong khoảng từ 0.1% đến 20%."
                self.max_risk_pct = val
                self.save_settings_to_file()
                return True, f"Đã cập nhật Tỷ lệ Rủi ro mỗi vị thế: {self.max_risk_pct}% NAV."

            elif key_lower in ["sl", "atr_sl", "stop_loss"]:
                val = float(value)
                if val <= 0.1 or val > 10:
                    return False, "Hệ số ATR SL phải từ 0.5x đến 10x."
                self.atr_sl_multiplier = val
                self.save_settings_to_file()
                return True, f"Đã cập nhật Hệ số Cắt lỗ: {self.atr_sl_multiplier}x ATR."

            elif key_lower in ["tp", "rr", "take_profit"]:
                val = float(value)
                if val <= 0.5 or val > 20:
                    return False, "Tỷ lệ R:R chốt lời phải từ 1:0.5 đến 1:20."
                self.tp_rr_ratio = val
                self.save_settings_to_file()
                return True, f"Đã cập nhật Tỷ lệ Chốt lời: 1:{self.tp_rr_ratio} R:R."

            elif key_lower in ["tf", "timeframe", "khung", "frame"]:
                val_str = str(value).lower().strip()
                valid_tfs = ["1m", "5m", "15m", "30m", "1h", "2h", "4h", "6h", "8h", "12h", "1d"]
                if val_str not in valid_tfs:
                    return False, f"Khung nến không hợp lệ. Các khung hỗ trợ: {', '.join(valid_tfs)}"
                self.timeframe = val_str
                self.save_settings_to_file()
                return True, f"Đã đổi Khung nến theo dõi sang: {self.timeframe.upper()}."

            elif key_lower in ["hours", "trading_hours", "gio", "khung_gio"]:
                val_str = str(value).strip()
                if val_str.lower() in ["24/7", "all", "always"]:
                    self.trading_hours = "24/7"
                    self.save_settings_to_file()
                    return True, "Đã cập nhật Khung giờ giao dịch: 24/7 (Quét và giao dịch liên tục)."
                
                # Check HH:MM-HH:MM
                match = re.match(r"^(\d{1,2}):(\d{2})-(\d{1,2}):(\d{2})$", val_str)
                if not match:
                    return False, "Định dạng khung giờ không hợp lệ! Vui lòng nhập dạng 'HH:MM-HH:MM' (ví dụ: '08:00-23:00') hoặc '24/7'."
                h1, m1, h2, m2 = map(int, match.groups())
                if not (0 <= h1 <= 23 and 0 <= h2 <= 23 and 0 <= m1 <= 59 and 0 <= m2 <= 59):
                    return False, "Giờ phút không hợp lệ (Giờ từ 0-23, Phút từ 0-59)."
                self.trading_hours = f"{h1:02d}:{m1:02d}-{h2:02d}:{m2:02d}"
                self.save_settings_to_file()
                return True, f"Đã cập nhật Khung giờ giao dịch: {self.trading_hours} (Giờ Việt Nam UTC+7)."

            elif key_lower in ["coins", "pairs", "danh_sach_coin"]:
                val_str = str(value).strip()
                raw_items = [s for s in val_str.replace(";", ",").split(",") if s.strip()]
                if not raw_items:
                    return False, "Danh sách coin không được để trống."
                normalized = [self.normalize_coin_symbol(s) for s in raw_items]
                self.watched_coins = list(dict.fromkeys(normalized))
                self.save_settings_to_file()
                coins_str = ", ".join(self.watched_coins)
                return True, f"Đã cập nhật danh sách Coin theo dõi: {coins_str}."

            elif key_lower in ["add_coin", "add_pair", "them_coin"]:
                sym = self.normalize_coin_symbol(str(value))
                if sym in self.watched_coins:
                    return False, f"Cặp {sym} đã có sẵn trong danh sách theo dõi."
                self.watched_coins.append(sym)
                self.save_settings_to_file()
                return True, f"Đã thêm `{sym}` vào danh sách theo dõi. Tổng: {len(self.watched_coins)} cặp."

            elif key_lower in ["remove_coin", "del_coin", "xoa_coin", "remove_pair"]:
                sym = self.normalize_coin_symbol(str(value))
                matched = [c for c in self.watched_coins if c == sym or c.split("/")[0] == sym.split("/")[0]]
                if not matched:
                    return False, f"Không tìm thấy `{sym}` trong danh sách theo dõi."
                for m in matched:
                    self.watched_coins.remove(m)
                self.save_settings_to_file()
                return True, f"Đã xóa `{', '.join(matched)}` khỏi danh sách theo dõi. Còn lại: {len(self.watched_coins)} cặp."

            elif key_lower in ["breaker", "circuit_breaker", "drawdown"]:
                val = float(value)
                if val <= 1 or val > 50:
                    return False, "Ngưỡng Circuit Breaker phải từ 1% đến 50%."
                self.circuit_breaker_limit_pct = val
                self.save_settings_to_file()
                return True, f"Đã cập nhật Ngưỡng Circuit Breaker: {self.circuit_breaker_limit_pct}% Drawdown."

            elif key_lower in ["spread", "arbitrage", "arb"]:
                val = float(value)
                if val <= 0.5 or val > 100:
                    return False, "Ngưỡng Arbitrage Spread phải từ 0.5% đến 100%."
                self.arbitrage_threshold_pct = val
                self.save_settings_to_file()
                return True, f"Đã cập nhật Ngưỡng Cảnh báo Arbitrage: {self.arbitrage_threshold_pct}%."

            elif key_lower in ["mode", "bot_mode"]:
                val_str = str(value).lower().strip()
                if val_str in ["paper", "paper_trading"]:
                    self.bot_mode = "paper_trading"
                    self.save_settings_to_file()
                    return True, "Đã chuyển sang chế độ: 🟢 PAPER TRADING (Giao dịch giả lập)."
                elif val_str in ["alert", "alert_only"]:
                    self.bot_mode = "alert_only"
                    self.save_settings_to_file()
                    return True, "Đã chuyển sang chế độ: 🟡 ALERT ONLY (Chỉ gửi cảnh báo)."
                else:
                    return False, "Chế độ hợp lệ: paper_trading hoặc alert_only."

            return False, (
                f"Không tìm thấy thông số '{key}'.\n"
                "Các thông số hợp lệ: tf, hours, coins, add_coin, remove_coin, risk, sl, tp, breaker, spread, mode."
            )
        except Exception as e:
            return False, f"Lỗi định dạng giá trị: {e}"

    def get_all_settings(self) -> Dict[str, Any]:
        """Return dict of current settings"""
        return {
            "bot_mode": self.bot_mode,
            "max_risk_pct": self.max_risk_pct,
            "atr_sl_multiplier": self.atr_sl_multiplier,
            "tp_rr_ratio": self.tp_rr_ratio,
            "circuit_breaker_limit_pct": self.circuit_breaker_limit_pct,
            "arbitrage_threshold_pct": self.arbitrage_threshold_pct,
            "is_circuit_breaker_active": self.is_circuit_breaker_active,
            "timeframe": self.timeframe,
            "trading_hours": self.trading_hours,
            "watched_coins": self.watched_coins,
            "is_trading_active_now": self.is_within_trading_hours(),
        }

    def check_circuit_breaker(self, current_nav: float, peak_nav_24h: float) -> Tuple[bool, str]:
        """
        Check if drawdown exceeds safe threshold.
        """
        if peak_nav_24h <= 0:
            return False, ""

        drawdown_pct = ((peak_nav_24h - current_nav) / peak_nav_24h) * 100.0

        if drawdown_pct >= self.circuit_breaker_limit_pct:
            self.is_circuit_breaker_active = True
            self.breaker_reason = f"Ngắt mạch an toàn kích hoạt: Drawdown 24h đạt {drawdown_pct:.2f}% (vượt ngưỡng {self.circuit_breaker_limit_pct}%)."
            logger.critical(self.breaker_reason)
            return True, self.breaker_reason

        return False, ""

    def calculate_position_size(
        self,
        capital: float,
        entry_price: float,
        stop_loss: float,
        confidence_score: float = 0.70,
    ) -> Dict[str, Any]:
        """
        Calculate position sizing using adjusted Kelly Criterion:
        Risk Amount = Capital * max_risk_pct
        Position Quantity = Risk Amount / (Price - StopLoss)
        """
        if self.is_circuit_breaker_active:
            return {
                "allowed": False,
                "reason": f"Circuit Breaker đang bật: {self.breaker_reason}",
                "quantity": 0.0,
                "cost_basis": 0.0,
            }

        risk_per_unit = abs(entry_price - stop_loss)
        if risk_per_unit <= 0 or entry_price <= 0:
            return {"allowed": False, "reason": "Khoảng cách Stop-Loss không hợp lệ.", "quantity": 0.0, "cost_basis": 0.0}

        # Half-Kelly multiplier adjusted by AI confidence
        effective_risk_pct = self.max_risk_pct * min(1.2, max(0.5, confidence_score))
        max_risk_dollars = capital * (effective_risk_pct / 100.0)

        units = max_risk_dollars / risk_per_unit
        cost = units * entry_price

        # Cap max position cost to 25% of total capital to maintain liquidity
        max_cost_cap = capital * 0.25
        if cost > max_cost_cap:
            cost = max_cost_cap
            units = cost / entry_price

        return {
            "allowed": True,
            "reason": "OK",
            "quantity": round(units, 4),
            "cost_basis": round(cost, 2),
            "risk_amount": round(max_risk_dollars, 2),
            "risk_pct": round(effective_risk_pct, 2),
        }

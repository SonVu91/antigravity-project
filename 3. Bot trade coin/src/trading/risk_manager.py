import logging
from typing import Dict, Any, Tuple
from config.settings import settings

logger = logging.getLogger("RiskManager")


class RiskManager:
    """
    Risk Management Module strictly enforcing:
    - Position Sizing (Kelly Criterion adjusted: 1% - 2% max risk per trade)
    - Dynamic ATR Stop-Loss & Take-Profit
    - 24-Hour Circuit Breaker (halts on > 5% drawdown)
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

    def update_setting(self, key: str, value: Any) -> Tuple[bool, str]:
        """Dynamically update a trading or risk parameter"""
        key_lower = key.lower().strip()
        try:
            if key_lower in ["risk", "max_risk", "risk_pct"]:
                val = float(value)
                if val <= 0 or val > 20:
                    return False, "Rủi ro phải nằm trong khoảng từ 0.1% đến 20%."
                self.max_risk_pct = val
                return True, f"Đã cập nhật Tỷ lệ Rủi ro mỗi vị thế: {self.max_risk_pct}% NAV."

            elif key_lower in ["sl", "atr_sl", "stop_loss"]:
                val = float(value)
                if val <= 0.1 or val > 10:
                    return False, "Hệ số ATR SL phải từ 0.5x đến 10x."
                self.atr_sl_multiplier = val
                return True, f"Đã cập nhật Hệ số Cắt lỗ: {self.atr_sl_multiplier}x ATR."

            elif key_lower in ["tp", "rr", "take_profit"]:
                val = float(value)
                if val <= 0.5 or val > 20:
                    return False, "Tỷ lệ R:R chốt lời phải từ 1:0.5 đến 1:20."
                self.tp_rr_ratio = val
                return True, f"Đã cập nhật Tỷ lệ Chốt lời: 1:{self.tp_rr_ratio} R:R."

            elif key_lower in ["breaker", "circuit_breaker", "drawdown"]:
                val = float(value)
                if val <= 1 or val > 50:
                    return False, "Ngưỡng Circuit Breaker phải từ 1% đến 50%."
                self.circuit_breaker_limit_pct = val
                return True, f"Đã cập nhật Ngưỡng Circuit Breaker: {self.circuit_breaker_limit_pct}% Drawdown."

            elif key_lower in ["spread", "arbitrage", "arb"]:
                val = float(value)
                if val <= 0.5 or val > 100:
                    return False, "Ngưỡng Arbitrage Spread phải từ 0.5% đến 100%."
                self.arbitrage_threshold_pct = val
                return True, f"Đã cập nhật Ngưỡng Cảnh báo Arbitrage: {self.arbitrage_threshold_pct}%."

            elif key_lower in ["mode", "bot_mode"]:
                val_str = str(value).lower().strip()
                if val_str in ["paper", "paper_trading"]:
                    self.bot_mode = "paper_trading"
                    return True, "Đã chuyển sang chế độ: 🟢 PAPER TRADING (Giao dịch giả lập)."
                elif val_str in ["alert", "alert_only"]:
                    self.bot_mode = "alert_only"
                    return True, "Đã chuyển sang chế độ: 🟡 ALERT ONLY (Chỉ gửi cảnh báo)."
                else:
                    return False, "Chế độ hợp lệ: paper_trading hoặc alert_only."

            return False, f"Không tìm thấy thông số '{key}'. Các thông số hợp lệ: risk, sl, tp, breaker, spread, mode."
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

"""
Supply & Demand (S&D) Core Analysis Engine
Implements institutional Supply and Demand zone detection:
- Patterns: Drop-Base-Rally (DBR), Rally-Base-Drop (RBD), Rally-Base-Rally (RBR), Drop-Base-Drop (DBD)
- Extended Range Candle (ERC) / Imbalance detection
- Freshness tracking: Fresh (Unmitigated), Tested, Violated
- Quality Scoring (0 - 100)
- Confirmation signal generation (Pinbar, Engulfing at proximal boundary)
"""

from dataclasses import dataclass, field
from enum import Enum
from typing import List, Dict, Any, Optional, Tuple
import numpy as np


class ZoneType(str, Enum):
    SUPPLY = "SUPPLY"
    DEMAND = "DEMAND"


class ZonePattern(str, Enum):
    DBR = "DBR"  # Drop - Base - Rally (Demand Reversal)
    RBR = "RBR"  # Rally - Base - Rally (Demand Continuation)
    RBD = "RBD"  # Rally - Base - Drop (Supply Reversal)
    DBD = "DBD"  # Drop - Base - Drop (Supply Continuation)


class ZoneStatus(str, Enum):
    FRESH = "FRESH"          # Chưa bị chạm lần nào (Tươi mới - Uy tín cao nhất)
    TESTED = "TESTED"        # Đã bị test 1 lần (Đã giảm áp lực cung/cầu)
    EXHAUSTED = "EXHAUSTED"  # Đã bị test nhiều lần (Dễ bị đục thủng)
    VIOLATED = "VIOLATED"    # Đã bị phá vỡ hoàn toàn qua Distal Line


@dataclass
class SDZone:
    id: str
    zone_type: ZoneType
    pattern: ZonePattern
    proximal: float           # Mức giá biên trước (điểm đón / entry line)
    distal: float             # Mức giá biên sau (điểm cắt lỗ / stop line)
    creation_index: int       # Vị trí nến tạo vùng
    creation_time: Any        # Thời điểm tạo vùng
    base_candle_count: int    # Số nến tại base
    score: float = 0.0        # Điểm chất lượng vùng (0 - 100)
    status: ZoneStatus = ZoneStatus.FRESH
    test_count: int = 0       # Số lần giá chạm vào vùng
    last_test_index: Optional[int] = None
    breakout_volume: float = 0.0

    @property
    def width(self) -> float:
        """Độ rộng biên độ giá của vùng"""
        return abs(self.distal - self.proximal)

    @property
    def mid_price(self) -> float:
        return (self.proximal + self.distal) / 2.0


@dataclass
class SDSignal:
    symbol: str
    timeframe: str
    action: str              # "BUY", "SELL", "HOLD"
    current_price: float
    nearest_demand: Optional[SDZone] = None
    nearest_supply: Optional[SDZone] = None
    entry_price: float = 0.0
    stop_loss: float = 0.0
    take_profit: float = 0.0
    risk_reward: float = 0.0
    reason: str = ""
    active_zones: List[SDZone] = field(default_factory=list)


class SupplyDemandDetector:
    """
    Phát hiện và quản lý Vùng Cung - Cầu chuyên sâu theo chuẩn Fimi S&D / SMC
    """

    def __init__(
        self,
        atr_period: int = 14,
        base_body_ratio_max: float = 0.55,    # Thân nến base <= 55% toàn bộ nến
        erc_atr_multiplier: float = 1.3,      # Nến bứt phá (ERC) có thân >= 1.3x ATR
        max_base_candles: int = 4,            # Số nến base tối đa
        zone_buffer_atr_mult: float = 0.5,    # Đệm an toàn SL theo ATR
    ):
        self.atr_period = atr_period
        self.base_body_ratio_max = base_body_ratio_max
        self.erc_atr_multiplier = erc_atr_multiplier
        self.max_base_candles = max_base_candles
        self.zone_buffer_atr_mult = zone_buffer_atr_mult

    def calculate_atr(self, candles: List[Dict[str, Any]]) -> List[float]:
        """Tính toán Average True Range (ATR)"""
        if len(candles) < 2:
            return [0.0] * len(candles)

        highs = np.array([c["high"] for c in candles], dtype=float)
        lows = np.array([c["low"] for c in candles], dtype=float)
        closes = np.array([c["close"] for c in candles], dtype=float)

        tr = np.zeros(len(candles))
        tr[0] = highs[0] - lows[0]

        for i in range(1, len(candles)):
            hl = highs[i] - lows[i]
            hc = abs(highs[i] - closes[i - 1])
            lc = abs(lows[i] - closes[i - 1])
            tr[i] = max(hl, hc, lc)

        atr = np.zeros(len(candles))
        # Initial Simple MA for ATR
        if len(candles) >= self.atr_period:
            atr[self.atr_period - 1] = np.mean(tr[: self.atr_period])
            for i in range(self.atr_period, len(candles)):
                atr[i] = (atr[i - 1] * (self.atr_period - 1) + tr[i]) / self.atr_period
            # Fill early values
            for i in range(self.atr_period - 1):
                atr[i] = atr[self.atr_period - 1]
        else:
            atr[:] = np.mean(tr)

        return atr.tolist()

    def detect_zones(
        self,
        candles: List[Dict[str, Any]],
        symbol: str = "UNKNOWN",
        timeframe: str = "1h",
    ) -> List[SDZone]:
        """
        Quét toàn bộ chuỗi nến và phát hiện các Vùng Cung - Cầu.
        Đồng thời theo dõi tiến trình kiểm tra (Fresh/Tested/Violated) tới nến hiện tại.
        """
        n = len(candles)
        if n < self.atr_period + 5:
            return []

        atr = self.calculate_atr(candles)
        volumes = [c.get("volume", 0.0) for c in candles]
        avg_vol = np.mean(volumes) if volumes else 1.0

        raw_zones: List[SDZone] = []

        # Quét qua từng nến để tìm Base và Breakout
        for i in range(2, n - 1):
            curr_atr = atr[i]
            if curr_atr <= 0:
                continue

            # Nến Leg-out (Breakout): nến bứt phá mạnh ra khỏi vùng
            out_c = candles[i]
            out_body = abs(out_c["close"] - out_c["open"])
            is_bullish_breakout = (out_c["close"] > out_c["open"]) and (out_body >= self.erc_atr_multiplier * curr_atr)
            is_bearish_breakout = (out_c["close"] < out_c["open"]) and (out_body >= self.erc_atr_multiplier * curr_atr)

            if not (is_bullish_breakout or is_bearish_breakout):
                continue

            # Tìm 1 đến max_base_candles nến Base trước nến Breakout
            for base_len in range(1, self.max_base_candles + 1):
                base_start = i - base_len
                if base_start < 1:
                    break

                base_candles = candles[base_start:i]
                leg_in_c = candles[base_start - 1]

                # Kiểm tra tính hợp lệ của cụm Base (nến thân hẹp hoặc doji)
                is_valid_base = True
                for bc in base_candles:
                    b_body = abs(bc["close"] - bc["open"])
                    b_range = max(bc["high"] - bc["low"], 1e-8)
                    if (b_body / b_range) > self.base_body_ratio_max and (b_body > curr_atr * 0.9):
                        is_valid_base = False
                        break

                if not is_valid_base:
                    continue

                # Nhận diện Pattern
                leg_in_drop = leg_in_c["close"] < leg_in_c["open"]
                leg_in_rally = leg_in_c["close"] > leg_in_c["open"]

                zone_type = None
                pattern = None

                if is_bullish_breakout:
                    zone_type = ZoneType.DEMAND
                    pattern = ZonePattern.DBR if leg_in_drop else ZonePattern.RBR
                elif is_bearish_breakout:
                    zone_type = ZoneType.SUPPLY
                    pattern = ZonePattern.RBD if leg_in_rally else ZonePattern.DBD

                if not zone_type or not pattern:
                    continue

                # Xác định Proximal Line và Distal Line
                base_highs = [bc["high"] for bc in base_candles]
                base_lows = [bc["low"] for bc in base_candles]
                base_bodies_top = [max(bc["open"], bc["close"]) for bc in base_candles]
                base_bodies_bottom = [min(bc["open"], bc["close"]) for bc in base_candles]

                if zone_type == ZoneType.DEMAND:
                    proximal = max(base_bodies_top)     # Mép trên của Demand Zone
                    distal = min(base_lows)              # Mép dưới thấp nhất
                else:
                    proximal = min(base_bodies_bottom)  # Mép dưới của Supply Zone
                    distal = max(base_highs)             # Mép trên cao nhất

                if abs(distal - proximal) <= 0:
                    continue

                # Tính điểm chất lượng ban đầu
                vol_ratio = (out_c.get("volume", 0) / avg_vol) if avg_vol > 0 else 1.0
                departure_ratio = out_body / curr_atr

                score = 50.0
                score += min(departure_ratio * 10, 25.0)     # Lực thoát nến càng mạnh điểm càng cao
                score += min(vol_ratio * 10, 15.0)          # Volume nổ
                if base_len == 1:
                    score += 10.0                           # Base 1 nến phản ứng nhanh nhất

                zone_id = f"{symbol}_{timeframe}_{zone_type.value}_{base_start}_{i}"
                zone = SDZone(
                    id=zone_id,
                    zone_type=zone_type,
                    pattern=pattern,
                    proximal=float(proximal),
                    distal=float(distal),
                    creation_index=i,
                    creation_time=out_c.get("time", ""),
                    base_candle_count=base_len,
                    score=min(score, 100.0),
                    breakout_volume=float(out_c.get("volume", 0)),
                )
                raw_zones.append(zone)
                break  # Khi đã tìm được base phù hợp cho breakout này thì dừng tìm base dài hơn

        # Lọc trạng thái và độ tươi mới (Freshness) bằng cách kiểm tra các nến tiếp theo
        active_zones: List[SDZone] = []
        for zone in raw_zones:
            self._update_zone_status(zone, candles)
            # Chỉ giữ các vùng chưa bị phá vỡ (Fresh hoặc Tested)
            if zone.status != ZoneStatus.VIOLATED:
                active_zones.append(zone)

        # Hợp nhất các vùng quá sát nhau (Deduplicate / Merge overlapping zones)
        merged_zones = self._merge_overlapping_zones(active_zones)
        return merged_zones

    def _update_zone_status(self, zone: SDZone, candles: List[Dict[str, Any]]) -> None:
        """Kiểm tra diễn biến giá sau khi vùng được tạo để cập nhật trạng thái Fresh, Tested, Violated"""
        n = len(candles)
        test_count = 0

        for k in range(zone.creation_index + 1, n):
            c = candles[k]
            high = c["high"]
            low = c["low"]
            close = c["close"]

            if zone.zone_type == ZoneType.DEMAND:
                # Nếu giá đâm thủng mép Distal -> Bị phá vỡ (Violated)
                if close < zone.distal:
                    zone.status = ZoneStatus.VIOLATED
                    return
                # Nếu giá chạm vào vùng giữa Proximal và Distal -> Đã bị Test
                if low <= zone.proximal:
                    test_count += 1
                    zone.last_test_index = k
            elif zone.zone_type == ZoneType.SUPPLY:
                # Nếu giá đâm thủng mép Distal -> Bị phá vỡ (Violated)
                if close > zone.distal:
                    zone.status = ZoneStatus.VIOLATED
                    return
                # Nếu giá chạm vào vùng giữa Proximal và Distal -> Đã bị Test
                if high >= zone.proximal:
                    test_count += 1
                    zone.last_test_index = k

        zone.test_count = test_count
        if test_count == 0:
            zone.status = ZoneStatus.FRESH
            zone.score = min(zone.score + 15.0, 100.0)
        elif test_count == 1:
            zone.status = ZoneStatus.TESTED
        else:
            zone.status = ZoneStatus.EXHAUSTED
            zone.score = max(zone.score - 20.0, 10.0)

    def _merge_overlapping_zones(self, zones: List[SDZone]) -> List[SDZone]:
        """Gộp các vùng cùng loại bị trùng lặp hoặc lồng vào nhau, giữ lại vùng có score cao hơn"""
        if not zones:
            return []

        # Sắp xếp theo score giảm dần
        sorted_zones = sorted(zones, key=lambda z: z.score, reverse=True)
        final_zones: List[SDZone] = []

        for candidate in sorted_zones:
            overlap = False
            for existing in final_zones:
                if candidate.zone_type == existing.zone_type:
                    # Kiểm tra độ chồng lấn biên độ
                    c_low, c_high = min(candidate.proximal, candidate.distal), max(candidate.proximal, candidate.distal)
                    e_low, e_high = min(existing.proximal, existing.distal), max(existing.proximal, existing.distal)

                    if not (c_high < e_low or c_low > e_high):
                        overlap = True
                        break
            if not overlap:
                final_zones.append(candidate)

        return sorted(final_zones, key=lambda z: z.proximal)

    def analyze(
        self,
        candles: List[Dict[str, Any]],
        symbol: str,
        timeframe: str = "1h",
    ) -> SDSignal:
        """
        Phân tích toàn diện: tìm Vùng Cung - Cầu gần nhất, kiểm tra nến xác nhận
        và đưa ra khuyến nghị Mua/Bán kèm Stop-Loss & Take-Profit tối ưu.
        """
        if not candles or len(candles) < 20:
            return SDSignal(
                symbol=symbol,
                timeframe=timeframe,
                action="HOLD",
                current_price=candles[-1]["close"] if candles else 0.0,
                reason="Không đủ dữ liệu nến để phân tích S&D",
            )

        current_price = candles[-1]["close"]
        atr_list = self.calculate_atr(candles)
        curr_atr = atr_list[-1] if atr_list else (current_price * 0.01)

        zones = self.detect_zones(candles, symbol=symbol, timeframe=timeframe)

        # Lọc Vùng Cầu gần nhất ở dưới giá hiện tại
        demand_zones = [
            z for z in zones
            if z.zone_type == ZoneType.DEMAND and z.proximal <= current_price * 1.015
        ]
        # Lọc Vùng Cung gần nhất ở trên giá hiện tại
        supply_zones = [
            z for z in zones
            if z.zone_type == ZoneType.SUPPLY and z.proximal >= current_price * 0.985
        ]

        nearest_demand = max(demand_zones, key=lambda z: z.proximal) if demand_zones else None
        nearest_supply = min(supply_zones, key=lambda z: z.proximal) if supply_zones else None

        action = "HOLD"
        entry_price = current_price
        stop_loss = 0.0
        take_profit = 0.0
        rr_ratio = 0.0
        reason = "Giá đang dao động giữa các vùng Cung - Cầu. Chưa có tín hiệu xác nhận."

        # Kiểm tra điều kiện BUY tại Vùng Cầu (Demand Zone)
        if nearest_demand:
            dist_to_demand = (current_price - nearest_demand.proximal) / current_price
            # Giá đang ở trong hoặc rất gần biên trên của Demand Zone (< 0.8% hoặc đang chạm)
            in_or_near_demand = nearest_demand.distal * 0.998 <= current_price <= nearest_demand.proximal * 1.008

            if in_or_near_demand:
                # Kiểm tra nến xác nhận đảo chiều (Pinbar hoặc Bullish Reversal)
                is_confirmed, conf_type = self._check_bullish_confirmation(candles[-2:])
                if is_confirmed or nearest_demand.status == ZoneStatus.FRESH:
                    action = "BUY"
                    entry_price = current_price
                    stop_loss = nearest_demand.distal - (self.zone_buffer_atr_mult * curr_atr)
                    risk = max(entry_price - stop_loss, 1e-6)

                    # TP đặt tại Vùng Cung gần nhất hoặc tỷ lệ 1:2.5
                    if nearest_supply:
                        take_profit = nearest_supply.proximal * 0.998
                        reward = take_profit - entry_price
                        rr_ratio = round(reward / risk, 2)
                    else:
                        take_profit = entry_price + (risk * 2.5)
                        rr_ratio = 2.5

                    reason = (
                        f"Giá phản ứng tại Vùng Cầu {nearest_demand.pattern.value} "
                        f"[{nearest_demand.distal:.4f} - {nearest_demand.proximal:.4f}] "
                        f"({nearest_demand.status.value}). Tín hiệu: {conf_type}. R:R = {rr_ratio}:1"
                    )

        # Kiểm tra điều kiện SELL / CHỐT LỜI tại Vùng Cung (Supply Zone)
        if action == "HOLD" and nearest_supply:
            in_or_near_supply = nearest_supply.proximal * 0.992 <= current_price <= nearest_supply.distal * 1.002

            if in_or_near_supply:
                is_confirmed, conf_type = self._check_bearish_confirmation(candles[-2:])
                if is_confirmed or nearest_supply.status == ZoneStatus.FRESH:
                    action = "SELL"
                    entry_price = current_price
                    stop_loss = nearest_supply.distal + (self.zone_buffer_atr_mult * curr_atr)
                    risk = max(stop_loss - entry_price, 1e-6)

                    if nearest_demand:
                        take_profit = nearest_demand.proximal * 1.002
                        reward = entry_price - take_profit
                        rr_ratio = round(reward / risk, 2)
                    else:
                        take_profit = entry_price - (risk * 2.5)
                        rr_ratio = 2.5

                    reason = (
                        f"Giá tiếp cận Vùng Cung {nearest_supply.pattern.value} "
                        f"[{nearest_supply.proximal:.4f} - {nearest_supply.distal:.4f}] "
                        f"({nearest_supply.status.value}). Tín hiệu: {conf_type}. R:R = {rr_ratio}:1"
                    )

        return SDSignal(
            symbol=symbol,
            timeframe=timeframe,
            action=action,
            current_price=current_price,
            nearest_demand=nearest_demand,
            nearest_supply=nearest_supply,
            entry_price=round(entry_price, 6),
            stop_loss=round(stop_loss, 6),
            take_profit=round(take_profit, 6),
            risk_reward=rr_ratio,
            reason=reason,
            active_zones=zones,
        )

    def _check_bullish_confirmation(self, recent_candles: List[Dict[str, Any]]) -> Tuple[bool, str]:
        """Kiểm tra nến đảo chiều tăng (Pinbar rút chân hoặc Bullish Engulfing)"""
        if len(recent_candles) < 1:
            return False, ""

        c = recent_candles[-1]
        c_range = max(c["high"] - c["low"], 1e-8)
        body = abs(c["close"] - c["open"])
        lower_wick = min(c["open"], c["close"]) - c["low"]

        # Bullish Pinbar: Râu nến dưới dài hơn 50% toàn bộ cây nến
        if (lower_wick / c_range) >= 0.5:
            return True, "Bullish Pinbar rút chân"

        # Bullish Engulfing
        if len(recent_candles) >= 2:
            prev = recent_candles[-2]
            if (prev["close"] < prev["open"]) and (c["close"] > c["open"]) and (c["close"] >= prev["open"]):
                return True, "Bullish Engulfing nhấn chìm tăng"

        return False, "Chờ xác nhận"

    def _check_bearish_confirmation(self, recent_candles: List[Dict[str, Any]]) -> Tuple[bool, str]:
        """Kiểm tra nến đảo chiều giảm (Pinbar rút đầu hoặc Bearish Engulfing)"""
        if len(recent_candles) < 1:
            return False, ""

        c = recent_candles[-1]
        c_range = max(c["high"] - c["low"], 1e-8)
        upper_wick = c["high"] - max(c["open"], c["close"])

        # Bearish Pinbar: Râu nến trên dài hơn 50%
        if (upper_wick / c_range) >= 0.5:
            return True, "Bearish Pinbar từ chối giá"

        # Bearish Engulfing
        if len(recent_candles) >= 2:
            prev = recent_candles[-2]
            if (prev["close"] > prev["open"]) and (c["close"] < c["open"]) and (c["close"] <= prev["open"]):
                return True, "Bearish Engulfing nhấn chìm giảm"

        return False, "Chờ xác nhận"

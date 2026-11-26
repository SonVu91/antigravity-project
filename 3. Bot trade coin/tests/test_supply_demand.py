import os
import sys
import unittest
from datetime import datetime, timezone, timedelta
import re

# Ensure project root is in path
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from src.ai.supply_demand import (
    SupplyDemandDetector,
    ZoneType,
    ZonePattern,
    ZoneStatus,
    SDSignal,
)
from src.bot.charts import generate_sd_chart


class TestSupplyDemandEngine(unittest.TestCase):

    def setUp(self):
        self.detector = SupplyDemandDetector(atr_period=5, erc_atr_multiplier=1.2)

    def _generate_synthetic_candles(self, n=50, base_price=100.0, trend="sideway"):
        candles = []
        now = datetime.now(timezone.utc)
        p = base_price
        for i in range(n):
            ts = now - timedelta(hours=n - i)
            if trend == "bull":
                p += 1.0
            elif trend == "bear":
                p -= 1.0
            o = p
            h = p + 0.8
            l = p - 0.8
            c = p + 0.2
            v = 1000.0 + (i * 20)
            candles.append({
                "time": ts.strftime("%Y-%m-%d %H:%M"),
                "timestamp": ts,
                "open": round(o, 2),
                "high": round(h, 2),
                "low": round(l, 2),
                "close": round(c, 2),
                "volume": float(v),
            })
        return candles

    def test_01_atr_calculation(self):
        candles = self._generate_synthetic_candles(20)
        atr = self.detector.calculate_atr(candles)
        self.assertEqual(len(atr), 20)
        self.assertTrue(all(a > 0 for a in atr))

    def test_02_dbr_demand_zone_detection(self):
        """Test Drop - Base - Rally pattern creating a Demand Zone"""
        candles = self._generate_synthetic_candles(25, base_price=100.0)

        # Inject DBR pattern:
        # Candle 15: Drop (Leg-in)
        candles[15]["open"] = 105.0
        candles[15]["close"] = 98.0
        candles[15]["high"] = 105.5
        candles[15]["low"] = 97.5

        # Candle 16: Base (small doji / narrow body)
        candles[16]["open"] = 98.0
        candles[16]["close"] = 98.2
        candles[16]["high"] = 98.6
        candles[16]["low"] = 97.0

        # Candle 17: Rally (Leg-out explosive ERC candle)
        candles[17]["open"] = 98.2
        candles[17]["close"] = 106.0
        candles[17]["high"] = 106.5
        candles[17]["low"] = 98.0
        candles[17]["volume"] = 95000.0

        # Subsequent candles keep price high (fresh zone)
        for k in range(18, 25):
            candles[k]["open"] = 106.0 + (k - 18) * 0.5
            candles[k]["close"] = 106.3 + (k - 18) * 0.5
            candles[k]["high"] = 107.0 + (k - 18) * 0.5
            candles[k]["low"] = 105.8 + (k - 18) * 0.5

        zones = self.detector.detect_zones(candles, symbol="BTC/USDT", timeframe="1h")
        demand_zones = [z for z in zones if z.zone_type == ZoneType.DEMAND]

        self.assertGreaterEqual(len(demand_zones), 1)
        z = demand_zones[0]
        self.assertEqual(z.zone_type, ZoneType.DEMAND)
        self.assertEqual(z.pattern, ZonePattern.DBR)
        self.assertEqual(z.status, ZoneStatus.FRESH)
        self.assertAlmostEqual(z.distal, 97.0, places=1)
        self.assertAlmostEqual(z.proximal, 98.2, places=1)

    def test_03_rbd_supply_zone_detection(self):
        """Test Rally - Base - Drop pattern creating a Supply Zone"""
        candles = self._generate_synthetic_candles(25, base_price=100.0)

        # Candle 15: Rally (Leg-in)
        candles[15]["open"] = 95.0
        candles[15]["close"] = 102.0
        candles[15]["high"] = 102.5
        candles[15]["low"] = 94.5

        # Candle 16: Base
        candles[16]["open"] = 102.0
        candles[16]["close"] = 101.8
        candles[16]["high"] = 102.8
        candles[16]["low"] = 101.2

        # Candle 17: Drop (Leg-out ERC breakdown)
        candles[17]["open"] = 101.8
        candles[17]["close"] = 94.0
        candles[17]["high"] = 102.0
        candles[17]["low"] = 93.5
        candles[17]["volume"] = 80000.0

        # Subsequent candles stay low
        for k in range(18, 25):
            candles[k]["open"] = 93.0
            candles[k]["close"] = 93.2
            candles[k]["high"] = 93.8
            candles[k]["low"] = 92.5

        zones = self.detector.detect_zones(candles, symbol="ADA/USDT", timeframe="4h")
        supply_zones = [z for z in zones if z.zone_type == ZoneType.SUPPLY]

        self.assertGreaterEqual(len(supply_zones), 1)
        s = supply_zones[0]
        self.assertEqual(s.zone_type, ZoneType.SUPPLY)
        self.assertEqual(s.pattern, ZonePattern.RBD)
        self.assertEqual(s.status, ZoneStatus.FRESH)
        self.assertAlmostEqual(s.distal, 102.8, places=1)

    def test_04_zone_mitigation_and_violation(self):
        """Test status transitions: FRESH -> TESTED -> VIOLATED"""
        candles = self._generate_synthetic_candles(30, base_price=100.0)

        # DBR at candle 10
        candles[8]["open"] = 102.0
        candles[8]["close"] = 98.0
        candles[9]["open"] = 98.0
        candles[9]["close"] = 98.1
        candles[9]["low"] = 97.0
        candles[9]["high"] = 98.3
        candles[10]["open"] = 98.1
        candles[10]["close"] = 104.0
        candles[10]["volume"] = 99999.0

        # Candle 15 tests the zone (low reaches into 97.5)
        candles[15]["low"] = 97.5
        candles[15]["close"] = 100.0

        zones_tested = self.detector.detect_zones(candles[:18], symbol="TEST", timeframe="1h")
        if zones_tested:
            self.assertEqual(zones_tested[0].status, ZoneStatus.TESTED)
            self.assertEqual(zones_tested[0].test_count, 1)

        # Candle 25 violates the zone (close breaks below distal 97.0)
        candles[25]["close"] = 95.0
        candles[25]["low"] = 94.0

        zones_after_drop = self.detector.detect_zones(candles, symbol="TEST", timeframe="1h")
        active_demand_zones = [z for z in zones_after_drop if z.zone_type == ZoneType.DEMAND]
        # The demand zone at distal 97.0 was violated and removed from active demand
        self.assertEqual(len(active_demand_zones), 0)

    def test_05_comprehensive_analyze_signal(self):
        """Test full analyze method returning SDSignal"""
        candles = self._generate_synthetic_candles(40, base_price=0.85)
        signal = self.detector.analyze(candles, symbol="ADA/USDT", timeframe="4h")

        self.assertIsInstance(signal, SDSignal)
        self.assertEqual(signal.symbol, "ADA/USDT")
        self.assertEqual(signal.timeframe, "4h")
        self.assertIn(signal.action, ["BUY", "SELL", "HOLD"])
        self.assertGreater(signal.current_price, 0.0)

    def test_06_chart_generation(self):
        """Test dark mode chart generation with S&D zones"""
        candles = self._generate_synthetic_candles(40, base_price=50000.0)
        sig = self.detector.analyze(candles, symbol="BTC/USDT", timeframe="1d")

        chart_path = generate_sd_chart(
            candles=candles,
            symbol="BTC/USDT",
            timeframe="1d",
            zones=sig.active_zones,
            signal=sig,
        )

        self.assertIsNotNone(chart_path)
        self.assertTrue(os.path.exists(chart_path))
        self.assertGreater(os.path.getsize(chart_path), 5000)

    def test_07_fimi_query_regex_parser(self):
        """Test parsing of FimiSDbot style queries"""
        pattern3 = r"^\?([a-zA-Z0-9]+)\s*,\s*([a-zA-Z0-9]+)\s*,\s*([a-zA-Z0-9]+)$"

        m1 = re.match(pattern3, "?btc,usdt,d1")
        self.assertIsNotNone(m1)
        self.assertEqual(m1.groups(), ("btc", "usdt", "d1"))

        m2 = re.match(pattern3, "?night,ada,h4")
        self.assertIsNotNone(m2)
        self.assertEqual(m2.groups(), ("night", "ada", "h4"))

        m3 = re.match(pattern3, "?ADA, USDT, 1h")
        self.assertIsNotNone(m3)
        self.assertEqual(m3.groups(), ("ADA", "USDT", "1h"))


if __name__ == "__main__":
    unittest.main()

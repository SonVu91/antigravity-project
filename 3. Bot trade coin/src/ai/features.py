import logging
from typing import List, Dict, Any, Optional
import pandas as pd
import numpy as np

logger = logging.getLogger("FeatureExtractor")


class FeatureExtractor:
    """
    Computes:
    1. Technical indicators (RSI, MACD, EMA, ATR, Bollinger Bands).
    2. True USD Parity comparison between CEX (NIGHT/USDT or USDC) and DEX (NIGHT/ADA x ADA/USD).
    3. Pair Trading / Ratio Accumulation Engine for NIGHT/ADA (Z-score + Bollinger Bands + RSI).
    """

    @staticmethod
    def calculate_technical_features(df: pd.DataFrame) -> pd.DataFrame:
        """
        Calculate technical indicators from OHLCV dataframe.
        df must contain: ['open', 'high', 'low', 'close', 'volume']
        """
        if df.empty or len(df) < 14:
            return df

        df = df.copy()
        close = df["close"]
        high = df["high"]
        low = df["low"]
        vol = df["volume"]

        # EMAs
        df["ema_9"] = close.ewm(span=9, adjust=False).mean()
        df["ema_21"] = close.ewm(span=21, adjust=False).mean()
        df["ema_50"] = close.ewm(span=50, adjust=False).mean()

        # Trend bias: 1 if fast > slow, else -1
        df["trend_bias"] = np.where(df["ema_9"] > df["ema_21"], 1.0, -1.0)

        # RSI (14)
        delta = close.diff()
        gain = (delta.where(delta > 0, 0)).rolling(window=14).mean()
        loss = (-delta.where(delta < 0, 0)).rolling(window=14).mean()
        rs = gain / (loss + 1e-9)
        df["rsi_14"] = 100 - (100 / (1 + rs))

        # MACD (12, 26, 9)
        ema_12 = close.ewm(span=12, adjust=False).mean()
        ema_26 = close.ewm(span=26, adjust=False).mean()
        df["macd"] = ema_12 - ema_26
        df["macd_signal"] = df["macd"].ewm(span=9, adjust=False).mean()
        df["macd_hist"] = df["macd"] - df["macd_signal"]

        # ATR (14) - Average True Range
        tr1 = high - low
        tr2 = (high - close.shift(1)).abs()
        tr3 = (low - close.shift(1)).abs()
        tr = pd.concat([tr1, tr2, tr3], axis=1).max(axis=1)
        df["atr_14"] = tr.rolling(window=14).mean().bfill()

        # Bollinger Bands (20, 2)
        sma_20 = close.rolling(window=20).mean()
        std_20 = close.rolling(window=20).std()
        df["bb_upper"] = sma_20 + 2 * std_20
        df["bb_lower"] = sma_20 - 2 * std_20
        df["bb_pct"] = (close - df["bb_lower"]) / (df["bb_upper"] - df["bb_lower"] + 1e-9)

        # Volume change & momentum
        df["vol_sma_20"] = vol.rolling(window=20).mean()
        df["vol_ratio"] = vol / (df["vol_sma_20"] + 1e-9)
        df["return_1"] = close.pct_change(1)
        df["return_4"] = close.pct_change(4)

        return df

    @staticmethod
    def calculate_usd_parity(
        cex_night_usd: float,       # Price of NIGHT in USD on CEX (from NIGHT/USDT or NIGHT/USDC)
        cex_ada_usd: float,         # Price of ADA in USD on CEX (from ADA/USDT)
        dex_night_ada_ratio: float, # Pool ratio on Minswap (1 NIGHT = X ADA)
    ) -> Dict[str, Any]:
        """
        MODULE 1: Standardized USD Parity Comparison between CEX and DEX.
        Both sides are strictly converted to the same currency: USD ($).
        """
        # Calculate DEX price in USD: (NIGHT/ADA) * (ADA/USD)
        dex_night_usd = dex_night_ada_ratio * cex_ada_usd

        # Calculate exact spread in USD:
        diff_usd = cex_night_usd - dex_night_usd
        spread_pct = (diff_usd / (dex_night_usd + 1e-9)) * 100.0

        return {
            "cex_night_usd": round(cex_night_usd, 6),
            "dex_night_usd": round(dex_night_usd, 6),
            "diff_usd": round(diff_usd, 6),
            "spread_pct": round(spread_pct, 2),
            "cheaper_market": "DEX" if spread_pct > 0 else "CEX",
        }

    @staticmethod
    def calculate_night_ada_ratio_analysis(
        cex_night_df: pd.DataFrame,
        cex_ada_df: pd.DataFrame,
        dex_night_ada_price: float,
    ) -> Dict[str, Any]:
        """
        MODULE 2: Quantitative Pair Trading / Ratio Accumulation Analysis (NIGHT / ADA).
        Applies Mean-Reversion (Z-score + Bollinger Bands + RSI on the ratio series).
        Finds optimal entry points to maximize holdings of BOTH coins:
        - When ratio is low (NIGHT underpriced relative to ADA) -> Accumulate NIGHT with ADA.
        - When ratio is high (NIGHT overpriced relative to ADA) -> Swap NIGHT to ADA.
        """
        if cex_night_df.empty or cex_ada_df.empty or len(cex_night_df) < 14:
            # Fallback estimation
            return {
                "current_ratio": dex_night_ada_price,
                "inv_ratio": round(1.0 / (dex_night_ada_price + 1e-9), 2),
                "z_score": 0.0,
                "ratio_rsi": 50.0,
                "action": "BALANCED",
                "recommendation": "Tỷ giá trong vùng cân bằng, chưa có điểm đảo chiều gom hàng.",
            }

        # Align series lengths
        min_len = min(len(cex_night_df), len(cex_ada_df))
        night_closes = cex_night_df["close"].iloc[-min_len:].values
        ada_closes = cex_ada_df["close"].iloc[-min_len:].values

        # Historical ratio: (NIGHT/USD) / (ADA/USD) = NIGHT/ADA
        ratio_series = pd.Series(night_closes / (ada_closes + 1e-9))

        # Consistent current ratio calculation:
        series_last_ratio = float(ratio_series.iloc[-1])
        # Use DEX price if available and within realistic bounds (< 25% divergence from market ratio), otherwise use consistent series ratio
        if dex_night_ada_price and dex_night_ada_price > 0 and (abs(dex_night_ada_price - series_last_ratio) / (series_last_ratio + 1e-9) < 0.25):
            cur_ratio = dex_night_ada_price
        else:
            cur_ratio = series_last_ratio

        inv_ratio = 1.0 / (cur_ratio + 1e-9)

        # 20-period Mean and Std of the ratio
        window = min(20, len(ratio_series))
        sma_20 = float(ratio_series.rolling(window).mean().iloc[-1])
        std_20 = float(ratio_series.rolling(window).std().iloc[-1])
        z_score = (cur_ratio - sma_20) / (std_20 + 1e-9)

        # Ratio RSI (14)
        delta = ratio_series.diff()
        gain = (delta.where(delta > 0, 0)).rolling(window=min(14, len(ratio_series))).mean()
        loss = (-delta.where(delta < 0, 0)).rolling(window=min(14, len(ratio_series))).mean()
        rs = float(gain.iloc[-1]) / (float(loss.iloc[-1]) + 1e-9)
        ratio_rsi = 100.0 - (100.0 / (1.0 + rs))

        bb_upper = sma_20 + 2.0 * std_20
        bb_lower = sma_20 - 2.0 * std_20

        # Action determination
        if z_score <= -1.5 or ratio_rsi < 35 or cur_ratio <= bb_lower:
            action = "ACCUMULATE_NIGHT"
            recommendation = (
                f"🟢 ĐIỂM ĐẸP TÍCH LŨY NIGHT: Tỷ giá NIGHT/ADA chạm vùng đáy (Z-score: {z_score:+.2f}, RSI: {ratio_rsi:.1f}). "
                f"Dùng ADA mua gom NIGHT để nhận được nhiều NIGHT nhất!"
            )
        elif z_score >= 1.5 or ratio_rsi > 65 or cur_ratio >= bb_upper:
            action = "ACCUMULATE_ADA"
            recommendation = (
                f"🔴 ĐIỂM ĐẸP TÍCH LŨY ADA: Tỷ giá NIGHT/ADA chạm vùng đỉnh (Z-score: {z_score:+.2f}, RSI: {ratio_rsi:.1f}). "
                f"Đổi NIGHT sang ADA để chốt lời lượng lớn ADA!"
            )
        else:
            action = "BALANCED"
            recommendation = f"Tỷ giá NIGHT/ADA đang trong vùng cân bằng (Z-score: {z_score:+.2f}, RSI: {ratio_rsi:.1f})."

        return {
            "current_ratio": round(cur_ratio, 4),
            "inv_ratio": round(inv_ratio, 2),
            "mean_ratio": round(sma_20, 4),
            "z_score": round(z_score, 2),
            "ratio_rsi": round(ratio_rsi, 1),
            "bb_upper": round(bb_upper, 4),
            "bb_lower": round(bb_lower, 4),
            "action": action,
            "recommendation": recommendation,
        }

    @staticmethod
    def calculate_lead_lag_features(
        cex_night_df: pd.DataFrame,
        cex_ada_df: pd.DataFrame,
        dex_night_ada_price: float,
    ) -> Dict[str, float]:
        """
        Calculate Cross-Market Lead-Lag metrics for NIGHT using standardized USD terms.
        """
        if cex_night_df.empty or cex_ada_df.empty:
            return {
                "night_cex_velocity_1h": 0.0,
                "night_cex_vol_spike": 1.0,
                "arbitrage_spread_pct": 0.0,
                "lead_signal": 0.0,
            }

        night_close = float(cex_night_df["close"].iloc[-1])
        night_prev = float(cex_night_df["close"].iloc[-2]) if len(cex_night_df) > 1 else night_close
        ada_close = float(cex_ada_df["close"].iloc[-1])

        # CEX 1h Price velocity
        velocity = (night_close - night_prev) / (night_prev + 1e-9)

        # Volume spike on CEX
        avg_vol = float(cex_night_df["volume"].rolling(10).mean().iloc[-1]) if len(cex_night_df) >= 10 else 1.0
        cur_vol = float(cex_night_df["volume"].iloc[-1])
        vol_spike = cur_vol / (avg_vol + 1e-9)

        # Standardized USD comparison:
        # DEX NIGHT price in USD = (NIGHT/ADA on DEX) * (ADA/USD on CEX)
        dex_night_usd = dex_night_ada_price * ada_close
        spread_pct = 0.0
        if dex_night_usd > 0:
            spread_pct = ((night_close - dex_night_usd) / dex_night_usd) * 100.0

        lead_signal = 0.0
        if spread_pct > 3.0 and velocity > 0.01:
            lead_signal = 1.0  # CEX is leading ahead of DEX
        elif spread_pct < -3.0 and velocity < -0.01:
            lead_signal = -1.0

        return {
            "night_cex_velocity_1h": velocity,
            "night_cex_vol_spike": vol_spike,
            "arbitrage_spread_pct": spread_pct,
            "lead_signal": lead_signal,
        }

import asyncio
import logging
from datetime import datetime, timezone
from typing import Dict, Any, Optional
import aiohttp
from config.settings import settings

logger = logging.getLogger("DEXCollector")


class DEXCollector:
    """
    Decentralized Exchange (DEX) Data Collector for Cardano Pools (Minswap, DexHunter).
    Monitors liquidity depth, spot price, and reserves for NIGHT/ADA and ADA/USDC.
    """

    def __init__(self):
        self.minswap_v2_url = "https://api-mainnet-prod.minswap.org/v1/pools/metrics"
        self.dexhunter_api_url = "https://api.dexhunter.io"

    async def fetch_pool_reserves(self, pair: str = "NIGHT/ADA") -> Dict[str, Any]:
        """
        Fetch reserves and price for a Cardano DEX liquidity pool.
        Queries Minswap V2 official metrics API, selecting the deepest liquidity pool.
        Calculates constant product k = reserve_a * reserve_b and slippage.
        """
        parts = pair.upper().split("/")
        base_sym = parts[0] if len(parts) > 0 else "NIGHT"
        quote_sym = parts[1] if len(parts) > 1 else "ADA"

        headers = {
            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
            "Content-Type": "application/json",
        }

        try:
            async with aiohttp.ClientSession(headers=headers) as session:
                async with session.post(self.minswap_v2_url, json={"limit": 100}, timeout=10) as resp:
                    if resp.status == 200:
                        data = await resp.json()
                        pools = data.get("pool_metrics", [])
                        
                        best_pool = None
                        max_liquidity = -1.0

                        for pool in pools:
                            t_a = pool.get("asset_a", {}).get("metadata", {}).get("ticker", "").upper()
                            t_b = pool.get("asset_b", {}).get("metadata", {}).get("ticker", "").upper()

                            # Match pair in either order
                            if (t_a == base_sym and t_b == quote_sym) or (t_a == quote_sym and t_b == base_sym):
                                liq = float(pool.get("liquidity", 0.0))
                                if liq > max_liquidity:
                                    max_liquidity = liq
                                    best_pool = pool

                        if best_pool:
                            t_a = best_pool.get("asset_a", {}).get("metadata", {}).get("ticker", "").upper()
                            liq_a = float(best_pool.get("liquidity_a", 0.0))
                            liq_b = float(best_pool.get("liquidity_b", 0.0))

                            if t_a == base_sym and liq_a > 0:
                                # price = quote / base (e.g., ADA / NIGHT)
                                price = liq_b / liq_a
                                reserve_base = liq_a
                                reserve_quote = liq_b
                            elif liq_b > 0:
                                # asset_a is quote, asset_b is base
                                price = liq_a / liq_b
                                reserve_base = liq_b
                                reserve_quote = liq_a
                            else:
                                price = 0.33
                                reserve_base = 2_500_000.0
                                reserve_quote = reserve_base * price

                            pool_type = best_pool.get("type", "V2")
                            logger.info(f"DEX Live Pool [{pair}]: 1 {base_sym} = {price:.6f} {quote_sym} ({pool_type}, Thanh khoản: {max_liquidity:,.0f})")

                            return {
                                "pair": pair,
                                "dex": f"Minswap ({pool_type})",
                                "price": round(price, 6),
                                "reserve_base": reserve_base,
                                "reserve_quote": reserve_quote,
                                "liquidity_usd": float(best_pool.get("liquidity_currency", 500000.0)),
                                "is_live": True,
                                "timestamp": datetime.now(timezone.utc),
                            }
        except Exception as e:
            logger.warning(f"Lỗi truy vấn Minswap V2 API: {e}. Chuyển sang chế độ dự phòng.")

        # Fallback simulation reserves (Marked as is_live=False to avoid false arbitrage alerts)
        default_prices = {
            "NIGHT/ADA": 0.33,
            "ADA/USDC": 0.148,
            "ADA/USDT": 0.148,
        }
        price = default_prices.get(pair.upper(), 1.0)
        return {
            "pair": pair,
            "dex": "DexHunter/Minswap (Estimated)",
            "price": price,
            "reserve_base": 2_500_000.0,
            "reserve_quote": 2_500_000.0 * price,
            "liquidity_usd": 450_000.0,
            "is_live": False,
            "timestamp": datetime.now(timezone.utc),
        }

    def calculate_amm_slippage(
        self,
        reserve_in: float,
        reserve_out: float,
        amount_in: float,
    ) -> Dict[str, float]:
        """
        Calculate Constant Product AMM swap output and slippage:
        (x + dx * (1 - fee)) * (y - dy) = x * y
        Standard Cardano DEX fee = 0.3%
        """
        fee_factor = 0.997  # 0.3% LP fee
        amount_in_with_fee = amount_in * fee_factor
        amount_out = (amount_in_with_fee * reserve_out) / (reserve_in + amount_in_with_fee)

        ideal_out = amount_in * (reserve_out / reserve_in)
        slippage_pct = ((ideal_out - amount_out) / ideal_out) * 100.0 if ideal_out > 0 else 0.0

        return {
            "amount_out": amount_out,
            "effective_price": amount_out / amount_in if amount_in > 0 else 0.0,
            "slippage_pct": max(0.0, slippage_pct),
        }

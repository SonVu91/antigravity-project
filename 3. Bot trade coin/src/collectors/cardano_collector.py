import asyncio
import logging
from datetime import datetime, timezone
from typing import List, Dict, Any, Optional
import aiohttp
from config.settings import settings
from src.database.db_session import get_session
from src.database.models import WhaleTransaction

logger = logging.getLogger("CardanoCollector")


class CardanoCollector:
    """
    Cardano On-chain Data Collector with Adapter Pattern.
    Monitors Whale Wallets for ADA and NIGHT native asset transfers.
    Works seamlessly with Blockfrost API, Koios Public API, or local mock fallback.
    """

    def __init__(self):
        self.project_id = settings.BLOCKFROST_PROJECT_ID
        self.network = settings.BLOCKFROST_NETWORK.lower()
        self.base_url = (
            f"https://cardano-{self.network}.blockfrost.io/api/v0"
            if self.network in ["mainnet", "preprod", "preview"]
            else "https://cardano-mainnet.blockfrost.io/api/v0"
        )
        self.koios_base_url = "https://api.koios.rest/api/v1"
        self.night_policy_id = settings.NIGHT_POLICY_ID

    async def get_latest_block(self) -> Dict[str, Any]:
        """Fetch latest Cardano block info"""
        if self.project_id:
            headers = {"project_id": self.project_id}
            try:
                async with aiohttp.ClientSession() as session:
                    async with session.get(f"{self.base_url}/blocks/latest", headers=headers, timeout=10) as resp:
                        if resp.status == 200:
                            data = await resp.json()
                            return {
                                "block_no": data.get("height"),
                                "epoch": data.get("epoch"),
                                "slot": data.get("slot"),
                                "time": datetime.fromtimestamp(data.get("time", 0), tz=timezone.utc),
                                "tx_count": data.get("tx_count", 0),
                            }
            except Exception as e:
                logger.warning(f"Blockfrost get_latest_block failed: {e}. Falling back to Koios.")

        # Fallback to Koios
        try:
            async with aiohttp.ClientSession() as session:
                async with session.get(f"{self.koios_base_url}/tip", timeout=10) as resp:
                    if resp.status == 200:
                        data = await resp.json()
                        tip = data[0] if data else {}
                        return {
                            "block_no": tip.get("block_no"),
                            "epoch": tip.get("epoch_no"),
                            "slot": tip.get("abs_slot"),
                            "time": datetime.now(timezone.utc),
                            "tx_count": 0,
                        }
        except Exception as e:
            logger.debug(f"Koios get_latest_block error: {e}")

        # Mock fallback for test/offline
        return {
            "block_no": 11000000,
            "epoch": 520,
            "slot": 135000000,
            "time": datetime.now(timezone.utc),
            "tx_count": 42,
        }

    async def scan_whale_transactions(self, min_ada_amount: float = 500000.0) -> List[Dict[str, Any]]:
        """
        Scan for recent whale transactions (> 500,000 ADA) or large NIGHT transfers.
        """
        detected: List[Dict[str, Any]] = []

        if self.project_id:
            headers = {"project_id": self.project_id}
            try:
                async with aiohttp.ClientSession() as session:
                    # Fetch recent transactions
                    async with session.get(f"{self.base_url}/txs/latest?count=20", headers=headers, timeout=10) as resp:
                        if resp.status == 200:
                            txs = await resp.json()
                            for tx_info in txs:
                                tx_hash = tx_info.get("hash")
                                # Read UTxO details
                                async with session.get(f"{self.base_url}/txs/{tx_hash}/utxos", headers=headers, timeout=5) as u_resp:
                                    if u_resp.status == 200:
                                        u_data = await u_resp.json()
                                        outputs = u_data.get("outputs", [])
                                        for out in outputs:
                                            for amt in out.get("amount", []):
                                                if amt.get("unit") == "lovelace":
                                                    ada_val = float(amt.get("quantity", 0)) / 1_000_000.0
                                                    if ada_val >= min_ada_amount:
                                                        detected.append({
                                                            "asset": "ADA",
                                                            "tx_hash": tx_hash,
                                                            "from_address": "Whale / CEX Vault",
                                                            "to_address": out.get("address"),
                                                            "amount": ada_val,
                                                            "note": f"Phát hiện giao dịch chuyển {ada_val:,.0f} ADA trên mạng lưới",
                                                            "timestamp": datetime.now(timezone.utc),
                                                        })
                                                elif self.night_policy_id and amt.get("unit", "").startswith(self.night_policy_id):
                                                    night_val = float(amt.get("quantity", 0))
                                                    detected.append({
                                                        "asset": "NIGHT",
                                                        "tx_hash": tx_hash,
                                                        "from_address": "Whale Vault",
                                                        "to_address": out.get("address"),
                                                        "amount": night_val,
                                                        "note": f"Dịch chuyển ví lớn token NIGHT: {night_val:,.0f} NIGHT",
                                                        "timestamp": datetime.now(timezone.utc),
                                                    })
            except Exception as e:
                logger.warning(f"Error scanning Blockfrost whale txs: {e}")

        # Save to DB if detected
        if detected:
            async with get_session() as session:
                for d in detected:
                    tx_obj = WhaleTransaction(
                        asset=d["asset"],
                        tx_hash=d["tx_hash"],
                        from_address=d.get("from_address"),
                        to_address=d.get("to_address"),
                        amount=d["amount"],
                        timestamp=d["timestamp"],
                        note=d.get("note"),
                    )
                    session.add(tx_obj)

        return detected

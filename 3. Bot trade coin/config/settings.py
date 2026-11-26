from pathlib import Path
from typing import Optional
from pydantic_settings import BaseSettings, SettingsConfigDict


BASE_DIR = Path(__file__).resolve().parent.parent


class Settings(BaseSettings):
    # Operating Mode
    BOT_MODE: str = "paper_trading"  # alert_only, paper_trading, live_trading
    LOG_LEVEL: str = "INFO"

    # Target Assets
    CEX_ADA_PAIR: str = "ADA/USDT"
    CEX_NIGHT_PAIR: str = "NIGHT/USDT"
    DEFAULT_CEX_EXCHANGE: str = "binance"
    FALLBACK_CEX_EXCHANGES: list[str] = ["mexc", "okx", "gateio"]

    DEX_ADA_PAIR: str = "ADA/USDC"
    DEX_NIGHT_PAIR: str = "NIGHT/ADA"
    NIGHT_POLICY_ID: str = ""
    NIGHT_ASSET_NAME_HEX: str = ""

    # Paper Trading Balances
    PAPER_INITIAL_USDT: float = 10000.0
    PAPER_INITIAL_ADA: float = 10000.0
    PAPER_INITIAL_NIGHT: float = 0.0

    # Risk Management
    MAX_RISK_PER_TRADE_PCT: float = 1.5
    CIRCUIT_BREAKER_DRAWDOWN_PCT: float = 5.0
    ATR_SL_MULTIPLIER: float = 1.5
    TAKE_PROFIT_RR_RATIO: float = 2.0

    # Fees & Delays for Paper Simulation
    CEX_TAKER_FEE_PCT: float = 0.00075  # 0.075%
    CARDANO_NETWORK_FEE_ADA: float = 0.20  # 0.20 ADA
    CARDANO_DEX_BATCHER_FEE_ADA: float = 2.0  # 2.0 ADA
    CARDANO_DEX_DELAY_SECONDS: float = 20.0  # ~1 block delay

    # APIs & Keys
    BLOCKFROST_PROJECT_ID: str = ""
    BLOCKFROST_NETWORK: str = "mainnet"

    GEMINI_API_KEY: str = ""
    GEMINI_MODEL: str = "gemini-2.0-flash"

    TELEGRAM_BOT_TOKEN: str = ""
    TELEGRAM_CHAT_ID: str = ""

    # CEX Keys (Optional)
    BINANCE_API_KEY: str = ""
    BINANCE_API_SECRET: str = ""
    MEXC_API_KEY: str = ""
    MEXC_API_SECRET: str = ""
    OKX_API_KEY: str = ""
    OKX_API_SECRET: str = ""
    OKX_PASSPHRASE: str = ""

    # Database
    DATABASE_URL: str = "sqlite+aiosqlite:///./data/sentinel.db"

    model_config = SettingsConfigDict(
        env_file=(str(BASE_DIR / "config" / ".env"), str(BASE_DIR / ".env")),
        env_file_encoding="utf-8",
        extra="ignore",
    )


settings = Settings()

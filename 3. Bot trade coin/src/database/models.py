from datetime import datetime, timezone
from sqlalchemy import Column, Integer, String, Float, DateTime, Boolean, Text
from sqlalchemy.orm import declarative_base

Base = declarative_base()


class Candle(Base):
    __tablename__ = "candles"

    id = Column(Integer, primary_key=True, autoincrement=True)
    exchange = Column(String(50), nullable=False, index=True)
    symbol = Column(String(50), nullable=False, index=True)
    timeframe = Column(String(10), nullable=False, index=True)
    timestamp = Column(DateTime, nullable=False, index=True)
    open = Column(Float, nullable=False)
    high = Column(Float, nullable=False)
    low = Column(Float, nullable=False)
    close = Column(Float, nullable=False)
    volume = Column(Float, nullable=False)


class WhaleTransaction(Base):
    __tablename__ = "whale_transactions"

    id = Column(Integer, primary_key=True, autoincrement=True)
    asset = Column(String(50), nullable=False, index=True)  # ADA, NIGHT
    tx_hash = Column(String(128), unique=True, index=True)
    from_address = Column(String(150), nullable=True)
    to_address = Column(String(150), nullable=True)
    amount = Column(Float, nullable=False)
    usd_value = Column(Float, nullable=True)
    timestamp = Column(DateTime, default=lambda: datetime.now(timezone.utc), index=True)
    note = Column(Text, nullable=True)


class AISignal(Base):
    __tablename__ = "ai_signals"

    id = Column(Integer, primary_key=True, autoincrement=True)
    signal_id = Column(String(100), unique=True, index=True)
    asset = Column(String(50), nullable=False, index=True)
    market_type = Column(String(20), nullable=False)  # CEX or DEX
    action = Column(String(10), nullable=False)  # BUY, SELL, HOLD
    confidence = Column(Float, nullable=False)
    timeframe = Column(String(10), default="1h")
    reasoning = Column(Text, nullable=True)
    technical_score = Column(Float, default=0.0)
    sentiment_score = Column(Float, default=0.0)
    lead_lag_score = Column(Float, default=0.0)
    suggested_entry = Column(Float, nullable=False)
    suggested_sl = Column(Float, nullable=False)
    suggested_tp = Column(Float, nullable=False)
    position_size_pct = Column(Float, default=1.5)
    timestamp = Column(DateTime, default=lambda: datetime.now(timezone.utc), index=True)


class PaperTrade(Base):
    __tablename__ = "paper_trades"

    id = Column(Integer, primary_key=True, autoincrement=True)
    trade_id = Column(String(100), unique=True, index=True)
    market_type = Column(String(20), nullable=False)  # CEX or DEX
    asset = Column(String(50), nullable=False, index=True)
    side = Column(String(10), nullable=False)  # BUY or SELL
    entry_price = Column(Float, nullable=False)
    exit_price = Column(Float, nullable=True)
    quantity = Column(Float, nullable=False)
    cost_basis = Column(Float, nullable=False)
    stop_loss = Column(Float, nullable=False)
    take_profit = Column(Float, nullable=False)
    fee_paid = Column(Float, default=0.0)  # CEX fee or DEX batcher/tx fee
    slippage = Column(Float, default=0.0)
    pnl = Column(Float, default=0.0)
    pnl_pct = Column(Float, default=0.0)
    status = Column(String(20), default="OPEN", index=True)  # OPEN, CLOSED, CANCELLED
    entry_time = Column(DateTime, default=lambda: datetime.now(timezone.utc), index=True)
    exit_time = Column(DateTime, nullable=True)
    close_reason = Column(String(50), nullable=True)  # TP, SL, MANUAL, EXPIRED


class PortfolioBalance(Base):
    __tablename__ = "portfolio_balances"

    id = Column(Integer, primary_key=True, autoincrement=True)
    account_type = Column(String(20), nullable=False, index=True)  # CEX or DEX
    currency = Column(String(20), nullable=False, index=True)  # USDT, ADA, NIGHT
    total_balance = Column(Float, nullable=False)
    available_balance = Column(Float, nullable=False)
    locked_balance = Column(Float, default=0.0)
    updated_at = Column(DateTime, default=lambda: datetime.now(timezone.utc))

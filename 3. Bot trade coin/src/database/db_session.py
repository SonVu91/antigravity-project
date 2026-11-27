import os
from pathlib import Path
from typing import AsyncGenerator
from contextlib import asynccontextmanager
from sqlalchemy.ext.asyncio import create_async_engine, async_sessionmaker, AsyncSession
from config.settings import settings
from src.database.models import Base

_current_db_url = None
_engine = None


def get_db_url() -> str:
    return os.environ.get("DATABASE_URL", settings.DATABASE_URL)


def get_engine():
    global _engine, _current_db_url
    url = get_db_url()
    if _engine is None or _current_db_url != url:
        _current_db_url = url
        clean_path = url.replace("sqlite+aiosqlite:///", "")
        if clean_path and not clean_path.startswith(":"):
            d_dir = Path(clean_path).parent
            os.makedirs(d_dir, exist_ok=True)
        _engine = create_async_engine(url, echo=False, future=True)
    return _engine


def get_session_factory():
    eng = get_engine()
    return async_sessionmaker(bind=eng, class_=AsyncSession, expire_on_commit=False)


# Backward-compatible global references
engine = get_engine()
async_session_factory = get_session_factory()


async def init_db() -> None:
    """Initialize database tables"""
    eng = get_engine()
    async with eng.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)


@asynccontextmanager
async def get_session() -> AsyncGenerator[AsyncSession, None]:
    """Provide an async transaction session"""
    factory = get_session_factory()
    async with factory() as session:
        try:
            yield session
            await session.commit()
        except Exception:
            await session.rollback()
            raise

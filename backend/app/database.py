from collections.abc import AsyncGenerator

from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine
from sqlalchemy.orm import DeclarativeBase
from sqlalchemy.pool import StaticPool

from app.config import settings

_url = settings.async_database_url
_sqlite = "aiosqlite" in _url
_engine_kwargs: dict = {}
_connect_args: dict = {}
if _sqlite and ":memory:" in _url:
    _engine_kwargs["poolclass"] = StaticPool
if _sqlite:
    _connect_args["check_same_thread"] = False

engine = create_async_engine(
    _url,
    connect_args=_connect_args,
    **_engine_kwargs,
)

AsyncSessionLocal = async_sessionmaker(
    engine,
    class_=AsyncSession,
    autoflush=False,
    expire_on_commit=False,
)


class Base(DeclarativeBase):
    pass


async def get_db() -> AsyncGenerator[AsyncSession, None]:
    async with AsyncSessionLocal() as session:
        yield session

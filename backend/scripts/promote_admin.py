"""Назначить пользователю роль admin (после первого запуска API).

Запуск:
  py -3 scripts/promote_admin.py user@example.com
"""

import asyncio
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from sqlalchemy import text  # noqa: E402
from sqlalchemy.ext.asyncio import create_async_engine  # noqa: E402

from app.config import settings  # noqa: E402


async def main() -> None:
    if len(sys.argv) != 2:
        print("Использование: promote_admin.py <email>")
        sys.exit(1)
    email = sys.argv[1]
    kw: dict = {}
    if "aiosqlite" in settings.async_database_url:
        kw["connect_args"] = {"check_same_thread": False}
    engine = create_async_engine(settings.async_database_url, **kw)
    async with engine.begin() as conn:
        r = await conn.execute(text("UPDATE users SET role = 'admin' WHERE email = :e"), {"e": email})
        if r.rowcount == 0:
            print("Пользователь не найден.")
            sys.exit(2)
    await engine.dispose()
    print("Готово: роль admin назначена.")


if __name__ == "__main__":
    asyncio.run(main())

from pydantic import computed_field
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    app_name: str = "API задач (учебный проект)"
    secret_key: str = "change-me-in-production-use-openssl-rand-hex-32"
    algorithm: str = "HS256"
    access_token_expire_minutes: int = 60 * 24
    # SQLite: sqlite:///./todo.db | PostgreSQL: postgresql://user:pass@localhost:5432/todo
    database_url: str = "sqlite:///./todo.db"
    # При False используйте только Alembic (alembic upgrade head) для создания таблиц
    auto_create_tables: bool = True
    # Токен Logfire (https://logfire.pydantic.dev); без токена — только стандартные логи
    logfire_token: str | None = None

    @computed_field  # type: ignore[prop-decorator]
    @property
    def async_database_url(self) -> str:
        u = self.database_url.strip()
        if u.startswith("sqlite+aiosqlite:"):
            return u
        if u.startswith("sqlite:///"):
            return "sqlite+aiosqlite:///" + u.removeprefix("sqlite:///")
        if u.startswith("postgresql+asyncpg:"):
            return u
        if u.startswith("postgresql://"):
            return "postgresql+asyncpg://" + u.removeprefix("postgresql://")
        return u


settings = Settings()

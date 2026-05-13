import logging
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from prometheus_client import CONTENT_TYPE_LATEST, REGISTRY, generate_latest
from starlette.responses import Response

from app.config import settings
from app.database import Base, engine
from app.logging_config import setup_logging
from app.routers import admin, auth, tasks

setup_logging()
logger = logging.getLogger(__name__)


@asynccontextmanager
async def lifespan(app: FastAPI):
    if settings.auto_create_tables:
        async with engine.begin() as conn:
            await conn.run_sync(Base.metadata.create_all)
        logger.info("db_tables_ready", extra={"mode": "auto_create"})
    if settings.logfire_token:
        try:
            import logfire

            logfire.configure(
                token=settings.logfire_token,
                service_name=settings.app_name,
            )
            logfire.instrument_fastapi(app)
            logger.info("logfire_enabled")
        except Exception as e:
            logger.warning("logfire_failed", extra={"error": str(e)})
    yield


app = FastAPI(
    title=settings.app_name,
    description=(
        "REST API: регистрация и вход, JWT, управление задачами, "
        "пример разграничения прав (эндпоинты администратора)."
    ),
    version="0.1.0",
    lifespan=lifespan,
    openapi_tags=[
        {"name": "Аутентификация", "description": "Регистрация и получение токена доступа"},
        {"name": "Задачи", "description": "Создание и изменение своих задач"},
        {"name": "Администрирование", "description": "Доступ только у пользователей с ролью admin"},
    ],
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth.router)
app.include_router(tasks.router)
app.include_router(admin.router)


@app.get("/health", summary="Проверка работоспособности")
def health() -> dict[str, str]:
    return {"status": "ok"}


@app.get("/metrics", include_in_schema=False)
def metrics() -> Response:
    """Метрики в формате Prometheus (текстовый exposition)."""
    data = generate_latest(REGISTRY)
    return Response(content=data, media_type=CONTENT_TYPE_LATEST)

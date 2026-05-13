# Бэкенд: FastAPI и SQLAlchemy 2 (async)

## Возможности

- **API:** регистрация, вход (OAuth2 form + JWT), CRUD задач (заголовок, описание, выполнено, даты).
- **Безопасность:** bcrypt, доступ к задачам только владельцу, пример RBAC (`GET /admin/tasks` для роли `admin`).
- **Асинхронность:** `AsyncSession`, драйверы **asyncpg** (PostgreSQL) и **aiosqlite** (SQLite).
- **Миграции:** [Alembic](https://alembic.sqlalchemy.org/) (`alembic/`), ревизия `9d43be7b49ff_initial`.
- **Наблюдаемость:** `GET /health`, `GET /metrics` (Prometheus), опционально **Logfire** (`LOGFIRE_TOKEN` в `.env`).
- **Тесты:** `pytest` + `TestClient` (интеграционные сценарии).

## Установка

```text
cd backend
py -3 -m venv .venv
.venv\Scripts\activate
pip install -r requirements.txt
copy .env.example .env
```

Отредактируйте `.env`: `SECRET_KEY`, при необходимости `DATABASE_URL`, `LOGFIRE_TOKEN`, `AUTO_CREATE_TABLES`.

### SQLite (по умолчанию)

Файл `todo.db` в каталоге `backend/`. Таблицы создаются при старте, если `AUTO_CREATE_TABLES=true`.

### PostgreSQL + asyncpg

В корне репозитория:

```text
docker compose up -d
```

В `backend/.env`:

```text
DATABASE_URL=postgresql://todo:todo@localhost:5432/todo
AUTO_CREATE_TABLES=false
```

Применить схему:

```text
cd backend
py -3 -m alembic upgrade head
```

## Запуск

```text
py -3 -m uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

- OpenAPI: http://127.0.0.1:8000/docs  
- Метрики: http://127.0.0.1:8000/metrics  

### Список задач: фильтр и сортировка

`GET /tasks?is_done=true|false&sort=created_at|status&order=asc|desc`

## Тесты и линтер

```text
py -3 -m ruff check app tests
py -3 -m pytest tests -q
```

## Роль admin (RBAC)

После регистрации пользователя:

```text
py -3 scripts/promote_admin.py email@example.com
```

Эндпоинт `GET /admin/tasks` доступен только с ролью `admin`.

## Новая миграция (после изменения моделей)

```text
py -3 -m alembic revision --autogenerate -m "описание"
py -3 -m alembic upgrade head
```

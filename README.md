## TODO List (fullstack)

**Задание:** backend на **Python (FastAPI)**, **веб-приложение** и **мобильное приложение** — простой список задач с регистрацией, JWT и CRUD. Теория по FastAPI — курс [Stepik: «FastAPI, Docker и CI/CD»](https://stepik.org/course/179694/promo). Ориентир по идее API — пример [hazadus/fastapi-todos](https://github.com/hazadus/fastapi-todos).

| Часть | Реализация |
|--------|------------|
| Backend | `backend/` — FastAPI, **async** SQLAlchemy 2 (asyncpg / aiosqlite), JWT, CRUD, Alembic, `/metrics`, опционально Logfire |
| Веб | `web_client/` — регистрация/вход, **localStorage**, фильтр и сортировка, inline-редактирование, анимации, Font Awesome, адаптивная вёрстка |
| Мобильное | `mobile/todo_app/` — Flutter (Android / iOS / web / Windows) |

Подробный текст для сдачи: [docs/POYASNITELNAYA_ZAPISKA.md](docs/POYASNITELNAYA_ZAPISKA.md).

---

## Быстрый старт

### 1. Backend

См. [backend/README.md](backend/README.md). Кратко:

```text
cd backend
py -3 -m pip install -r requirements.txt
copy .env.example .env
py -3 -m uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

### 2. Веб-клиент (браузер)

Откройте `web_client/index.html` в браузере **или** поднимите локальный сервер (так надёжнее для запросов к API):

```text
cd web_client
py -3 -m http.server 8080
```

В браузере: `http://127.0.0.1:8080` — в поле «Адрес API» должен быть `http://127.0.0.1:8000` (если backend запущен как выше).

### 3. Мобильный клиент (Flutter)

Установите [Flutter SDK](https://flutter.dev/). **Удобнее всего открыть проект через файл [kurs_todo_fullstack.code-workspace](kurs_todo_fullstack.code-workspace)** (два корня в боковой панели: весь курс и отдельно `flutter_app` = тот же `mobile/todo_app`). Тогда терминал по умолчанию создаётся в `mobile/todo_app`, и правки в дереве **flutter_app** совпадают с каталогом, откуда идёт `flutter run` — не остаётся «второй копии» на диске.

Запуск из командной строки — только из этой папки:

```text
cd mobile/todo_app
flutter pub get
flutter run -d chrome
```

В Windows можно запускать из `mobile/todo_app`: **`run_chrome.bat`**; если в Chrome отображается старая версия интерфейса — **`run_chrome_fresh.bat`** или см. [mobile/todo_app/README.md](mobile/todo_app/README.md). В Cursor/VS Code: **Flutter: todo_app (Chrome) — workspace file** при открытом `.code-workspace`; иначе **…opened repo as folder** или **…only mobile/todo_app** — см. подсказки в Run and Debug.

Для Android-эмулятора API по умолчанию указывает на `http://10.0.2.2:8000`. На реальном устройстве задайте IP вашего ПК в `lib/main.dart` (`defaultBaseUrl`).

### 4. Первый вход

На экране входа нажмите «Войти / зарегистрироваться»: сначала выполняется регистрация; если email уже занят — вход с тем же паролем.

## Структура репозитория

- `backend/` — REST API, JWT, операции с задачами, пример разграничения прав (`/admin/tasks`).
- `web_client/` — веб-приложение (HTML/CSS/JS): фильтры, сортировки, inline-edit, ошибки API.
- `docker-compose.yml` — опциональный PostgreSQL для asyncpg.е.

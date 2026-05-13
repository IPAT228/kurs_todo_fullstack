# Пояснительная записка

> **Оформление для сдачи в Word:** выполните `py -3 docs/generate_poyasnitelnaya_zapiska.py` из корня репозитория (или из каталога `docs/`). В полученном `docs/POYASNITELNAYA_ZAPISKA.docx` заданы: поля страницы (левое 30 мм, правое 15 мм, верх/низ 20 мм), шрифт **Times New Roman**, основной текст **14 pt**, межстрочный полуторный интервал, **красная строка** 12,5 мм у обычных абзацев; заголовки разделов 1–13 и подразделы 5.1–5.4 — **чёрный** цвет (не синий стиль Word); заголовки разделов — **16 pt**, подразделы 5.x — **14 pt**.

**Тема:** веб- и мобильное приложение «Список задач (TODO)» с общим backend на FastAPI.

---

## 1. Описание предметной области

Предметная область — **персональный список задач**: пользователь создаёт записи (заголовок, необязательное описание), отмечает выполнение, редактирует и удаляет задачи. Данные одного пользователя недоступны другому (изоляция по владельцу). Для администратора предусмотрен расширенный просмотр (все задачи) в рамках учебной демонстрации **RBAC**.

---

## 2. Цели и задачи

**Цель:** реализовать учебный fullstack-контур: HTTP API на Python (FastAPI) и клиент на Flutter (веб + мобильные платформы), с корректной моделью данных и авторизацией.

**Задачи:**

- Спроектировать модель пользователя и задачи в реляционной БД.
- Реализовать **CRUD** для задач с проверкой прав доступа.
- Обеспечить регистрацию и вход, выдачу **JWT**.
- Реализовать клиент на Flutter с хранением токена и вызовами REST.
- Задокументировать стек, линтер, СУБД, подход к логированию и тестированию.

---

## 3. Функциональные требования

| Действие | Описание |
|----------|----------|
| Регистрация | Создание пользователя по email и паролю. |
| Вход | Получение JWT (OAuth2 password flow, поле `username` = email). |
| Профиль | `GET /auth/me` — id, email, роль из БД; клиенты переключают `/tasks` и `/admin/tasks`. |
| Список задач | `GET /tasks` — только задачи текущего пользователя; query `is_done`, `sort`, `order`. |
| Создание | `POST /tasks` — задача с `owner_id` текущего пользователя. |
| Чтение одной | `GET /tasks/{id}` — только если владелец совпадает. |
| Обновление | `PATCH /tasks/{id}` — частичное обновление (`TaskUpdate`). |
| Удаление | `DELETE /tasks/{id}` — только владелец; ответ **204** без тела. |
| Админ: список | `GET /admin/tasks` — все задачи; те же query; в ответе `owner_email`. |
| Админ: одна | `GET /admin/tasks/{id}` — любая задача. |
| Админ: создание | `POST /admin/tasks` — поля задачи + `owner_id`. |
| Админ: обновление | `PATCH /admin/tasks/{id}` — любая задача. |
| Админ: удаление | `DELETE /admin/tasks/{id}` — только при роли `admin`. |

---

## 4. Описание стека технологий

| Уровень | Технологии |
|---------|------------|
| Backend | Python 3.11+, FastAPI, Uvicorn, Pydantic v2, SQLAlchemy 2.x **async** (asyncpg / aiosqlite) |
| БД | SQLite (разработка), PostgreSQL + asyncpg (см. `docker-compose.yml`), миграции **Alembic** |
| Наблюдаемость | `GET /health`, `GET /metrics` (Prometheus), опционально **Logfire** |
| Auth | JWT (библиотека `python-jose`), хэш пароля — `bcrypt` |
| Веб-клиент | HTML5, JavaScript (fetch), страница `web_client/index.html` |
| Мобильный клиент | Flutter 3.x, `http`, `flutter_secure_storage` |
| Линтер Python | Ruff (`pyproject.toml`) |
| Линтер Dart | `flutter_lints` (`analysis_options.yaml`) |
| Тесты backend | `pytest`, `httpx` / `TestClient` |

Теория по курсу: FastAPI и Python — по материалам Stepik, в т.ч. курс [«FastAPI, Docker и CI/CD» (промо)](https://stepik.org/course/179694/promo); веб-клиент не требует отдельного фреймворка; мобильный клиент — Flutter: [flutter.dev](https://flutter.dev/), [справочник Яндекса](https://education.yandex.ru/handbook/flutter). Дополнительно по fullstack на Kotlin в задании указаны вводные по синтаксису Kotlin — в данном проекте мобильная часть на Flutter; веб — на статической странице с вызовами REST.

---

## 5. CRUD: пользователь, БД, backend и абстракция операций

### С точки зрения абстракции CRUD

**CRUD** (Create, Read, Update, Delete) — канонический жизненный цикл над **одной сущностью** (здесь — «задача»):

- **Create** — добавление новой строки в множество задач. В REST: `POST`. Не идемпотентен: повторные запросы создают разные записи. Сервер назначает `id`, `created_at`, `updated_at`. Владелец: при `POST /tasks` берётся из JWT; при `POST /admin/tasks` задаётся полем `owner_id`.
- **Read** — извлечение без изменения состояния хранилища. Коллекция: `GET /tasks` или `GET /admin/tasks` с фильтром `is_done` и сортировкой `sort` / `order`. Элемент: `GET .../{id}`. Ответ **200** и JSON `TaskRead`. Нет записи или нет права — **404** (для пользователя чужая задача неотличима от отсутствующей).
- **Update** — изменение атрибутов существующей строки. В REST: **`PATCH`** с частичным телом (`TaskUpdate` — только изменяемые поля). Ответ — полное текущее состояние задачи.
- **Delete** — удаление строки. **`DELETE`**; успех — **204 No Content** без тела. Повторный запрос по тому же `id` после удаления снова даёт **404**.

Для одной таблицы `tasks` в проекте две **поверхности REST**: префикс `/tasks/*` (изоляция по `owner_id` текущего пользователя) и `/admin/tasks/*` (те же операции CRUD по всем задачам при роли `admin`, в ответах дополнительно `owner_email` владельца). Это разграничение **авторизации**, а не разных моделей данных.

### С точки зрения клиента (HTTP, контракт API, веб и Flutter)

**Общие правила.** Клиент задаёт базовый URL API (в веб-клиенте — поле «Адрес API», в Flutter — `defaultBaseUrl` / сохранённый URL). После входа все защищённые запросы идут с заголовком `Authorization: Bearer <access_token>` и при необходимости `Content-Type: application/json`.

**Аутентификация и профиль (до CRUD по задачам).**

- `POST /auth/register` — тело JSON `{"email","password"}`; успех **201**, занятый email — **400**.
- `POST /auth/login` — тело `application/x-www-form-urlencoded`, поля `username` (= email) и `password`; ответ **200**, JSON `{"access_token","token_type":"bearer"}`.
- `GET /auth/me` — по Bearer возвращаются `id`, `email`, `role` из БД. Веб сохраняет роль и id в `localStorage`; Flutter — в secure storage. Если `role === "admin"`, дальнейшие операции с задачами выполняются на префиксе **`/admin/tasks`** (тот же набор Create/Read/Update/Delete, но по всем пользователям); иначе — только **`/tasks`** (только свои задачи).

**Create (создание задачи).**

- Пользователь: `POST /tasks`, тело `TaskCreate`: `title` (обязательно), `description` (опционально), `is_done` (по умолчанию можно передать `false`). Ответ **201** и объект `TaskRead` с назначенным сервером `id`, `owner_id`, метками времени.
- Администратор: `POST /admin/tasks`, тело как у создания плюс **`owner_id`** — владелец новой задачи; **404**, если пользователя с таким id нет.

**Read (чтение).**

- Список: `GET /tasks` или `GET /admin/tasks` с необязательными query-параметрами `is_done` (`true` / `false`), `sort` (`created_at` | `status`), `order` (`asc` | `desc`). Ответ **200**, JSON-массив `TaskRead`. У админских ответов в элементах заполнены **`owner_email`** и **`owner_id`** чужих владельцев.
- Одна задача: `GET /tasks/{id}` (только своя) или `GET /admin/tasks/{id}` (любая при admin). **404**, если записи нет или нет права (для обычного пользователя чужая задача выглядит как «не найдена»).

**Update (изменение).**

- `PATCH /tasks/{id}` или `PATCH /admin/tasks/{id}` — тело **частичное** (`TaskUpdate`): только изменяемые поля (`title`, `description`, `is_done`). Ответ **200** и полный актуальный `TaskRead`.

**Delete (удаление).**

- `DELETE /tasks/{id}` или `DELETE /admin/tasks/{id}` — успех **204** без тела. Повторный запрос после удаления — снова **404**.

**Типичные коды, которые клиент обрабатывает в UI:** **401** — сессия недействительна (веб и Flutter сбрасывают токен и просят войти снова); **403** — попытка вызвать `/admin/...` без роли admin; **422** — ошибка валидации тела запроса (Pydantic).

**Сопоставление с экраном.**

- **Веб** (`web_client/index.html`): после входа — `fetch` на `/auth/me`, затем на список задач; фильтры и выпадающие списки меняют только query у GET; чекбокс «выполнено» и правка заголовка — `PATCH`; удаление — `DELETE`; «Добавить» — `POST`; у админа поле владельца при создании задачи задаёт `owner_id` в теле.
- **Flutter** (`lib/api.dart`, `lib/main.dart`): те же URL после `login` / `fetchMe` и при перезапуске с сохранённым токеном; `listTasks` / `createTask` / `patchTask` / `deleteTask` внутри выбирают `/tasks` или `/admin/tasks` в зависимости от сохранённой роли.

### С точки зрения пользователя (кратко по сценариям)

**Веб:** список с чекбоксами, фильтры и сортировка, поля новой задачи, inline-редактирование заголовка, кнопка удаления.

**Flutter:** те же сценарии — добавление, отметка выполнения, переименование по нажатию на заголовок, удаление, кнопка «Обновить».

### С точки зрения БД (SQLite)

Таблица `users`: идентификатор, email (уникальный), хэш пароля, роль, время создания.

Таблица `tasks`: идентификатор, заголовок, описание, флаг выполнения, внешний ключ `owner_id` → `users.id`, метки времени. Каскадное удаление задач при удалении пользователя (на уровне ORM/схемы).

Операции SQL под капотом ORM: `INSERT`, `SELECT`, `UPDATE`, `DELETE` для строк `tasks` с фильтром по `owner_id` (кроме админского сценария).

### С точки зрения backend (FastAPI)

- Маршруты в `app/routers/tasks.py`, `admin.py`, `auth.py` отображают HTTP-методы на вызовы `app/crud.py` (функции с явными именами: `create_task`, `list_tasks_for_user`, `update_task`, `delete_task`, `list_all_tasks`, `get_task_by_id` и т.д.) — это прямое отображение операций CRUD на слой персистентности.
- Валидация входных и выходных данных — схемы Pydantic в `app/schemas.py` (`TaskCreate`, `TaskCreateAdmin`, `TaskUpdate`, `TaskRead`).
- Перед операциями из JWT извлекается пользователь (`app/deps.py`); для `/tasks/*` ко всем выборкам и изменениям добавляется условие по владельцу.

Иллюстративные материалы из задания по CRUD (Spring, Hibernate, взаимодействие с пользователем) концептуально совпадают: тот же жизненный цикл ресурса, различие лишь в стеке.

---

## 6. Линтер

**Python:** [Ruff](https://docs.astral.sh/ruff/) — быстрая замена цепочки flake8/isort; правила подключены в `backend/pyproject.toml` (`E`, `F`, `I`, `UP`, `B`). Запуск: `py -3 -m ruff check app tests`.

**Dart/Flutter:** пакет `flutter_lints` и файл `mobile/todo_app/analysis_options.yaml` — единый стиль и базовые предупреждения для кода клиента.

Общее назначение линтера — раннее обнаружение ошибок и единообразие; см. [статью Яндекс Практикума о линтерах](https://practicum.yandex.ru/blog/chto-takoe-linter-v-programmirovanii/).

---

## 7. СУБД (в задании: «СУЗ» — далее трактуем как систему управления **базами данных**)

**Выбор:** SQLite для локальной разработки и сдачи работы без отдельного сервера; строка подключения задаётся переменной `DATABASE_URL` (см. `backend/.env.example`).

**Обоснование:** простота развёртывания, один файл БД, полная поддержка SQLAlchemy. Для продакшена целесообразен **PostgreSQL** (транзакции, конкурентный доступ, расширенные типы).

---

## 8. Анализ соответствия принципам SOLID (фрагментарно, по коду backend)

- **SRP:** маршруты (`routers/`) отвечают за HTTP; `crud.py` — за работу с БД; `security.py` — за хэш и JWT; `schemas.py` — за контракты данных.
- **OCP:** расширение новыми эндпоинтами не требует правок низкоуровневого слоя БД — добавляются роутеры и функции CRUD.
- **LSP:** схемы Pydantic и модели ORM согласованы через `model_validate` / `from_attributes`.
- **ISP:** зависимости эндпоинтов — узкие (`Session`, `User`), без «толстых» интерфейсов.
- **DIP:** эндпоинты зависят от абстракции `get_db` и протокола репозитория (набор функций в `crud`), а не от конкретики драйвера (скрыта в `database.py`).

Пример разбора SOLID на JS из задания ([sprintcode](https://sprintcode.pro/ru/blog/solid-principles)) полезен как общая методология; здесь она применена к слоям FastAPI-приложения.

---

## 9. Метод авторизации и контроль доступа на backend

**Выбрано:** аутентификация по **JWT** после проверки email/пароля; авторизация — **RBAC** (роли `user` и `admin`).

- **RBAC (Role-Based Access Control):** право выдано **роли**; проверка «есть ли у субъекта роль admin» для `/admin/tasks`. Теория: [RBAC vs ABAC](https://glabit.ru/blog/podhody-k-kontrolyu-dostupa-rbac-vs-abac), [обзор Keeper](https://www.keepersecurity.com/blog/ru/2024/10/28/rbac-vs-abac-which-should-you-use/), [Stepik](https://stepik.org/lesson/2045912/step/1?unit=2074376).

- **ABAC** в проекте не используется: нет политик по атрибутам контекста (время, IP, теги ресурса и т.д.). Для учебного TODO RBAC проще и прозрачнее.

Практические аналоги из задания (Casbin, RBACX для Python) — более тяжёлые решения; здесь роль закодирована в JWT и проверяется зависимостью `require_admin`, что достаточно для демонстрации идеи RBAC.

---

## 10. Логирование

Реализован **структурированный** вывод в stdout в формате **JSON** (`app/logging_config.py`): уровень, время (UTC), имя логгера, сообщение. Это упрощает сбор логов внешними системами.

Теория и обзоры: [KursHub — что такое логгер](https://kurshub.ru/journal/blog/chto-takoe-logger-v-programmirovanii-i-tehnike-polnoe-obyasnenie-prostymi-slovami/), [обзор инструментов на Хабре](https://habr.com/ru/companies/ultravds/articles/984372/), [пример на Хабре (МТС)](https://habr.com/ru/companies/ru_mts/articles/715212/).

---

## 11. Тестирование

**Backend:** модульные/интеграционные тесты с `TestClient` — проверка `GET /health`, полного цикла CRUD задач и запрета `/admin/tasks` для роли `user` (`backend/tests/`).

**Flutter:** минимальный **widget-test** `test/widget_test.dart` (приложение монтируется, виден заголовок). Для более глубокого уровня обычно добавляют `mockito`/`http.MockClient` для API. В задании приведён пример экосистемы React ([PurpleSchool — React test](https://purpleschool.ru/knowledge-base/react/dev/react-test)); для Flutter аналогичную роль играют `flutter_test` и пакеты моков HTTP.

---

## 12. Установка и запуск (кратко)

См. корневой [README.md](../README.md): backend (`uvicorn`), клиент (`flutter pub get`, `flutter run`).

---

## 13. Список источников

1. Текст задания курса «Расширенный курс по решению практических задач» (оригинальный документ).
2. FastAPI — документация и курс Stepik: https://stepik.org/course/179694/promo (и др. материалы из задания).
3. Flutter — https://flutter.dev/ , https://education.yandex.ru/handbook/flutter
4. Kotlin (теория из задания) — https://kotlinlang.org/docs/basic-syntax.html
5. CRUD / Spring / Hibernate — ссылки из п. задания (JavaRush, Хабр, Skillbox).
6. Линтер — https://practicum.yandex.ru/blog/chto-takoe-linter-v-programmirovanii/
7. SOLID — https://sprintcode.pro/ru/blog/solid-principles
8. RBAC vs ABAC — glabit.ru, keepersecurity.com, Stepik (ссылки выше).
9. Casbin / RBACX — статьи Хабра из задания (как ориентиры по промышленным библиотекам).
10. Логирование — kurshub.ru, ultravds, ru_mts на Хабре.
11. Тестирование UI — https://purpleschool.ru/knowledge-base/react/dev/react-test (методология; для проекта использован Flutter test).

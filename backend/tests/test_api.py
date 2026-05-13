import pytest
from fastapi.testclient import TestClient
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models import User, UserRole


def _register_and_token(client: TestClient, email: str = "u@example.com") -> str:
    r = client.post("/auth/register", json={"email": email, "password": "secret12"})
    assert r.status_code == 201, r.text
    r = client.post("/auth/login", data={"username": email, "password": "secret12"})
    assert r.status_code == 200, r.text
    return r.json()["access_token"]


def test_auth_me(client: TestClient) -> None:
    token = _register_and_token(client, "me@example.com")
    r = client.get("/auth/me", headers={"Authorization": f"Bearer {token}"})
    assert r.status_code == 200
    data = r.json()
    assert data["email"] == "me@example.com"
    assert data["role"] == "user"


def test_auth_me_unauthorized(client: TestClient) -> None:
    r = client.get("/auth/me")
    assert r.status_code == 401


def test_health(client: TestClient) -> None:
    r = client.get("/health")
    assert r.status_code == 200
    assert r.json()["status"] == "ok"


def test_task_crud_flow(client: TestClient) -> None:
    token = _register_and_token(client)
    headers = {"Authorization": f"Bearer {token}"}

    r = client.post(
        "/tasks",
        headers=headers,
        json={"title": "Купить молоко", "description": "2 л", "is_done": False},
    )
    assert r.status_code == 201
    task_id = r.json()["id"]

    r = client.get("/tasks", headers=headers)
    assert r.status_code == 200
    assert len(r.json()) == 1

    r = client.patch(f"/tasks/{task_id}", headers=headers, json={"is_done": True})
    assert r.status_code == 200
    assert r.json()["is_done"] is True

    r = client.delete(f"/tasks/{task_id}", headers=headers)
    assert r.status_code == 204

    r = client.get("/tasks", headers=headers)
    assert r.json() == []


def test_admin_forbidden_for_user(client: TestClient) -> None:
    token = _register_and_token(client, "user2@example.com")
    r = client.get("/admin/tasks", headers={"Authorization": f"Bearer {token}"})
    assert r.status_code == 403


@pytest.mark.asyncio
async def test_admin_manages_any_task(client: TestClient, db_session: AsyncSession) -> None:
    token_user = _register_and_token(client, "plain@example.com")
    token_admin = _register_and_token(client, "boss@example.com")
    admin_row = await db_session.scalar(select(User).where(User.email == "boss@example.com"))
    assert admin_row is not None
    admin_row.role = UserRole.admin
    await db_session.commit()

    h_user = {"Authorization": f"Bearer {token_user}"}
    h_admin = {"Authorization": f"Bearer {token_admin}"}

    r = client.post(
        "/tasks",
        headers=h_user,
        json={"title": "User task", "description": None, "is_done": False},
    )
    assert r.status_code == 201
    task_id = r.json()["id"]
    user_id = r.json()["owner_id"]

    r = client.get(f"/admin/tasks/{task_id}", headers=h_admin)
    assert r.status_code == 200
    assert r.json()["title"] == "User task"

    r = client.patch(f"/admin/tasks/{task_id}", headers=h_admin, json={"is_done": True})
    assert r.status_code == 200
    assert r.json()["is_done"] is True

    r = client.delete(f"/admin/tasks/{task_id}", headers=h_admin)
    assert r.status_code == 204

    r = client.get(f"/admin/tasks/{task_id}", headers=h_admin)
    assert r.status_code == 404

    r = client.post(
        "/admin/tasks",
        headers=h_admin,
        json={
            "title": "Assigned",
            "description": "x",
            "is_done": False,
            "owner_id": user_id,
        },
    )
    assert r.status_code == 201
    assert r.json()["owner_id"] == user_id


@pytest.mark.asyncio
async def test_admin_post_task_unknown_owner(client: TestClient, db_session: AsyncSession) -> None:
    token_admin = _register_and_token(client, "admin2@example.com")
    admin_row = await db_session.scalar(select(User).where(User.email == "admin2@example.com"))
    assert admin_row is not None
    admin_row.role = UserRole.admin
    await db_session.commit()
    h_admin = {"Authorization": f"Bearer {token_admin}"}
    r = client.post(
        "/admin/tasks",
        headers=h_admin,
        json={
            "title": "X",
            "description": None,
            "is_done": False,
            "owner_id": 999_999,
        },
    )
    assert r.status_code == 404


@pytest.mark.asyncio
async def test_user_forbidden_admin_task_mutations(
    client: TestClient, db_session: AsyncSession
) -> None:
    token_user = _register_and_token(client, "uonly@example.com")
    h = {"Authorization": f"Bearer {token_user}"}
    r = client.post("/tasks", headers=h, json={"title": "T", "description": None, "is_done": False})
    tid = r.json()["id"]
    r = client.patch(f"/admin/tasks/{tid}", headers=h, json={"is_done": True})
    assert r.status_code == 403
    r = client.delete(f"/admin/tasks/{tid}", headers=h)
    assert r.status_code == 403


def test_metrics(client: TestClient) -> None:
    r = client.get("/metrics")
    assert r.status_code == 200
    assert b"process_cpu" in r.content or b"python_info" in r.content or b"# HELP" in r.content


def test_tasks_filter_and_sort(client: TestClient) -> None:
    token = _register_and_token(client, "sort@example.com")
    headers = {"Authorization": f"Bearer {token}"}
    client.post(
        "/tasks",
        headers=headers,
        json={"title": "A", "description": None, "is_done": False},
    )
    client.post(
        "/tasks",
        headers=headers,
        json={"title": "B", "description": None, "is_done": True},
    )
    r = client.get("/tasks", headers=headers, params={"is_done": "false"})
    assert r.status_code == 200
    assert len(r.json()) == 1
    assert r.json()[0]["title"] == "A"
    r2 = client.get("/tasks", headers=headers, params={"sort": "status", "order": "asc"})
    assert r2.status_code == 200
    titles = [t["title"] for t in r2.json()]
    assert titles == ["A", "B"]

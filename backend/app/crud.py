"""Операции с БД — асинхронный слой (SQLAlchemy 2.0 AsyncSession)."""

from sqlalchemy import delete as sql_delete
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.models import Task, User, UserRole
from app.schemas import TaskCreate, TaskUpdate, UserCreate
from app.security import hash_password


async def get_user_by_email(db: AsyncSession, email: str) -> User | None:
    return await db.scalar(select(User).where(User.email == email))


async def get_user_by_id(db: AsyncSession, user_id: int) -> User | None:
    return await db.scalar(select(User).where(User.id == user_id))


async def create_user(db: AsyncSession, data: UserCreate, role: UserRole = UserRole.user) -> User:
    user = User(
        email=data.email,
        hashed_password=hash_password(data.password),
        role=role,
    )
    db.add(user)
    await db.commit()
    await db.refresh(user)
    return user


async def list_tasks_for_user(
    db: AsyncSession,
    owner_id: int,
    *,
    is_done: bool | None = None,
    sort_by: str = "created_at",
    sort_order: str = "desc",
) -> list[Task]:
    q = select(Task).where(Task.owner_id == owner_id)
    if is_done is not None:
        q = q.where(Task.is_done == is_done)

    sort_col = Task.is_done if sort_by == "status" else Task.created_at
    if sort_order == "asc":
        q = q.order_by(sort_col.asc(), Task.id.asc())
    else:
        q = q.order_by(sort_col.desc(), Task.id.desc())

    result = await db.scalars(q)
    return list(result.all())


async def list_all_tasks(
    db: AsyncSession,
    *,
    is_done: bool | None = None,
    sort_by: str = "created_at",
    sort_order: str = "desc",
) -> list[Task]:
    q = select(Task).options(selectinload(Task.owner))
    if is_done is not None:
        q = q.where(Task.is_done == is_done)

    sort_col = Task.is_done if sort_by == "status" else Task.created_at
    if sort_order == "asc":
        q = q.order_by(sort_col.asc(), Task.id.asc())
    else:
        q = q.order_by(sort_col.desc(), Task.id.desc())

    result = await db.scalars(q)
    return list(result.all())


async def get_task_for_user(db: AsyncSession, task_id: int, owner_id: int) -> Task | None:
    return await db.scalar(select(Task).where(Task.id == task_id, Task.owner_id == owner_id))


async def get_task_by_id(db: AsyncSession, task_id: int) -> Task | None:
    return await db.scalar(
        select(Task).options(selectinload(Task.owner)).where(Task.id == task_id),
    )


async def create_task(db: AsyncSession, owner_id: int, data: TaskCreate) -> Task:
    task = Task(
        title=data.title,
        description=data.description,
        is_done=data.is_done,
        owner_id=owner_id,
    )
    db.add(task)
    await db.commit()
    await db.refresh(task)
    return task


async def update_task(db: AsyncSession, task: Task, data: TaskUpdate) -> Task:
    if data.title is not None:
        task.title = data.title
    if data.description is not None:
        task.description = data.description
    if data.is_done is not None:
        task.is_done = data.is_done
    db.add(task)
    await db.commit()
    await db.refresh(task)
    return task


async def delete_task(db: AsyncSession, task: Task) -> None:
    await db.execute(sql_delete(Task).where(Task.id == task.id))
    await db.commit()

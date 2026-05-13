import logging
from typing import Annotated, Literal

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.crud import (
    create_task,
    delete_task,
    get_task_by_id,
    get_user_by_id,
    list_all_tasks,
    update_task,
)
from app.database import get_db
from app.deps import require_admin
from app.models import User
from app.schemas import TaskCreate, TaskCreateAdmin, TaskRead, TaskUpdate, task_read_for_admin

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/admin", tags=["Администрирование"])


@router.get("/tasks", response_model=list[TaskRead])
async def all_tasks(
    db: Annotated[AsyncSession, Depends(get_db)],
    _: Annotated[User, Depends(require_admin)],
    is_done: bool | None = Query(
        default=None,
        description="Фильтр: только выполненные (true) или только активные (false)",
    ),
    sort: Literal["created_at", "status"] = Query(
        default="created_at",
        description="Сортировка: по дате создания или по статусу",
    ),
    order: Literal["asc", "desc"] = Query(
        default="desc",
        description="Порядок сортировки",
    ),
) -> list[TaskRead]:
    """RBAC: только роль admin видит задачи всех пользователей."""
    tasks = await list_all_tasks(db, is_done=is_done, sort_by=sort, sort_order=order)
    logger.info("admin_list_all_tasks", extra={"count": len(tasks)})
    return [task_read_for_admin(t) for t in tasks]


@router.post("/tasks", response_model=TaskRead, status_code=status.HTTP_201_CREATED)
async def create_task_for_user(
    data: TaskCreateAdmin,
    db: Annotated[AsyncSession, Depends(get_db)],
    admin: Annotated[User, Depends(require_admin)],
) -> TaskRead:
    owner = await get_user_by_id(db, data.owner_id)
    if owner is None:
        raise HTTPException(status_code=404, detail="Пользователь не найден")
    payload = TaskCreate(
        title=data.title,
        description=data.description,
        is_done=data.is_done,
    )
    task = await create_task(db, owner_id=data.owner_id, data=payload)
    task_full = await get_task_by_id(db, task.id)
    if task_full is None:
        raise HTTPException(status_code=500, detail="Не удалось загрузить созданную задачу")
    logger.info(
        "admin_task_created",
        extra={"task_id": task_full.id, "owner_id": data.owner_id, "by": admin.id},
    )
    return task_read_for_admin(task_full)


@router.get("/tasks/{task_id}", response_model=TaskRead)
async def get_task(
    task_id: int,
    db: Annotated[AsyncSession, Depends(get_db)],
    _: Annotated[User, Depends(require_admin)],
) -> TaskRead:
    task = await get_task_by_id(db, task_id)
    if task is None:
        raise HTTPException(status_code=404, detail="Задача не найдена")
    return task_read_for_admin(task)


@router.patch("/tasks/{task_id}", response_model=TaskRead)
async def patch_task(
    task_id: int,
    data: TaskUpdate,
    db: Annotated[AsyncSession, Depends(get_db)],
    admin: Annotated[User, Depends(require_admin)],
) -> TaskRead:
    task = await get_task_by_id(db, task_id)
    if task is None:
        raise HTTPException(status_code=404, detail="Задача не найдена")
    task = await update_task(db, task, data)
    task_full = await get_task_by_id(db, task.id)
    if task_full is None:
        raise HTTPException(status_code=500, detail="Не удалось загрузить задачу после обновления")
    logger.info("admin_task_updated", extra={"task_id": task_full.id, "by": admin.id})
    return task_read_for_admin(task_full)


@router.delete("/tasks/{task_id}", status_code=status.HTTP_204_NO_CONTENT)
async def remove_task(
    task_id: int,
    db: Annotated[AsyncSession, Depends(get_db)],
    admin: Annotated[User, Depends(require_admin)],
) -> None:
    task = await get_task_by_id(db, task_id)
    if task is None:
        raise HTTPException(status_code=404, detail="Задача не найдена")
    await delete_task(db, task)
    logger.info("admin_task_deleted", extra={"task_id": task_id, "by": admin.id})

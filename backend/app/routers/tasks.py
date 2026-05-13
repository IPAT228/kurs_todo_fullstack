import logging
from typing import Annotated, Literal

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.crud import create_task, delete_task, get_task_for_user, list_tasks_for_user, update_task
from app.database import get_db
from app.deps import get_current_user
from app.models import User
from app.schemas import TaskCreate, TaskRead, TaskUpdate

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/tasks", tags=["Задачи"])


@router.get("", response_model=list[TaskRead])
async def list_tasks(
    db: Annotated[AsyncSession, Depends(get_db)],
    user: Annotated[User, Depends(get_current_user)],
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
    # Фильтрация/сортировка применяются в CRUD-слое, чтобы роутер оставался тонким.
    tasks = await list_tasks_for_user(
        db,
        user.id,
        is_done=is_done,
        sort_by=sort,
        sort_order=order,
    )
    logger.info("tasks_list", extra={"user_id": user.id, "count": len(tasks)})
    return [TaskRead.model_validate(t) for t in tasks]


@router.post("", response_model=TaskRead, status_code=status.HTTP_201_CREATED)
async def create(
    data: TaskCreate,
    db: Annotated[AsyncSession, Depends(get_db)],
    user: Annotated[User, Depends(get_current_user)],
) -> TaskRead:
    task = await create_task(db, owner_id=user.id, data=data)
    logger.info("task_created", extra={"task_id": task.id, "user_id": user.id})
    return TaskRead.model_validate(task)


@router.get("/{task_id}", response_model=TaskRead)
async def get_one(
    task_id: int,
    db: Annotated[AsyncSession, Depends(get_db)],
    user: Annotated[User, Depends(get_current_user)],
) -> TaskRead:
    # Возвращаем только задачу владельца; чужие id не раскрываем.
    task = await get_task_for_user(db, task_id, user.id)
    if task is None:
        raise HTTPException(status_code=404, detail="Задача не найдена")
    return TaskRead.model_validate(task)


@router.patch("/{task_id}", response_model=TaskRead)
async def patch(
    task_id: int,
    data: TaskUpdate,
    db: Annotated[AsyncSession, Depends(get_db)],
    user: Annotated[User, Depends(get_current_user)],
) -> TaskRead:
    task = await get_task_for_user(db, task_id, user.id)
    if task is None:
        raise HTTPException(status_code=404, detail="Задача не найдена")
    task = await update_task(db, task, data)
    logger.info("task_updated", extra={"task_id": task.id})
    return TaskRead.model_validate(task)


@router.delete("/{task_id}", status_code=status.HTTP_204_NO_CONTENT)
async def remove(
    task_id: int,
    db: Annotated[AsyncSession, Depends(get_db)],
    user: Annotated[User, Depends(get_current_user)],
) -> None:
    # Единая проверка владения перед удалением защищает от доступа к чужим данным.
    task = await get_task_for_user(db, task_id, user.id)
    if task is None:
        raise HTTPException(status_code=404, detail="Задача не найдена")
    await delete_task(db, task)
    logger.info("task_deleted", extra={"task_id": task_id})

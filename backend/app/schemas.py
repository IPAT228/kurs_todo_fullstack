from datetime import datetime
from enum import Enum

from pydantic import BaseModel, EmailStr, Field

from app.models import Task


class UserRoleEnum(str, Enum):
    user = "user"
    admin = "admin"


class UserCreate(BaseModel):
    email: EmailStr = Field(description="Электронная почта")
    password: str = Field(min_length=6, description="Пароль (не короче 6 символов)")


class UserRead(BaseModel):
    id: int = Field(description="Идентификатор пользователя")
    email: EmailStr = Field(description="Электронная почта")
    role: UserRoleEnum = Field(description="Роль: user или admin")
    created_at: datetime = Field(description="Дата регистрации")

    model_config = {"from_attributes": True}


class Token(BaseModel):
    access_token: str = Field(description="JWT для заголовка Authorization: Bearer …")
    token_type: str = Field(default="bearer", description="Тип токена (OAuth2)")


class TokenPayload(BaseModel):
    sub: str
    role: UserRoleEnum


class TaskCreate(BaseModel):
    title: str = Field(min_length=1, max_length=200, description="Краткий заголовок задачи")
    description: str | None = Field(default=None, max_length=4000, description="Подробное описание")
    is_done: bool = Field(default=False, description="Признак выполнения")


class TaskCreateAdmin(TaskCreate):
    owner_id: int = Field(description="Пользователь, для которого создаётся задача")


class TaskUpdate(BaseModel):
    title: str | None = Field(
        default=None,
        min_length=1,
        max_length=200,
        description="Новый заголовок",
    )
    description: str | None = Field(default=None, max_length=4000, description="Новое описание")
    is_done: bool | None = Field(default=None, description="Признак выполнения")


class TaskRead(BaseModel):
    id: int = Field(description="Идентификатор задачи")
    title: str = Field(description="Заголовок")
    description: str | None = Field(description="Описание")
    is_done: bool = Field(description="Выполнена ли задача")
    owner_id: int = Field(description="Владелец (id пользователя)")
    owner_email: str | None = Field(
        default=None,
        description="Email владельца (только если relationship owner загружен, обычно в /admin)",
    )
    created_at: datetime = Field(description="Создана")
    updated_at: datetime = Field(description="Обновлена")

    model_config = {"from_attributes": True}


def task_read_for_admin(task: Task) -> TaskRead:
    """Сборка ответа для админских маршрутов при загруженном `task.owner`."""
    owner_email = task.owner.email if task.owner is not None else None
    return TaskRead(
        id=task.id,
        title=task.title,
        description=task.description,
        is_done=task.is_done,
        owner_id=task.owner_id,
        owner_email=owner_email,
        created_at=task.created_at,
        updated_at=task.updated_at,
    )

import logging
from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import OAuth2PasswordRequestForm
from sqlalchemy.ext.asyncio import AsyncSession

from app.crud import create_user, get_user_by_email
from app.database import get_db
from app.deps import get_current_user
from app.models import User
from app.schemas import Token, UserCreate, UserRead, UserRoleEnum
from app.security import create_access_token, verify_password

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/auth", tags=["Аутентификация"])


@router.post("/register", response_model=UserRead, status_code=status.HTTP_201_CREATED)
async def register(
    data: UserCreate,
    db: Annotated[AsyncSession, Depends(get_db)],
) -> UserRead:
    if await get_user_by_email(db, data.email):
        raise HTTPException(status_code=400, detail="Email уже зарегистрирован")
    user = await create_user(db, data)
    logger.info("user_registered", extra={"email": user.email})
    return UserRead.model_validate(user)


@router.post("/login", response_model=Token)
async def login(
    form: Annotated[OAuth2PasswordRequestForm, Depends()],
    db: Annotated[AsyncSession, Depends(get_db)],
) -> Token:
    user = await get_user_by_email(db, form.username)
    if user is None or not verify_password(form.password, user.hashed_password):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Неверный email или пароль",
        )
    token = create_access_token(subject=user.email, role=UserRoleEnum(user.role.value))
    logger.info("user_login", extra={"email": user.email})
    return Token(access_token=token)


@router.get("/me", response_model=UserRead)
async def read_me(user: Annotated[User, Depends(get_current_user)]) -> UserRead:
    """Текущий пользователь и роль из БД (для клиентов: админские маршруты)."""
    return UserRead.model_validate(user)

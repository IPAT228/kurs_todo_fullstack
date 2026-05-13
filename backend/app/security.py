from datetime import UTC, datetime, timedelta

import bcrypt
from jose import JWTError, jwt

from app.config import settings
from app.schemas import TokenPayload, UserRoleEnum


def hash_password(password: str) -> str:
    return bcrypt.hashpw(password.encode("utf-8"), bcrypt.gensalt()).decode("utf-8")


def verify_password(plain: str, hashed: str) -> bool:
    return bcrypt.checkpw(plain.encode("utf-8"), hashed.encode("utf-8"))


def create_access_token(*, subject: str, role: UserRoleEnum) -> str:
    expire = datetime.now(tz=UTC) + timedelta(minutes=settings.access_token_expire_minutes)
    payload = {"sub": subject, "role": role.value, "exp": expire}
    return jwt.encode(payload, settings.secret_key, algorithm=settings.algorithm)


def decode_token(token: str) -> TokenPayload | None:
    try:
        data = jwt.decode(token, settings.secret_key, algorithms=[settings.algorithm])
        sub = data.get("sub")
        role = data.get("role")
        if sub is None or role is None:
            return None
        return TokenPayload(sub=sub, role=UserRoleEnum(role))
    except JWTError:
        return None

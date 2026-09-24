from typing import Annotated

from fastapi import Depends, HTTPException, Path, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from pydantic import BaseModel
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.security import decode_access_token
from app.db import get_db
from app.models import Center, CenterMember, MemberRole, User, UserRole

bearer = HTTPBearer(auto_error=False)

DB = Annotated[Session, Depends(get_db)]


def get_current_user(db: DB, creds: Annotated[HTTPAuthorizationCredentials | None, Depends(bearer)]) -> User:
    if creds is None:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Authentification requise")
    payload = decode_access_token(creds.credentials)
    if not payload:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Session expirée, veuillez vous reconnecter")
    user = db.get(User, int(payload["sub"]))
    if user is None or not user.is_active:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Compte inactif")
    return user


def get_optional_user(db: DB, creds: Annotated[HTTPAuthorizationCredentials | None, Depends(bearer)]) -> User | None:
    if creds is None:
        return None
    payload = decode_access_token(creds.credentials)
    return db.get(User, int(payload["sub"])) if payload else None


CurrentUser = Annotated[User, Depends(get_current_user)]
OptionalUser = Annotated[User | None, Depends(get_optional_user)]


def require_superadmin(user: CurrentUser) -> User:
    if user.role != UserRole.superadmin:
        raise HTTPException(status.HTTP_403_FORBIDDEN, "Réservé au super-administrateur")
    return user


class CenterContext(BaseModel):
    model_config = {"arbitrary_types_allowed": True}
    center: Center
    user: User
    role: MemberRole | None  # None = super-admin

    @property
    def is_owner(self) -> bool:
        return self.role in (None, MemberRole.owner)


def center_context(db: DB, user: CurrentUser, center_id: Annotated[int, Path()]) -> CenterContext:
    center = db.get(Center, center_id)
    if center is None:
        raise HTTPException(404, "Centre introuvable")
    if user.role == UserRole.superadmin:
        return CenterContext(center=center, user=user, role=None)
    member = db.scalar(select(CenterMember).where(CenterMember.center_id == center_id,
                                                  CenterMember.user_id == user.id,
                                                  CenterMember.is_active.is_(True)))
    if member is None:
        raise HTTPException(status.HTTP_403_FORBIDDEN, "Vous n'êtes pas gestionnaire de ce centre")
    return CenterContext(center=center, user=user, role=member.role)


Ctx = Annotated[CenterContext, Depends(center_context)]


def require_owner(ctx: Ctx) -> CenterContext:
    if not ctx.is_owner:
        raise HTTPException(status.HTTP_403_FORBIDDEN, "Action réservée au propriétaire du centre")
    return ctx


OwnerCtx = Annotated[CenterContext, Depends(require_owner)]


def apply_patch(obj, patch: BaseModel) -> None:
    for key, value in patch.model_dump(exclude_unset=True).items():
        setattr(obj, key, value)

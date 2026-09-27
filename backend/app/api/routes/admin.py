"""Administration de la plateforme (super-admin)."""

from datetime import timedelta

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import func, select

from app.api.deps import DB, require_superadmin
from app.db import utcnow
from app.models import (
    AppSetting,
    Center,
    CenterMember,
    LoyaltyAccount,
    MemberRole,
    PointTransaction,
    User,
    UserRole,
    Wash,
)
from app.schemas.center import CenterOut
from app.schemas.platform import AdminCenterOut, AppSettingOut, AppSettingUpdate, PlatformStats
from app.services.points import expire_points, send_expiry_reminders
from app.services.suggestions import run_reminders

router = APIRouter(prefix="/admin", tags=["Super-admin"], dependencies=[Depends(require_superadmin)])


@router.get("/settings", response_model=list[AppSettingOut])
def list_settings(db: DB):
    return db.scalars(select(AppSetting).order_by(AppSetting.group, AppSetting.key)).all()


@router.put("/settings/{key}", response_model=AppSettingOut)
def update_setting(key: str, body: AppSettingUpdate, db: DB):
    s = db.get(AppSetting, key)
    if s is None:
        raise HTTPException(404, "Paramètre introuvable")
    s.value = body.value
    db.commit()
    return s


@router.get("/centers", response_model=list[AdminCenterOut])
def list_centers(db: DB):
    out = []
    for c in db.scalars(select(Center).order_by(Center.created_at.desc())):
        owner = db.scalar(select(User.email).join(CenterMember).where(CenterMember.center_id == c.id,
                                                                     CenterMember.role == MemberRole.owner))
        out.append(AdminCenterOut(
            id=c.id, name=c.name, city=c.city, is_active=c.is_active, created_at=c.created_at, owner_email=owner,
            washes_count=db.scalar(select(func.count(Wash.id)).where(Wash.center_id == c.id)) or 0,
            clients_count=db.scalar(select(func.count(LoyaltyAccount.id)).where(LoyaltyAccount.center_id == c.id)) or 0,
        ))
    return out


@router.post("/centers/{center_id}/toggle", response_model=CenterOut)
def toggle_center(center_id: int, db: DB):
    c = db.get(Center, center_id)
    if c is None:
        raise HTTPException(404, "Centre introuvable")
    c.is_active = not c.is_active
    db.commit()
    return c


@router.get("/stats", response_model=PlatformStats)
def platform_stats(db: DB):
    return PlatformStats(
        centers=db.scalar(select(func.count(Center.id))) or 0,
        active_centers=db.scalar(select(func.count(Center.id)).where(Center.is_active.is_(True))) or 0,
        clients=db.scalar(select(func.count(User.id)).where(User.role == UserRole.client)) or 0,
        washes=db.scalar(select(func.count(Wash.id))) or 0,
        washes_30d=db.scalar(select(func.count(Wash.id)).where(Wash.created_at >= utcnow() - timedelta(days=30))) or 0,
        points_issued=db.scalar(select(func.coalesce(func.sum(PointTransaction.points), 0))
                                .where(PointTransaction.points > 0)) or 0,
    )


@router.post("/jobs/reminders")
def trigger_reminders(db: DB):
    """Lance immédiatement les tâches quotidiennes (expiration des points, relances, rappels de lavage)."""
    expired = expire_points(db)
    expiry = send_expiry_reminders(db)
    sent = run_reminders(db)
    return {"sent": sent + expiry, "wash_reminders": sent, "expiry_reminders": expiry, "points_expired": expired}

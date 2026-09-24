from datetime import datetime
from typing import Any

from pydantic import BaseModel

from app.schemas.common import ORM


class AppSettingOut(ORM):
    key: str
    value: Any
    label: str
    description: str | None
    group: str
    updated_at: datetime


class AppSettingUpdate(BaseModel):
    value: Any


class AdminCenterOut(ORM):
    id: int
    name: str
    city: str
    is_active: bool
    created_at: datetime
    washes_count: int = 0
    clients_count: int = 0
    owner_email: str | None = None


class PlatformStats(BaseModel):
    centers: int
    active_centers: int
    clients: int
    washes: int
    washes_30d: int
    points_issued: int

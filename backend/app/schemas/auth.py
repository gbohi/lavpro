from datetime import datetime

from pydantic import BaseModel, EmailStr, Field

from app.models.enums import MemberRole, UserRole
from app.schemas.common import ORM


class LoginIn(BaseModel):
    email: EmailStr
    password: str


class RegisterIn(BaseModel):
    email: EmailStr
    password: str = Field(min_length=6)
    first_name: str = Field(min_length=1, max_length=100)
    last_name: str = ""
    phone: str | None = None
    referral_code: str | None = None


class MembershipOut(ORM):
    center_id: int
    center_name: str
    role: MemberRole


class UserOut(ORM):
    id: int
    email: str
    phone: str | None
    first_name: str
    last_name: str
    avatar_url: str | None
    role: UserRole
    member_code: str
    referral_code: str
    eco_mode: bool
    notifications_enabled: bool
    weather_reminders: bool
    created_at: datetime


class MeOut(UserOut):
    qr_payload: str
    memberships: list[MembershipOut] = []


class TokenOut(BaseModel):
    access_token: str
    token_type: str = "bearer"
    user: MeOut


class UserUpdate(BaseModel):
    first_name: str | None = None
    last_name: str | None = None
    phone: str | None = None
    avatar_url: str | None = None
    eco_mode: bool | None = None
    notifications_enabled: bool | None = None
    weather_reminders: bool | None = None
    last_lat: float | None = None
    last_lng: float | None = None


class PasswordChange(BaseModel):
    current_password: str
    new_password: str = Field(min_length=6)


class DeviceTokenIn(BaseModel):
    token: str
    platform: str = "android"

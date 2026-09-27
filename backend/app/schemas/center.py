from datetime import datetime

from pydantic import BaseModel, EmailStr, Field

from app.models.enums import MemberRole
from app.schemas.common import ORM


class OpeningDay(BaseModel):
    day: int = Field(ge=0, le=6, description="0 = lundi ... 6 = dimanche")
    open: str = "08:00"
    close: str = "19:00"
    closed: bool = False


class CenterBase(BaseModel):
    name: str | None = None
    description: str | None = None
    address: str | None = None
    city: str | None = None
    country: str | None = None
    phone: str | None = None
    email: EmailStr | None = None
    logo_url: str | None = None
    cover_url: str | None = None
    lat: float | None = None
    lng: float | None = None
    currency: str | None = None
    timezone: str | None = None
    opening_hours: list[OpeningDay] | None = None
    capacity: int | None = Field(default=None, ge=1)
    booking_enabled: bool | None = None
    slot_duration_minutes: int | None = Field(default=None, ge=5)
    booking_min_notice_minutes: int | None = Field(default=None, ge=0)
    booking_max_days_ahead: int | None = Field(default=None, ge=0)
    occupancy_moderate_ratio: float | None = Field(default=None, ge=0)
    occupancy_high_ratio: float | None = Field(default=None, ge=0)
    welcome_points: int | None = Field(default=None, ge=0)
    referral_referrer_points: int | None = Field(default=None, ge=0)
    referral_referee_points: int | None = Field(default=None, ge=0)
    loyal_min_visits: int | None = Field(default=None, ge=1)
    loyal_period_days: int | None = Field(default=None, ge=1)
    inactive_after_days: int | None = Field(default=None, ge=1)
    points_payment_enabled: bool | None = None
    points_validity_months: int | None = Field(default=None, ge=1, le=120, description="None = pas d'expiration")
    points_expiry_reminders: list[int] | None = Field(default=None, description="Relances en jours avant expiration")
    reminder_enabled: bool | None = None
    reminder_default_days: int | None = Field(default=None, ge=1)


class CenterUpdate(CenterBase):
    pass


class CenterRegisterIn(BaseModel):
    """Inscription d'un centre + de son gérant propriétaire."""

    center_name: str = Field(min_length=2)
    address: str = ""
    city: str = ""
    country: str = ""
    phone: str | None = None
    lat: float | None = None
    lng: float | None = None
    currency: str = "XOF"
    owner_email: EmailStr
    owner_password: str = Field(min_length=6)
    owner_first_name: str
    owner_last_name: str = ""
    owner_phone: str | None = None


class CenterOut(ORM):
    id: int
    name: str
    slug: str
    description: str | None
    address: str
    city: str
    country: str
    phone: str | None
    email: str | None
    logo_url: str | None
    cover_url: str | None
    lat: float | None
    lng: float | None
    currency: str
    timezone: str
    is_active: bool
    opening_hours: list[OpeningDay]
    capacity: int
    booking_enabled: bool
    slot_duration_minutes: int
    booking_min_notice_minutes: int
    booking_max_days_ahead: int
    occupancy_moderate_ratio: float
    occupancy_high_ratio: float
    welcome_points: int
    referral_referrer_points: int
    referral_referee_points: int
    loyal_min_visits: int
    loyal_period_days: int
    inactive_after_days: int
    points_payment_enabled: bool
    points_validity_months: int | None
    points_expiry_reminders: list[int]
    reminder_enabled: bool
    reminder_default_days: int
    current_queue: int
    created_at: datetime


class Occupancy(BaseModel):
    level: str  # low | moderate | high | closed
    queue: int
    active_bookings: int
    capacity: int
    estimated_wait_minutes: int
    is_open: bool


class CenterPublic(ORM):
    id: int
    name: str
    slug: str
    description: str | None
    address: str
    city: str
    phone: str | None
    logo_url: str | None
    cover_url: str | None
    lat: float | None
    lng: float | None
    currency: str
    booking_enabled: bool
    points_payment_enabled: bool = False
    points_validity_months: int | None = None
    opening_hours: list[OpeningDay]
    distance_km: float | None = None
    occupancy: Occupancy | None = None
    my_balance: int | None = None


class QueueUpdate(BaseModel):
    value: int | None = Field(default=None, ge=0)
    delta: int | None = None


class MemberOut(ORM):
    id: int
    user_id: int
    role: MemberRole
    permissions: list[str] = []
    is_active: bool
    email: str
    first_name: str
    last_name: str
    phone: str | None
    created_at: datetime


class MemberCreate(BaseModel):
    email: EmailStr
    first_name: str
    last_name: str = ""
    phone: str | None = None
    password: str | None = Field(default=None, min_length=6)
    role: MemberRole = MemberRole.manager
    permissions: list[str] | None = Field(default=None, description="Droits du gestionnaire (défaut : réglage plateforme)")


class MemberUpdate(BaseModel):
    role: MemberRole | None = None
    permissions: list[str] | None = None
    is_active: bool | None = None


class WasherIn(BaseModel):
    first_name: str
    last_name: str = ""
    phone: str | None = None
    photo_url: str | None = None
    commission_rate: float = Field(default=0, ge=0, le=100)
    is_active: bool = True


class WasherUpdate(BaseModel):
    first_name: str | None = None
    last_name: str | None = None
    phone: str | None = None
    photo_url: str | None = None
    commission_rate: float | None = Field(default=None, ge=0, le=100)
    is_active: bool | None = None


class WasherOut(ORM):
    id: int
    first_name: str
    last_name: str
    full_name: str
    phone: str | None
    photo_url: str | None
    commission_rate: float
    is_active: bool
    created_at: datetime

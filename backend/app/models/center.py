from datetime import datetime

from sqlalchemy import JSON, Boolean, DateTime, Enum, Float, ForeignKey, Integer, String, Text, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db import Base, utcnow
from app.models.enums import MemberRole


def default_opening_hours() -> list[dict]:
    return [{"day": d, "open": "08:00", "close": "19:00", "closed": d == 6} for d in range(7)]


class Center(Base):
    __tablename__ = "centers"

    id: Mapped[int] = mapped_column(primary_key=True)
    name: Mapped[str] = mapped_column(String(150))
    slug: Mapped[str] = mapped_column(String(160), unique=True, index=True)
    description: Mapped[str | None] = mapped_column(Text)
    address: Mapped[str] = mapped_column(String(255), default="")
    city: Mapped[str] = mapped_column(String(100), default="")
    country: Mapped[str] = mapped_column(String(100), default="")
    phone: Mapped[str | None] = mapped_column(String(32))
    email: Mapped[str | None] = mapped_column(String(255))
    logo_url: Mapped[str | None] = mapped_column(String(500))
    cover_url: Mapped[str | None] = mapped_column(String(500))
    lat: Mapped[float | None] = mapped_column(Float)
    lng: Mapped[float | None] = mapped_column(Float)
    currency: Mapped[str] = mapped_column(String(8), default="XOF")
    timezone: Mapped[str] = mapped_column(String(64), default="UTC")
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)

    # Affluence & réservation
    opening_hours: Mapped[list] = mapped_column(JSON, default=default_opening_hours)
    capacity: Mapped[int] = mapped_column(Integer, default=2)
    booking_enabled: Mapped[bool] = mapped_column(Boolean, default=True)
    slot_duration_minutes: Mapped[int] = mapped_column(Integer, default=30)
    booking_min_notice_minutes: Mapped[int] = mapped_column(Integer, default=30)
    booking_max_days_ahead: Mapped[int] = mapped_column(Integer, default=14)
    current_queue: Mapped[int] = mapped_column(Integer, default=0)
    queue_updated_at: Mapped[datetime | None] = mapped_column(DateTime)
    occupancy_moderate_ratio: Mapped[float] = mapped_column(Float, default=0.5)
    occupancy_high_ratio: Mapped[float] = mapped_column(Float, default=1.0)

    # Fidélité
    welcome_points: Mapped[int] = mapped_column(Integer, default=0)
    referral_referrer_points: Mapped[int] = mapped_column(Integer, default=0)
    referral_referee_points: Mapped[int] = mapped_column(Integer, default=0)
    loyal_min_visits: Mapped[int] = mapped_column(Integer, default=3)
    loyal_period_days: Mapped[int] = mapped_column(Integer, default=90)
    inactive_after_days: Mapped[int] = mapped_column(Integer, default=45)

    # Rappels
    reminder_enabled: Mapped[bool] = mapped_column(Boolean, default=True)
    reminder_default_days: Mapped[int] = mapped_column(Integer, default=14)

    created_at: Mapped[datetime] = mapped_column(DateTime, default=utcnow)

    members: Mapped[list["CenterMember"]] = relationship(back_populates="center", cascade="all, delete-orphan")
    washers: Mapped[list["Washer"]] = relationship(back_populates="center", cascade="all, delete-orphan")


class CenterMember(Base):
    """Gestionnaire d'un centre (compte avec accès au back-office)."""

    __tablename__ = "center_members"
    __table_args__ = (UniqueConstraint("center_id", "user_id"),)

    id: Mapped[int] = mapped_column(primary_key=True)
    center_id: Mapped[int] = mapped_column(ForeignKey("centers.id", ondelete="CASCADE"), index=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    role: Mapped[MemberRole] = mapped_column(Enum(MemberRole), default=MemberRole.manager)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=utcnow)

    center: Mapped[Center] = relationship(back_populates="members")
    user: Mapped["User"] = relationship(back_populates="memberships")  # noqa: F821


class Washer(Base):
    """Laveur : n'a pas besoin de compte, sert à tracer qui a lavé chaque véhicule."""

    __tablename__ = "washers"

    id: Mapped[int] = mapped_column(primary_key=True)
    center_id: Mapped[int] = mapped_column(ForeignKey("centers.id", ondelete="CASCADE"), index=True)
    first_name: Mapped[str] = mapped_column(String(100))
    last_name: Mapped[str] = mapped_column(String(100), default="")
    phone: Mapped[str | None] = mapped_column(String(32))
    photo_url: Mapped[str | None] = mapped_column(String(500))
    commission_rate: Mapped[float] = mapped_column(Float, default=0)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=utcnow)

    center: Mapped[Center] = relationship(back_populates="washers")

    @property
    def full_name(self) -> str:
        return f"{self.first_name} {self.last_name}".strip()

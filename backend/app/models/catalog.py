from datetime import datetime

from sqlalchemy import Boolean, DateTime, Enum, Float, ForeignKey, Integer, String, Text, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db import Base, utcnow
from app.models.enums import PromotionTarget


class VehicleType(Base):
    __tablename__ = "vehicle_types"

    id: Mapped[int] = mapped_column(primary_key=True)
    center_id: Mapped[int] = mapped_column(ForeignKey("centers.id", ondelete="CASCADE"), index=True)
    name: Mapped[str] = mapped_column(String(100))
    icon: Mapped[str] = mapped_column(String(50), default="car")
    # Litres d'eau consommés par un lavage "classique" (référence pour le Mode Écolo)
    eco_baseline_liters: Mapped[float] = mapped_column(Float, default=0)
    sort_order: Mapped[int] = mapped_column(Integer, default=0)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)


class ServiceType(Base):
    __tablename__ = "service_types"

    id: Mapped[int] = mapped_column(primary_key=True)
    center_id: Mapped[int] = mapped_column(ForeignKey("centers.id", ondelete="CASCADE"), index=True)
    name: Mapped[str] = mapped_column(String(100))
    description: Mapped[str | None] = mapped_column(Text)
    icon: Mapped[str] = mapped_column(String(50), default="water")
    duration_minutes: Mapped[int] = mapped_column(Integer, default=30)
    water_used_liters: Mapped[float] = mapped_column(Float, default=0)
    is_eco: Mapped[bool] = mapped_column(Boolean, default=False)
    bookable: Mapped[bool] = mapped_column(Boolean, default=True)
    sort_order: Mapped[int] = mapped_column(Integer, default=0)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)


class PricingRule(Base):
    """Prix et points attribués pour un couple (service, type de véhicule)."""

    __tablename__ = "pricing_rules"
    __table_args__ = (UniqueConstraint("service_type_id", "vehicle_type_id"),)

    id: Mapped[int] = mapped_column(primary_key=True)
    center_id: Mapped[int] = mapped_column(ForeignKey("centers.id", ondelete="CASCADE"), index=True)
    service_type_id: Mapped[int] = mapped_column(ForeignKey("service_types.id", ondelete="CASCADE"))
    vehicle_type_id: Mapped[int] = mapped_column(ForeignKey("vehicle_types.id", ondelete="CASCADE"))
    price: Mapped[float] = mapped_column(Float, default=0)
    points: Mapped[int] = mapped_column(Integer, default=0)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)

    service_type: Mapped[ServiceType] = relationship()
    vehicle_type: Mapped[VehicleType] = relationship()


class Reward(Base):
    __tablename__ = "rewards"

    id: Mapped[int] = mapped_column(primary_key=True)
    center_id: Mapped[int] = mapped_column(ForeignKey("centers.id", ondelete="CASCADE"), index=True)
    name: Mapped[str] = mapped_column(String(150))
    description: Mapped[str | None] = mapped_column(Text)
    category: Mapped[str] = mapped_column(String(50), default="gift")
    image_url: Mapped[str | None] = mapped_column(String(500))
    points_cost: Mapped[int] = mapped_column(Integer)
    stock: Mapped[int | None] = mapped_column(Integer)
    # Offres "Mode Écolo" : débloquées à partir d'un volume d'eau économisé
    eco_min_liters_saved: Mapped[float | None] = mapped_column(Float)
    valid_from: Mapped[datetime | None] = mapped_column(DateTime)
    valid_until: Mapped[datetime | None] = mapped_column(DateTime)
    sort_order: Mapped[int] = mapped_column(Integer, default=0)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=utcnow)


class Promotion(Base):
    __tablename__ = "promotions"

    id: Mapped[int] = mapped_column(primary_key=True)
    center_id: Mapped[int] = mapped_column(ForeignKey("centers.id", ondelete="CASCADE"), index=True)
    name: Mapped[str] = mapped_column(String(150))
    description: Mapped[str | None] = mapped_column(Text)
    points_multiplier: Mapped[float] = mapped_column(Float, default=1)
    bonus_points: Mapped[int] = mapped_column(Integer, default=0)
    discount_percent: Mapped[float] = mapped_column(Float, default=0)
    service_type_id: Mapped[int | None] = mapped_column(ForeignKey("service_types.id", ondelete="SET NULL"))
    vehicle_type_id: Mapped[int | None] = mapped_column(ForeignKey("vehicle_types.id", ondelete="SET NULL"))
    target: Mapped[PromotionTarget] = mapped_column(Enum(PromotionTarget), default=PromotionTarget.all)
    starts_at: Mapped[datetime]
    ends_at: Mapped[datetime]
    notify_clients: Mapped[bool] = mapped_column(Boolean, default=False)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=utcnow)

from datetime import datetime

from pydantic import BaseModel, Field

from app.models.enums import PromotionTarget
from app.schemas.common import ORM


class VehicleTypeIn(BaseModel):
    name: str
    icon: str = "car"
    eco_baseline_liters: float = Field(default=0, ge=0)
    sort_order: int = 0
    is_active: bool = True


class VehicleTypeUpdate(BaseModel):
    name: str | None = None
    icon: str | None = None
    eco_baseline_liters: float | None = Field(default=None, ge=0)
    sort_order: int | None = None
    is_active: bool | None = None


class VehicleTypeOut(ORM, VehicleTypeIn):
    id: int
    center_id: int


class ServiceTypeIn(BaseModel):
    name: str
    description: str | None = None
    icon: str = "water"
    duration_minutes: int = Field(default=30, ge=1)
    water_used_liters: float = Field(default=0, ge=0)
    is_eco: bool = False
    bookable: bool = True
    sort_order: int = 0
    is_active: bool = True


class ServiceTypeUpdate(BaseModel):
    name: str | None = None
    description: str | None = None
    icon: str | None = None
    duration_minutes: int | None = Field(default=None, ge=1)
    water_used_liters: float | None = Field(default=None, ge=0)
    is_eco: bool | None = None
    bookable: bool | None = None
    sort_order: int | None = None
    is_active: bool | None = None


class ServiceTypeOut(ORM, ServiceTypeIn):
    id: int
    center_id: int


class PricingRuleIn(BaseModel):
    service_type_id: int
    vehicle_type_id: int
    price: float = Field(ge=0)
    points: int = Field(ge=0)
    is_active: bool = True


class PricingRuleOut(ORM, PricingRuleIn):
    id: int


class PricingBulkIn(BaseModel):
    rules: list[PricingRuleIn]


class RewardIn(BaseModel):
    name: str
    description: str | None = None
    category: str = "gift"
    image_url: str | None = None
    points_cost: int = Field(ge=1)
    stock: int | None = Field(default=None, ge=0)
    eco_min_liters_saved: float | None = Field(default=None, ge=0)
    valid_from: datetime | None = None
    valid_until: datetime | None = None
    sort_order: int = 0
    is_active: bool = True


class RewardUpdate(BaseModel):
    name: str | None = None
    description: str | None = None
    category: str | None = None
    image_url: str | None = None
    points_cost: int | None = Field(default=None, ge=1)
    stock: int | None = Field(default=None, ge=0)
    eco_min_liters_saved: float | None = Field(default=None, ge=0)
    valid_from: datetime | None = None
    valid_until: datetime | None = None
    sort_order: int | None = None
    is_active: bool | None = None


class RewardOut(ORM, RewardIn):
    id: int
    center_id: int


class RewardForClient(RewardOut):
    affordable: bool = False
    locked_reason: str | None = None


class PromotionIn(BaseModel):
    name: str
    description: str | None = None
    points_multiplier: float = Field(default=1, ge=0)
    bonus_points: int = Field(default=0, ge=0)
    discount_percent: float = Field(default=0, ge=0, le=100)
    service_type_id: int | None = None
    vehicle_type_id: int | None = None
    target: PromotionTarget = PromotionTarget.all
    starts_at: datetime
    ends_at: datetime
    notify_clients: bool = False
    is_active: bool = True


class PromotionUpdate(BaseModel):
    name: str | None = None
    description: str | None = None
    points_multiplier: float | None = Field(default=None, ge=0)
    bonus_points: int | None = Field(default=None, ge=0)
    discount_percent: float | None = Field(default=None, ge=0, le=100)
    service_type_id: int | None = None
    vehicle_type_id: int | None = None
    target: PromotionTarget | None = None
    starts_at: datetime | None = None
    ends_at: datetime | None = None
    notify_clients: bool | None = None
    is_active: bool | None = None


class PromotionOut(ORM, PromotionIn):
    id: int
    center_id: int
    created_at: datetime


class CatalogOut(BaseModel):
    """Catalogue public d'un centre (services x véhicules avec prix/points)."""

    services: list[ServiceTypeOut]
    vehicle_types: list[VehicleTypeOut]
    pricing: list[PricingRuleOut]
    promotions: list[PromotionOut]

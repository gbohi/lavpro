from datetime import datetime

from pydantic import BaseModel, Field

from app.models.enums import BookingStatus, RedemptionStatus, TransactionType
from app.schemas.common import ORM


class ClientVehicleIn(BaseModel):
    label: str
    category: str | None = None
    plate: str | None = None
    brand: str | None = None
    color: str | None = None


class ClientVehicleOut(ORM, ClientVehicleIn):
    id: int


class AccountOut(ORM):
    id: int
    center_id: int
    center_name: str
    center_logo_url: str | None
    balance: int
    total_earned: int
    total_spent: int
    visits: int
    last_visit_at: datetime | None
    next_reward_name: str | None = None
    next_reward_points: int | None = None


class ClientLookupOut(BaseModel):
    user_id: int
    first_name: str
    last_name: str
    email: str
    phone: str | None
    member_code: str
    balance: int
    visits: int
    last_visit_at: datetime | None
    vehicles: list[ClientVehicleOut]
    pending_redemptions: list["RedemptionOut"] = []
    upcoming_bookings: list["BookingOut"] = []
    is_loyal: bool = False


class WashIn(BaseModel):
    client_code: str | None = Field(default=None, description="QR token ou code membre du client (optionnel pour un client de passage)")
    service_type_id: int
    vehicle_type_id: int
    washer_id: int | None = None
    booking_id: int | None = None
    plate: str | None = None
    note: str | None = None
    price_override: float | None = Field(default=None, ge=0)


class WashOut(ORM):
    id: int
    center_id: int
    center_name: str | None = None
    user_id: int | None
    client_name: str | None = None
    service_type_id: int
    service_name: str | None = None
    vehicle_type_id: int
    vehicle_type_name: str | None = None
    washer_id: int | None
    washer_name: str | None = None
    validated_by_name: str | None = None
    plate: str | None
    price: float
    discount: float
    points_earned: int
    water_saved_liters: float
    note: str | None
    created_at: datetime


class RedemptionIn(BaseModel):
    reward_id: int


class RedemptionOut(ORM):
    id: int
    center_id: int
    center_name: str | None = None
    user_id: int
    client_name: str | None = None
    reward_id: int
    reward_name: str | None = None
    points: int
    code: str
    status: RedemptionStatus
    created_at: datetime
    used_at: datetime | None


class TransactionOut(ORM):
    id: int
    type: TransactionType
    points: int
    note: str | None
    center_id: int | None = None
    center_name: str | None = None
    wash_id: int | None
    redemption_id: int | None
    created_at: datetime


class PointsAdjustIn(BaseModel):
    user_id: int
    points: int
    note: str = Field(min_length=2)


class BookingIn(BaseModel):
    center_id: int
    service_type_id: int
    vehicle_type_id: int
    start_at: datetime
    note: str | None = None


class BookingStatusUpdate(BaseModel):
    status: BookingStatus


class BookingOut(ORM):
    id: int
    center_id: int
    center_name: str | None = None
    user_id: int
    client_name: str | None = None
    client_phone: str | None = None
    service_type_id: int
    service_name: str | None = None
    vehicle_type_id: int
    vehicle_type_name: str | None = None
    start_at: datetime
    end_at: datetime
    status: BookingStatus
    note: str | None
    created_at: datetime


class Slot(BaseModel):
    start_at: datetime
    end_at: datetime
    available: int
    capacity: int


class NotificationOut(ORM):
    id: int
    center_id: int | None
    type: str
    title: str
    body: str
    data: dict | None
    is_read: bool
    created_at: datetime


class EcoLevel(BaseModel):
    name: str
    min_liters: float
    icon: str | None = None


class EcoStats(BaseModel):
    total_liters_saved: float
    eco_washes: int
    total_washes: int
    level: EcoLevel | None
    next_level: EcoLevel | None
    equivalences: list[dict]
    monthly: list[dict]


class ReferralStats(BaseModel):
    referral_code: str
    share_message: str
    invited_count: int
    rewarded_count: int
    points_earned: int
    friends: list[dict]


class Suggestion(BaseModel):
    center_id: int
    center_name: str
    kind: str  # reminder | weather | promotion | reward
    title: str
    message: str
    due_in_days: int | None = None
    weather: dict | None = None


class ClientSummary(BaseModel):
    user_id: int
    first_name: str
    last_name: str
    email: str
    phone: str | None
    member_code: str
    balance: int
    total_earned: int
    visits: int
    last_visit_at: datetime | None
    is_loyal: bool
    created_at: datetime


ClientLookupOut.model_rebuild()

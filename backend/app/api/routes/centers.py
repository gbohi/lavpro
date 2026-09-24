"""Endpoints publics / clients sur les centres de lavage."""

from datetime import date

from fastapi import APIRouter, HTTPException, Query
from sqlalchemy import func, or_, select

from app.api.deps import DB, OptionalUser
from app.models import (
    Center,
    LoyaltyAccount,
    PricingRule,
    Reward,
    ServiceType,
    VehicleType,
)
from app.schemas.activity import Slot
from app.schemas.catalog import (
    CatalogOut,
    PricingRuleOut,
    PromotionOut,
    RewardForClient,
    ServiceTypeOut,
    VehicleTypeOut,
)
from app.schemas.center import CenterPublic, Occupancy
from app.services.loyalty import active_promotions, reward_lock_reason
from app.services.occupancy import available_slots, compute_occupancy, haversine_km
from app.services.platform_settings import get_setting

router = APIRouter(prefix="/centers", tags=["Centres (public)"])


def _avg_duration(db, center_id: int) -> int | None:
    v = db.scalar(select(func.avg(ServiceType.duration_minutes)).where(ServiceType.center_id == center_id,
                                                                      ServiceType.is_active.is_(True)))
    return int(v) if v else None


def _public(db, center: Center, user, lat=None, lng=None) -> CenterPublic:
    out = CenterPublic.model_validate(center)
    if lat is not None and lng is not None and center.lat is not None and center.lng is not None:
        out.distance_km = round(haversine_km(lat, lng, center.lat, center.lng), 2)
    out.occupancy = compute_occupancy(db, center, _avg_duration(db, center.id))
    if user is not None:
        out.my_balance = db.scalar(select(LoyaltyAccount.balance).where(LoyaltyAccount.user_id == user.id,
                                                                        LoyaltyAccount.center_id == center.id))
    return out


def _get_active(db, center_id: int) -> Center:
    center = db.get(Center, center_id)
    if center is None or not center.is_active:
        raise HTTPException(404, "Centre introuvable")
    return center


@router.get("", response_model=list[CenterPublic])
def list_centers(db: DB, user: OptionalUser, q: str | None = None, lat: float | None = None,
                 lng: float | None = None, radius_km: float | None = None, limit: int = Query(50, le=200)):
    """Liste des centres, triés par distance si une position est fournie."""
    stmt = select(Center).where(Center.is_active.is_(True))
    if q:
        like = f"%{q.lower()}%"
        stmt = stmt.where(or_(func.lower(Center.name).like(like), func.lower(Center.city).like(like),
                              func.lower(Center.address).like(like)))
    centers = [_public(db, c, user, lat, lng) for c in db.scalars(stmt)]
    if lat is not None and lng is not None:
        radius = radius_km or float(get_setting(db, "centers.search_radius_km", 50))
        centers = [c for c in centers if c.distance_km is None or c.distance_km <= radius]
        centers.sort(key=lambda c: c.distance_km if c.distance_km is not None else 1e9)
    else:
        centers.sort(key=lambda c: c.name.lower())
    return centers[:limit]


@router.get("/{center_id}", response_model=CenterPublic)
def get_center(center_id: int, db: DB, user: OptionalUser, lat: float | None = None, lng: float | None = None):
    return _public(db, _get_active(db, center_id), user, lat, lng)


@router.get("/{center_id}/occupancy", response_model=Occupancy)
def occupancy(center_id: int, db: DB):
    return compute_occupancy(db, _get_active(db, center_id), _avg_duration(db, center_id))


@router.get("/{center_id}/catalog", response_model=CatalogOut)
def catalog(center_id: int, db: DB):
    _get_active(db, center_id)
    services = db.scalars(select(ServiceType).where(ServiceType.center_id == center_id, ServiceType.is_active.is_(True))
                          .order_by(ServiceType.sort_order, ServiceType.id))
    vehicles = db.scalars(select(VehicleType).where(VehicleType.center_id == center_id, VehicleType.is_active.is_(True))
                          .order_by(VehicleType.sort_order, VehicleType.id))
    pricing = db.scalars(select(PricingRule).where(PricingRule.center_id == center_id, PricingRule.is_active.is_(True)))
    return CatalogOut(services=[ServiceTypeOut.model_validate(s) for s in services],
                      vehicle_types=[VehicleTypeOut.model_validate(v) for v in vehicles],
                      pricing=[PricingRuleOut.model_validate(p) for p in pricing],
                      promotions=[PromotionOut.model_validate(p) for p in active_promotions(db, center_id)])


@router.get("/{center_id}/rewards", response_model=list[RewardForClient])
def rewards(center_id: int, db: DB, user: OptionalUser):
    _get_active(db, center_id)
    balance = 0
    if user is not None:
        balance = db.scalar(select(LoyaltyAccount.balance).where(LoyaltyAccount.user_id == user.id,
                                                                 LoyaltyAccount.center_id == center_id)) or 0
    items = []
    for r in db.scalars(select(Reward).where(Reward.center_id == center_id, Reward.is_active.is_(True))
                        .order_by(Reward.sort_order, Reward.points_cost)):
        out = RewardForClient.model_validate(r)
        out.locked_reason = reward_lock_reason(db, r, user, balance)
        out.affordable = out.locked_reason is None
        items.append(out)
    return items


@router.get("/{center_id}/slots", response_model=list[Slot])
def slots(center_id: int, day: date, db: DB, service_type_id: int | None = None):
    center = _get_active(db, center_id)
    duration = None
    if service_type_id:
        st = db.get(ServiceType, service_type_id)
        if st is None or st.center_id != center_id:
            raise HTTPException(404, "Service introuvable")
        duration = st.duration_minutes
    return [Slot(**s) for s in available_slots(db, center, day, duration)]

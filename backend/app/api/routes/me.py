"""Espace client : soldes, historique, récompenses, réservations, écolo, parrainage."""

from collections import defaultdict
from datetime import timedelta

from fastapi import APIRouter, HTTPException, Query
from sqlalchemy import func, select

from app.api.deps import DB, CurrentUser, apply_patch
from app.api.serializers import booking_out, redemption_out, wash_out
from app.db import utcnow
from app.models import (
    Booking,
    BookingStatus,
    Center,
    ClientVehicle,
    LoyaltyAccount,
    Notification,
    PointTransaction,
    Redemption,
    Reward,
    ServiceType,
    TransactionType,
    User,
    VehicleType,
    Wash,
)
from app.schemas.activity import (
    AccountOut,
    BookingIn,
    BookingOut,
    ClientVehicleIn,
    ClientVehicleOut,
    EcoLevel,
    EcoStats,
    NotificationOut,
    RedemptionIn,
    RedemptionOut,
    ReferralStats,
    Suggestion,
    TransactionOut,
    WashOut,
)
from app.services.loyalty import cancel_redemption, eco_saved_liters, get_or_create_account, redeem_reward
from app.services.occupancy import available_slots
from app.services.platform_settings import get_setting
from app.services.suggestions import compute_suggestions
from app.services.timeutils import naive_utc_to_local, to_naive_utc

router = APIRouter(prefix="/me", tags=["Espace client"])


@router.get("/accounts", response_model=list[AccountOut])
def accounts(user: CurrentUser, db: DB):
    out = []
    for acc in db.scalars(select(LoyaltyAccount).where(LoyaltyAccount.user_id == user.id)
                          .order_by(LoyaltyAccount.last_visit_at.desc().nulls_last())):
        nxt = db.scalar(select(Reward).where(Reward.center_id == acc.center_id, Reward.is_active.is_(True),
                                             Reward.points_cost > acc.balance).order_by(Reward.points_cost))
        out.append(AccountOut(id=acc.id, center_id=acc.center_id, center_name=acc.center.name,
                              center_logo_url=acc.center.logo_url, balance=acc.balance,
                              total_earned=acc.total_earned, total_spent=acc.total_spent, visits=acc.visits,
                              last_visit_at=acc.last_visit_at, next_reward_name=nxt.name if nxt else None,
                              next_reward_points=nxt.points_cost if nxt else None))
    return out


# ---- Véhicules -------------------------------------------------------------
@router.get("/vehicles", response_model=list[ClientVehicleOut])
def my_vehicles(user: CurrentUser):
    return user.vehicles


@router.post("/vehicles", response_model=ClientVehicleOut, status_code=201)
def add_vehicle(body: ClientVehicleIn, user: CurrentUser, db: DB):
    v = ClientVehicle(user_id=user.id, **body.model_dump())
    db.add(v)
    db.commit()
    return v


@router.put("/vehicles/{vehicle_id}", response_model=ClientVehicleOut)
def update_vehicle(vehicle_id: int, body: ClientVehicleIn, user: CurrentUser, db: DB):
    v = db.get(ClientVehicle, vehicle_id)
    if v is None or v.user_id != user.id:
        raise HTTPException(404, "Véhicule introuvable")
    apply_patch(v, body)
    db.commit()
    return v


@router.delete("/vehicles/{vehicle_id}", status_code=204)
def delete_vehicle(vehicle_id: int, user: CurrentUser, db: DB):
    v = db.get(ClientVehicle, vehicle_id)
    if v is None or v.user_id != user.id:
        raise HTTPException(404, "Véhicule introuvable")
    db.delete(v)
    db.commit()


@router.get("/vehicle-categories", response_model=list[str])
def vehicle_categories(db: DB):
    return get_setting(db, "vehicle.categories", [])


# ---- Historique ------------------------------------------------------------
@router.get("/washes", response_model=list[WashOut])
def my_washes(user: CurrentUser, db: DB, center_id: int | None = None, limit: int = Query(50, le=200),
              offset: int = 0):
    stmt = select(Wash).where(Wash.user_id == user.id)
    if center_id:
        stmt = stmt.where(Wash.center_id == center_id)
    return [wash_out(w) for w in db.scalars(stmt.order_by(Wash.created_at.desc()).offset(offset).limit(limit))]


@router.get("/transactions", response_model=list[TransactionOut])
def my_transactions(user: CurrentUser, db: DB, center_id: int | None = None, limit: int = Query(50, le=200),
                    offset: int = 0):
    stmt = (select(PointTransaction, LoyaltyAccount).join(LoyaltyAccount)
            .where(LoyaltyAccount.user_id == user.id))
    if center_id:
        stmt = stmt.where(LoyaltyAccount.center_id == center_id)
    rows = db.execute(stmt.order_by(PointTransaction.created_at.desc()).offset(offset).limit(limit)).all()
    out = []
    for tx, acc in rows:
        item = TransactionOut.model_validate(tx)
        item.center_id = acc.center_id
        item.center_name = acc.center.name
        out.append(item)
    return out


# ---- Récompenses -----------------------------------------------------------
@router.get("/redemptions", response_model=list[RedemptionOut])
def my_redemptions(user: CurrentUser, db: DB):
    return [redemption_out(r) for r in db.scalars(select(Redemption).where(Redemption.user_id == user.id)
                                                  .order_by(Redemption.created_at.desc()))]


@router.post("/redemptions", response_model=RedemptionOut, status_code=201)
def redeem(body: RedemptionIn, user: CurrentUser, db: DB):
    reward = db.get(Reward, body.reward_id)
    if reward is None:
        raise HTTPException(404, "Récompense introuvable")
    r = redeem_reward(db, user, reward)
    db.commit()
    return redemption_out(r)


@router.post("/redemptions/{redemption_id}/cancel", response_model=RedemptionOut)
def cancel_my_redemption(redemption_id: int, user: CurrentUser, db: DB):
    r = db.get(Redemption, redemption_id)
    if r is None or r.user_id != user.id:
        raise HTTPException(404, "Récompense introuvable")
    cancel_redemption(db, r, user)
    db.commit()
    return redemption_out(r)


# ---- Réservations ----------------------------------------------------------
@router.get("/bookings", response_model=list[BookingOut])
def my_bookings(user: CurrentUser, db: DB, upcoming: bool = False):
    stmt = select(Booking).where(Booking.user_id == user.id)
    if upcoming:
        stmt = stmt.where(Booking.start_at >= utcnow() - timedelta(hours=1),
                          Booking.status.in_([BookingStatus.pending, BookingStatus.confirmed]))
        stmt = stmt.order_by(Booking.start_at)
    else:
        stmt = stmt.order_by(Booking.start_at.desc())
    return [booking_out(b) for b in db.scalars(stmt)]


@router.post("/bookings", response_model=BookingOut, status_code=201)
def create_booking(body: BookingIn, user: CurrentUser, db: DB):
    center = db.get(Center, body.center_id)
    if center is None or not center.is_active or not center.booking_enabled:
        raise HTTPException(400, "La réservation n'est pas disponible dans ce centre")
    service = db.get(ServiceType, body.service_type_id)
    vehicle = db.get(VehicleType, body.vehicle_type_id)
    if service is None or service.center_id != center.id or not service.bookable:
        raise HTTPException(400, "Service non réservable")
    if vehicle is None or vehicle.center_id != center.id:
        raise HTTPException(400, "Type de véhicule invalide")
    start = to_naive_utc(body.start_at)
    if start > utcnow() + timedelta(days=center.booking_max_days_ahead):
        raise HTTPException(400, "Date trop lointaine")
    local_day = naive_utc_to_local(start, center.timezone).date()
    slot = next((s for s in available_slots(db, center, local_day, service.duration_minutes)
                 if s["start_at"] == start), None)
    if slot is None:
        raise HTTPException(400, "Ce créneau n'est pas disponible")
    if slot["available"] <= 0:
        raise HTTPException(409, "Ce créneau est complet")
    booking = Booking(center_id=center.id, user_id=user.id, service_type_id=service.id, vehicle_type_id=vehicle.id,
                      start_at=start, end_at=slot["end_at"], status=BookingStatus.confirmed, note=body.note)
    db.add(booking)
    get_or_create_account(db, user, center)
    db.commit()
    return booking_out(booking)


@router.post("/bookings/{booking_id}/cancel", response_model=BookingOut)
def cancel_booking(booking_id: int, user: CurrentUser, db: DB):
    b = db.get(Booking, booking_id)
    if b is None or b.user_id != user.id:
        raise HTTPException(404, "Réservation introuvable")
    if b.status not in (BookingStatus.pending, BookingStatus.confirmed):
        raise HTTPException(400, "Réservation non annulable")
    notice = int(get_setting(db, "booking.cancel_min_notice_minutes", 60))
    if b.start_at - utcnow() < timedelta(minutes=notice):
        raise HTTPException(400, f"Annulation possible jusqu'à {notice} minutes avant le créneau")
    b.status = BookingStatus.cancelled
    db.commit()
    return booking_out(b)


# ---- Notifications ---------------------------------------------------------
@router.get("/notifications", response_model=list[NotificationOut])
def notifications(user: CurrentUser, db: DB, limit: int = Query(50, le=200)):
    return db.scalars(select(Notification).where(Notification.user_id == user.id)
                      .order_by(Notification.created_at.desc()).limit(limit)).all()


@router.get("/notifications/unread-count", response_model=int)
def unread_count(user: CurrentUser, db: DB):
    return db.scalar(select(func.count(Notification.id)).where(Notification.user_id == user.id,
                                                               Notification.is_read.is_(False))) or 0


@router.post("/notifications/read-all", status_code=204)
def read_all(user: CurrentUser, db: DB):
    for n in db.scalars(select(Notification).where(Notification.user_id == user.id, Notification.is_read.is_(False))):
        n.is_read = True
    db.commit()


@router.post("/notifications/{notification_id}/read", status_code=204)
def read_one(notification_id: int, user: CurrentUser, db: DB):
    n = db.get(Notification, notification_id)
    if n is None or n.user_id != user.id:
        raise HTTPException(404, "Notification introuvable")
    n.is_read = True
    db.commit()


# ---- Suggestions, Mode Écolo, parrainage -----------------------------------
@router.get("/suggestions", response_model=list[Suggestion])
def suggestions(user: CurrentUser, db: DB):
    return compute_suggestions(db, user)


@router.get("/eco", response_model=EcoStats)
def eco(user: CurrentUser, db: DB):
    washes = list(db.scalars(select(Wash).where(Wash.user_id == user.id).order_by(Wash.created_at)))
    total = eco_saved_liters(db, user.id)
    eco_ids = {s for (s,) in db.execute(select(ServiceType.id).where(ServiceType.is_eco.is_(True)))}
    levels = sorted([EcoLevel(**lv) for lv in get_setting(db, "eco.levels", [])], key=lambda lv: lv.min_liters)
    current = None
    nxt = None
    for lv in levels:
        if total >= lv.min_liters:
            current = lv
        elif nxt is None:
            nxt = lv
    monthly: dict[str, float] = defaultdict(float)
    for w in washes:
        monthly[w.created_at.strftime("%Y-%m")] += w.water_saved_liters
    equivalences = [{"label": e["label"], "icon": e.get("icon"),
                     "value": round(total / e["liters_per_unit"], 1) if e.get("liters_per_unit") else 0}
                    for e in get_setting(db, "eco.equivalences", [])]
    return EcoStats(total_liters_saved=round(total, 1), eco_washes=sum(1 for w in washes if w.service_type_id in eco_ids),
                    total_washes=len(washes), level=current, next_level=nxt, equivalences=equivalences,
                    monthly=[{"month": k, "liters": round(v, 1)} for k, v in sorted(monthly.items())][-12:])


@router.get("/referral", response_model=ReferralStats)
def referral(user: CurrentUser, db: DB):
    friends = list(db.scalars(select(User).where(User.referred_by_id == user.id).order_by(User.created_at.desc())))
    rewarded_ids = {uid for (uid,) in db.execute(select(LoyaltyAccount.user_id).where(
        LoyaltyAccount.user_id.in_([f.id for f in friends] or [-1]), LoyaltyAccount.referral_rewarded.is_(True)))}
    points = db.scalar(select(func.coalesce(func.sum(PointTransaction.points), 0)).join(LoyaltyAccount).where(
        LoyaltyAccount.user_id == user.id, PointTransaction.type == TransactionType.referral)) or 0
    template = get_setting(db, "referral.share_message", "{code}")
    return ReferralStats(referral_code=user.referral_code, share_message=template.replace("{code}", user.referral_code),
                         invited_count=len(friends), rewarded_count=len(rewarded_ids), points_earned=int(points),
                         friends=[{"first_name": f.first_name, "joined_at": f.created_at.isoformat() + "Z",
                                   "rewarded": f.id in rewarded_ids} for f in friends])

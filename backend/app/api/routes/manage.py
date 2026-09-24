"""Back-office des centres de lavage (gérants)."""

import csv
import io
from datetime import date, datetime, time, timedelta

from fastapi import APIRouter, HTTPException, Query
from fastapi.responses import StreamingResponse
from sqlalchemy import func, or_, select

from app.api.deps import DB, Ctx, OwnerCtx, apply_patch
from app.api.routes.auth import create_user
from app.api.serializers import booking_out, member_out, redemption_out, wash_out
from app.db import utcnow
from app.models import (
    Booking,
    BookingStatus,
    CenterMember,
    LoyaltyAccount,
    PointTransaction,
    PricingRule,
    Promotion,
    Redemption,
    RedemptionStatus,
    Reward,
    ServiceType,
    TransactionType,
    User,
    UserRole,
    VehicleType,
    Wash,
    Washer,
)
from app.schemas.activity import (
    BookingOut,
    BookingStatusUpdate,
    ClientLookupOut,
    ClientSummary,
    ClientVehicleOut,
    PointsAdjustIn,
    RedemptionOut,
    TransactionOut,
    WashIn,
    WashOut,
)
from app.schemas.catalog import (
    PricingBulkIn,
    PricingRuleOut,
    PromotionIn,
    PromotionOut,
    PromotionUpdate,
    RewardIn,
    RewardOut,
    RewardUpdate,
    ServiceTypeIn,
    ServiceTypeOut,
    ServiceTypeUpdate,
    VehicleTypeIn,
    VehicleTypeOut,
    VehicleTypeUpdate,
)
from app.schemas.center import (
    CenterOut,
    CenterUpdate,
    MemberCreate,
    MemberOut,
    MemberUpdate,
    Occupancy,
    QueueUpdate,
    WasherIn,
    WasherOut,
    WasherUpdate,
)
from app.services import stats as stats_service
from app.services.loyalty import (
    add_points,
    cancel_redemption,
    find_user_by_code,
    get_or_create_account,
    is_loyal,
    promotion_applies,
    record_wash,
)
from app.services.notifications import notify
from app.services.occupancy import compute_occupancy
from app.services.timeutils import local_now, local_to_naive_utc, to_naive_utc

router = APIRouter(prefix="/manage/centers/{center_id}", tags=["Back-office centre"])


def _own(obj, ctx, label: str):
    if obj is None or obj.center_id != ctx.center.id:
        raise HTTPException(404, f"{label} introuvable")
    return obj


def _period(ctx, start: date | None, end: date | None, default_days: int = 30) -> tuple[datetime, datetime]:
    today = local_now(ctx.center.timezone).date()
    end = end or today
    start = start or end - timedelta(days=default_days - 1)
    if start > end:
        raise HTTPException(400, "Période invalide")
    return (local_to_naive_utc(datetime.combine(start, time.min), ctx.center.timezone),
            local_to_naive_utc(datetime.combine(end + timedelta(days=1), time.min), ctx.center.timezone))


# ---- Centre ----------------------------------------------------------------
@router.get("", response_model=CenterOut)
def get_center(ctx: Ctx):
    return ctx.center


@router.patch("", response_model=CenterOut)
def update_center(body: CenterUpdate, ctx: Ctx, db: DB):
    data = body.model_dump(exclude_unset=True)
    if "opening_hours" in data and data["opening_hours"] is not None:
        data["opening_hours"] = [d if isinstance(d, dict) else d.model_dump() for d in data["opening_hours"]]
    for k, v in data.items():
        setattr(ctx.center, k, v)
    db.commit()
    return ctx.center


@router.get("/occupancy", response_model=Occupancy)
def get_occupancy(ctx: Ctx, db: DB):
    return compute_occupancy(db, ctx.center)


@router.post("/queue", response_model=Occupancy)
def update_queue(body: QueueUpdate, ctx: Ctx, db: DB):
    """Met à jour la file d'attente en temps réel (valeur absolue ou incrément)."""
    if body.value is not None:
        ctx.center.current_queue = body.value
    elif body.delta is not None:
        ctx.center.current_queue = max(0, ctx.center.current_queue + body.delta)
    ctx.center.queue_updated_at = utcnow()
    db.commit()
    return compute_occupancy(db, ctx.center)


# ---- Équipe (gestionnaires) -----------------------------------------------
@router.get("/members", response_model=list[MemberOut])
def list_members(ctx: Ctx, db: DB):
    return [member_out(m) for m in db.scalars(select(CenterMember).where(CenterMember.center_id == ctx.center.id))]


@router.post("/members", response_model=MemberOut, status_code=201)
def add_member(body: MemberCreate, ctx: OwnerCtx, db: DB):
    user = db.scalar(select(User).where(User.email == body.email.lower()))
    if user is None:
        if not body.password:
            raise HTTPException(400, "Mot de passe requis pour créer un nouveau compte gestionnaire")
        user = create_user(db, email=body.email, password=body.password, first_name=body.first_name,
                           last_name=body.last_name, phone=body.phone, role=UserRole.staff)
    elif user.role == UserRole.client:
        user.role = UserRole.staff
    if db.scalar(select(CenterMember).where(CenterMember.center_id == ctx.center.id, CenterMember.user_id == user.id)):
        raise HTTPException(409, "Cette personne fait déjà partie de l'équipe")
    m = CenterMember(center_id=ctx.center.id, user_id=user.id, role=body.role)
    db.add(m)
    notify(db, user, "Bienvenue dans l'équipe", f"Vous êtes désormais gestionnaire de {ctx.center.name}.",
           type_="team", center_id=ctx.center.id, push=False)
    db.commit()
    db.refresh(m)
    return member_out(m)


@router.patch("/members/{member_id}", response_model=MemberOut)
def update_member(member_id: int, body: MemberUpdate, ctx: OwnerCtx, db: DB):
    m = _own(db.get(CenterMember, member_id), ctx, "Membre")
    if m.user_id == ctx.user.id:
        raise HTTPException(400, "Vous ne pouvez pas modifier votre propre accès")
    apply_patch(m, body)
    db.commit()
    return member_out(m)


@router.delete("/members/{member_id}", status_code=204)
def remove_member(member_id: int, ctx: OwnerCtx, db: DB):
    m = _own(db.get(CenterMember, member_id), ctx, "Membre")
    if m.user_id == ctx.user.id:
        raise HTTPException(400, "Vous ne pouvez pas vous retirer vous-même")
    db.delete(m)
    db.commit()


# ---- Laveurs ---------------------------------------------------------------
@router.get("/washers", response_model=list[WasherOut])
def list_washers(ctx: Ctx, db: DB, active_only: bool = False):
    stmt = select(Washer).where(Washer.center_id == ctx.center.id)
    if active_only:
        stmt = stmt.where(Washer.is_active.is_(True))
    return db.scalars(stmt.order_by(Washer.first_name)).all()


@router.post("/washers", response_model=WasherOut, status_code=201)
def add_washer(body: WasherIn, ctx: Ctx, db: DB):
    w = Washer(center_id=ctx.center.id, **body.model_dump())
    db.add(w)
    db.commit()
    return w


@router.patch("/washers/{washer_id}", response_model=WasherOut)
def update_washer(washer_id: int, body: WasherUpdate, ctx: Ctx, db: DB):
    w = _own(db.get(Washer, washer_id), ctx, "Laveur")
    apply_patch(w, body)
    db.commit()
    return w


@router.delete("/washers/{washer_id}", status_code=204)
def delete_washer(washer_id: int, ctx: Ctx, db: DB):
    w = _own(db.get(Washer, washer_id), ctx, "Laveur")
    if db.scalar(select(Wash.id).where(Wash.washer_id == w.id).limit(1)):
        w.is_active = False  # historique conservé
    else:
        db.delete(w)
    db.commit()


# ---- Types de véhicules ----------------------------------------------------
@router.get("/vehicle-types", response_model=list[VehicleTypeOut])
def list_vehicle_types(ctx: Ctx, db: DB):
    return db.scalars(select(VehicleType).where(VehicleType.center_id == ctx.center.id)
                      .order_by(VehicleType.sort_order, VehicleType.id)).all()


@router.post("/vehicle-types", response_model=VehicleTypeOut, status_code=201)
def add_vehicle_type(body: VehicleTypeIn, ctx: Ctx, db: DB):
    v = VehicleType(center_id=ctx.center.id, **body.model_dump())
    db.add(v)
    db.commit()
    return v


@router.patch("/vehicle-types/{item_id}", response_model=VehicleTypeOut)
def update_vehicle_type(item_id: int, body: VehicleTypeUpdate, ctx: Ctx, db: DB):
    v = _own(db.get(VehicleType, item_id), ctx, "Type de véhicule")
    apply_patch(v, body)
    db.commit()
    return v


@router.delete("/vehicle-types/{item_id}", status_code=204)
def delete_vehicle_type(item_id: int, ctx: Ctx, db: DB):
    v = _own(db.get(VehicleType, item_id), ctx, "Type de véhicule")
    used = db.scalar(select(Wash.id).where(Wash.vehicle_type_id == v.id).limit(1)) or \
        db.scalar(select(Booking.id).where(Booking.vehicle_type_id == v.id).limit(1))
    if used:
        v.is_active = False
    else:
        db.delete(v)
    db.commit()


# ---- Services --------------------------------------------------------------
@router.get("/services", response_model=list[ServiceTypeOut])
def list_services(ctx: Ctx, db: DB):
    return db.scalars(select(ServiceType).where(ServiceType.center_id == ctx.center.id)
                      .order_by(ServiceType.sort_order, ServiceType.id)).all()


@router.post("/services", response_model=ServiceTypeOut, status_code=201)
def add_service(body: ServiceTypeIn, ctx: Ctx, db: DB):
    s = ServiceType(center_id=ctx.center.id, **body.model_dump())
    db.add(s)
    db.commit()
    return s


@router.patch("/services/{item_id}", response_model=ServiceTypeOut)
def update_service(item_id: int, body: ServiceTypeUpdate, ctx: Ctx, db: DB):
    s = _own(db.get(ServiceType, item_id), ctx, "Service")
    apply_patch(s, body)
    db.commit()
    return s


@router.delete("/services/{item_id}", status_code=204)
def delete_service(item_id: int, ctx: Ctx, db: DB):
    s = _own(db.get(ServiceType, item_id), ctx, "Service")
    used = db.scalar(select(Wash.id).where(Wash.service_type_id == s.id).limit(1)) or \
        db.scalar(select(Booking.id).where(Booking.service_type_id == s.id).limit(1))
    if used:
        s.is_active = False
    else:
        db.delete(s)
    db.commit()


# ---- Grille tarifaire & points --------------------------------------------
@router.get("/pricing", response_model=list[PricingRuleOut])
def list_pricing(ctx: Ctx, db: DB):
    return db.scalars(select(PricingRule).where(PricingRule.center_id == ctx.center.id)).all()


@router.put("/pricing", response_model=list[PricingRuleOut])
def save_pricing(body: PricingBulkIn, ctx: Ctx, db: DB):
    """Enregistre la matrice prix / points (service x type de véhicule)."""
    services = {s.id for s in db.scalars(select(ServiceType).where(ServiceType.center_id == ctx.center.id))}
    vehicles = {v.id for v in db.scalars(select(VehicleType).where(VehicleType.center_id == ctx.center.id))}
    existing = {(r.service_type_id, r.vehicle_type_id): r
                for r in db.scalars(select(PricingRule).where(PricingRule.center_id == ctx.center.id))}
    for rule in body.rules:
        if rule.service_type_id not in services or rule.vehicle_type_id not in vehicles:
            raise HTTPException(400, "Service ou type de véhicule invalide")
        current = existing.get((rule.service_type_id, rule.vehicle_type_id))
        if current:
            current.price, current.points, current.is_active = rule.price, rule.points, rule.is_active
        else:
            db.add(PricingRule(center_id=ctx.center.id, **rule.model_dump()))
    db.commit()
    return list_pricing(ctx, db)


# ---- Récompenses -----------------------------------------------------------
@router.get("/rewards", response_model=list[RewardOut])
def list_rewards(ctx: Ctx, db: DB):
    return db.scalars(select(Reward).where(Reward.center_id == ctx.center.id)
                      .order_by(Reward.sort_order, Reward.points_cost)).all()


@router.post("/rewards", response_model=RewardOut, status_code=201)
def add_reward(body: RewardIn, ctx: Ctx, db: DB):
    r = Reward(center_id=ctx.center.id, **body.model_dump())
    db.add(r)
    db.commit()
    return r


@router.patch("/rewards/{item_id}", response_model=RewardOut)
def update_reward(item_id: int, body: RewardUpdate, ctx: Ctx, db: DB):
    r = _own(db.get(Reward, item_id), ctx, "Récompense")
    apply_patch(r, body)
    db.commit()
    return r


@router.delete("/rewards/{item_id}", status_code=204)
def delete_reward(item_id: int, ctx: Ctx, db: DB):
    r = _own(db.get(Reward, item_id), ctx, "Récompense")
    if db.scalar(select(Redemption.id).where(Redemption.reward_id == r.id).limit(1)):
        r.is_active = False
    else:
        db.delete(r)
    db.commit()


# ---- Promotions ------------------------------------------------------------
def _promo_targets(db, ctx, promo: Promotion) -> list[User]:
    accounts = db.scalars(select(LoyaltyAccount).where(LoyaltyAccount.center_id == ctx.center.id))
    return [a.user for a in accounts if promotion_applies(db, promo, a.user, ctx.center, a)]


@router.get("/promotions", response_model=list[PromotionOut])
def list_promotions(ctx: Ctx, db: DB):
    return db.scalars(select(Promotion).where(Promotion.center_id == ctx.center.id)
                      .order_by(Promotion.starts_at.desc())).all()


@router.post("/promotions", response_model=PromotionOut, status_code=201)
def add_promotion(body: PromotionIn, ctx: Ctx, db: DB):
    if body.ends_at <= body.starts_at:
        raise HTTPException(400, "La date de fin doit être postérieure à la date de début")
    data = body.model_dump()
    data["starts_at"] = to_naive_utc(data["starts_at"])
    data["ends_at"] = to_naive_utc(data["ends_at"])
    p = Promotion(center_id=ctx.center.id, **data)
    db.add(p)
    db.flush()
    if p.notify_clients and p.is_active:
        for user in _promo_targets(db, ctx, p):
            notify(db, user, f"{ctx.center.name} : {p.name}", p.description or "Nouvelle offre disponible !",
                   type_="promotion", center_id=ctx.center.id, data={"promotion_id": p.id})
    db.commit()
    return p


@router.patch("/promotions/{item_id}", response_model=PromotionOut)
def update_promotion(item_id: int, body: PromotionUpdate, ctx: Ctx, db: DB):
    p = _own(db.get(Promotion, item_id), ctx, "Promotion")
    apply_patch(p, body)
    for f in ("starts_at", "ends_at"):
        v = getattr(p, f)
        if v is not None:
            setattr(p, f, to_naive_utc(v))
    db.commit()
    return p


@router.delete("/promotions/{item_id}", status_code=204)
def delete_promotion(item_id: int, ctx: Ctx, db: DB):
    p = _own(db.get(Promotion, item_id), ctx, "Promotion")
    db.delete(p)
    db.commit()


# ---- Clients ---------------------------------------------------------------
@router.get("/clients/lookup", response_model=ClientLookupOut)
def lookup_client(code: str, ctx: Ctx, db: DB):
    """Identifie un client via son QR code ou son code membre."""
    user = find_user_by_code(db, code)
    if user is None:
        raise HTTPException(404, "Client introuvable")
    acc = db.scalar(select(LoyaltyAccount).where(LoyaltyAccount.user_id == user.id,
                                                 LoyaltyAccount.center_id == ctx.center.id))
    pending = db.scalars(select(Redemption).where(Redemption.user_id == user.id,
                                                  Redemption.center_id == ctx.center.id,
                                                  Redemption.status == RedemptionStatus.pending))
    bookings = db.scalars(select(Booking).where(Booking.user_id == user.id, Booking.center_id == ctx.center.id,
                                                Booking.status.in_([BookingStatus.pending, BookingStatus.confirmed]),
                                                Booking.start_at >= utcnow() - timedelta(hours=3))
                          .order_by(Booking.start_at))
    return ClientLookupOut(user_id=user.id, first_name=user.first_name, last_name=user.last_name, email=user.email,
                           phone=user.phone, member_code=user.member_code, balance=acc.balance if acc else 0,
                           visits=acc.visits if acc else 0, last_visit_at=acc.last_visit_at if acc else None,
                           vehicles=[ClientVehicleOut.model_validate(v) for v in user.vehicles],
                           pending_redemptions=[redemption_out(r) for r in pending],
                           upcoming_bookings=[booking_out(b) for b in bookings],
                           is_loyal=is_loyal(db, user.id, ctx.center))


@router.get("/clients", response_model=list[ClientSummary])
def list_clients(ctx: Ctx, db: DB, q: str | None = None, segment: str | None = Query(None, pattern="^(loyal|inactive|new)$"),
                 limit: int = Query(100, le=500), offset: int = 0):
    stmt = select(LoyaltyAccount, User).join(User).where(LoyaltyAccount.center_id == ctx.center.id)
    if q:
        like = f"%{q.lower()}%"
        stmt = stmt.where(or_(func.lower(User.first_name).like(like), func.lower(User.last_name).like(like),
                              func.lower(User.email).like(like), User.phone.like(like),
                              User.member_code == q.upper()))
    now = utcnow()
    if segment == "inactive":
        stmt = stmt.where(LoyaltyAccount.last_visit_at < now - timedelta(days=ctx.center.inactive_after_days))
    elif segment == "new":
        stmt = stmt.where(LoyaltyAccount.created_at >= now - timedelta(days=30))
    rows = db.execute(stmt.order_by(LoyaltyAccount.last_visit_at.desc()).offset(offset).limit(limit)).all()
    since = now - timedelta(days=ctx.center.loyal_period_days)
    counts = dict(db.execute(select(Wash.user_id, func.count(Wash.id)).where(
        Wash.center_id == ctx.center.id, Wash.created_at >= since).group_by(Wash.user_id)).all())
    out = []
    for acc, user in rows:
        loyal = counts.get(user.id, 0) >= ctx.center.loyal_min_visits
        if segment == "loyal" and not loyal:
            continue
        out.append(ClientSummary(user_id=user.id, first_name=user.first_name, last_name=user.last_name,
                                 email=user.email, phone=user.phone, member_code=user.member_code,
                                 balance=acc.balance, total_earned=acc.total_earned, visits=acc.visits,
                                 last_visit_at=acc.last_visit_at, is_loyal=loyal, created_at=acc.created_at))
    return out


@router.get("/clients/{user_id}/transactions", response_model=list[TransactionOut])
def client_transactions(user_id: int, ctx: Ctx, db: DB):
    acc = db.scalar(select(LoyaltyAccount).where(LoyaltyAccount.user_id == user_id,
                                                 LoyaltyAccount.center_id == ctx.center.id))
    if acc is None:
        raise HTTPException(404, "Client introuvable")
    return db.scalars(select(PointTransaction).where(PointTransaction.account_id == acc.id)
                      .order_by(PointTransaction.created_at.desc())).all()


@router.post("/points/adjust", response_model=TransactionOut)
def adjust_points(body: PointsAdjustIn, ctx: Ctx, db: DB):
    user = db.get(User, body.user_id)
    if user is None:
        raise HTTPException(404, "Client introuvable")
    acc = get_or_create_account(db, user, ctx.center)
    tx = add_points(db, acc, body.points, TransactionType.bonus if body.points > 0 else TransactionType.adjust,
                    note=body.note, created_by_id=ctx.user.id)
    if body.points > 0:
        notify(db, user, "Points offerts 🎁", f"{ctx.center.name} vous offre {body.points} points : {body.note}",
               type_="bonus", center_id=ctx.center.id)
    db.commit()
    return tx


# ---- Lavages ---------------------------------------------------------------
@router.post("/washes", response_model=WashOut, status_code=201)
def create_wash(body: WashIn, ctx: Ctx, db: DB):
    """Valide un lavage : attribue les points au client et trace le laveur."""
    user = None
    if body.client_code:
        user = find_user_by_code(db, body.client_code)
        if user is None:
            raise HTTPException(404, "Client introuvable")
    wash = record_wash(db, ctx.center, service_type_id=body.service_type_id, vehicle_type_id=body.vehicle_type_id,
                       user=user, washer_id=body.washer_id, validated_by=ctx.user, booking_id=body.booking_id,
                       plate=body.plate, note=body.note, price_override=body.price_override)
    db.commit()
    db.refresh(wash)
    return wash_out(wash)


def _washes_query(ctx, start, end, washer_id, service_type_id):
    stmt = select(Wash).where(Wash.center_id == ctx.center.id, Wash.created_at >= start, Wash.created_at < end)
    if washer_id:
        stmt = stmt.where(Wash.washer_id == washer_id)
    if service_type_id:
        stmt = stmt.where(Wash.service_type_id == service_type_id)
    return stmt.order_by(Wash.created_at.desc())


@router.get("/washes", response_model=list[WashOut])
def list_washes(ctx: Ctx, db: DB, date_from: date | None = None, date_to: date | None = None,
                washer_id: int | None = None, service_type_id: int | None = None,
                limit: int = Query(200, le=1000), offset: int = 0):
    start, end = _period(ctx, date_from, date_to, 1)
    stmt = _washes_query(ctx, start, end, washer_id, service_type_id).offset(offset).limit(limit)
    return [wash_out(w) for w in db.scalars(stmt)]


@router.delete("/washes/{wash_id}", status_code=204)
def cancel_wash(wash_id: int, ctx: OwnerCtx, db: DB):
    """Annule un lavage saisi par erreur (retire les points attribués)."""
    w = _own(db.get(Wash, wash_id), ctx, "Lavage")
    if w.user_id and w.points_earned:
        acc = db.scalar(select(LoyaltyAccount).where(LoyaltyAccount.user_id == w.user_id,
                                                     LoyaltyAccount.center_id == ctx.center.id))
        if acc:
            add_points(db, acc, -min(w.points_earned, acc.balance), TransactionType.adjust,
                       note=f"Annulation du lavage #{w.id}", created_by_id=ctx.user.id)
            acc.total_earned -= min(w.points_earned, acc.total_earned)
            acc.visits = max(0, acc.visits - 1)
    db.delete(w)
    db.commit()


@router.get("/washes/export")
def export_washes(ctx: Ctx, db: DB, date_from: date | None = None, date_to: date | None = None,
                  washer_id: int | None = None):
    start, end = _period(ctx, date_from, date_to)
    buf = io.StringIO()
    writer = csv.writer(buf, delimiter=";")
    writer.writerow(["Date", "Client", "Service", "Véhicule", "Immatriculation", "Laveur", "Validé par",
                     f"Prix ({ctx.center.currency})", "Remise", "Points"])
    for w in db.scalars(_washes_query(ctx, start, end, washer_id, None)):
        o = wash_out(w)
        writer.writerow([w.created_at.isoformat(), o.client_name or "Client de passage", o.service_name,
                         o.vehicle_type_name, w.plate or "", o.washer_name or "", o.validated_by_name or "",
                         w.price, w.discount, w.points_earned])
    return StreamingResponse(iter(["﻿" + buf.getvalue()]), media_type="text/csv",
                             headers={"Content-Disposition": "attachment; filename=lavages.csv"})


# ---- Récompenses échangées -------------------------------------------------
@router.get("/redemptions", response_model=list[RedemptionOut])
def list_redemptions(ctx: Ctx, db: DB, status: RedemptionStatus | None = None, limit: int = Query(200, le=1000)):
    stmt = select(Redemption).where(Redemption.center_id == ctx.center.id)
    if status:
        stmt = stmt.where(Redemption.status == status)
    return [redemption_out(r) for r in db.scalars(stmt.order_by(Redemption.created_at.desc()).limit(limit))]


def _find_redemption(db, ctx, key: str) -> Redemption:
    r = db.get(Redemption, int(key)) if key.isdigit() else None
    if r is None:
        r = db.scalar(select(Redemption).where(Redemption.code == key.upper()))
    return _own(r, ctx, "Récompense")


@router.post("/redemptions/{key}/validate", response_model=RedemptionOut)
def validate_redemption(key: str, ctx: Ctx, db: DB):
    """Remet la récompense au client (par id ou code de retrait)."""
    r = _find_redemption(db, ctx, key)
    if r.status != RedemptionStatus.pending:
        raise HTTPException(400, "Récompense déjà remise ou annulée")
    r.status = RedemptionStatus.used
    r.used_at = utcnow()
    r.validated_by_id = ctx.user.id
    db.commit()
    return redemption_out(r)


@router.post("/redemptions/{key}/cancel", response_model=RedemptionOut)
def cancel_center_redemption(key: str, ctx: Ctx, db: DB):
    r = _find_redemption(db, ctx, key)
    cancel_redemption(db, r, ctx.user)
    db.commit()
    return redemption_out(r)


# ---- Réservations ----------------------------------------------------------
@router.get("/bookings", response_model=list[BookingOut])
def list_bookings(ctx: Ctx, db: DB, day: date | None = None, status: BookingStatus | None = None):
    stmt = select(Booking).where(Booking.center_id == ctx.center.id)
    if day:
        start = local_to_naive_utc(datetime.combine(day, time.min), ctx.center.timezone)
        stmt = stmt.where(Booking.start_at >= start, Booking.start_at < start + timedelta(days=1))
    if status:
        stmt = stmt.where(Booking.status == status)
    return [booking_out(b) for b in db.scalars(stmt.order_by(Booking.start_at))]


@router.patch("/bookings/{booking_id}", response_model=BookingOut)
def update_booking(booking_id: int, body: BookingStatusUpdate, ctx: Ctx, db: DB):
    b = _own(db.get(Booking, booking_id), ctx, "Réservation")
    b.status = body.status
    if body.status == BookingStatus.cancelled:
        notify(db, b.user, "Réservation annulée",
               f"Votre réservation chez {ctx.center.name} a été annulée par le centre.", type_="booking",
               center_id=ctx.center.id)
    db.commit()
    return booking_out(b)


# ---- Statistiques & rapports ------------------------------------------------
@router.get("/stats/dashboard")
def dashboard(ctx: Ctx, db: DB, date_from: date | None = None, date_to: date | None = None):
    start, end = _period(ctx, date_from, date_to)
    return stats_service.dashboard(db, ctx.center, start, end)


@router.get("/stats/washers")
def washers_report(ctx: Ctx, db: DB, date_from: date | None = None, date_to: date | None = None):
    """Point de lavage par laveur."""
    start, end = _period(ctx, date_from, date_to)
    data = stats_service.dashboard(db, ctx.center, start, end)
    details: dict[int | None, dict] = {}
    for w in db.scalars(_washes_query(ctx, start, end, None, None)):
        d = details.setdefault(w.washer_id, {"services": {}})
        name = w.service_type.name
        d["services"][name] = d["services"].get(name, 0) + 1
    for row in data["washers"]:
        row["services"] = details.get(row["id"], {}).get("services", {})
    return {"period": data["period"], "currency": ctx.center.currency, "washers": data["washers"]}

from datetime import timedelta

from fastapi import HTTPException
from sqlalchemy import func, or_, select
from sqlalchemy.orm import Session

from app.core.security import random_code
from app.db import utcnow
from app.models import (
    Booking,
    BookingStatus,
    Center,
    LoyaltyAccount,
    PointTransaction,
    PricingRule,
    Promotion,
    PromotionTarget,
    Redemption,
    RedemptionStatus,
    Reward,
    ServiceType,
    TransactionType,
    User,
    VehicleType,
    Wash,
    Washer,
)
from app.services.notifications import notify

QR_PREFIX = "LAVPRO:"


def find_user_by_code(db: Session, code: str) -> User | None:
    code = code.strip()
    if code.upper().startswith(QR_PREFIX):
        code = code[len(QR_PREFIX):]
    return db.scalar(select(User).where(or_(User.qr_token == code, User.member_code == code.upper())))


def get_or_create_account(db: Session, user: User, center: Center) -> LoyaltyAccount:
    account = db.scalar(select(LoyaltyAccount).where(LoyaltyAccount.user_id == user.id,
                                                     LoyaltyAccount.center_id == center.id))
    if account is None:
        account = LoyaltyAccount(user_id=user.id, center_id=center.id, balance=0, total_earned=0,
                                 total_spent=0, visits=0)
        db.add(account)
        db.flush()
        if center.welcome_points > 0:
            add_points(db, account, center.welcome_points, TransactionType.welcome,
                       note=f"Bienvenue chez {center.name}")
    return account


def add_points(db: Session, account: LoyaltyAccount, points: int, type_: TransactionType, *, note: str | None = None,
               wash_id: int | None = None, redemption_id: int | None = None,
               created_by_id: int | None = None) -> PointTransaction:
    account.balance += points
    if points > 0 and type_ != TransactionType.refund:
        account.total_earned += points
    elif points < 0 and type_ == TransactionType.redeem:
        account.total_spent += -points
    elif type_ == TransactionType.refund:
        account.total_spent -= points
    if account.balance < 0:
        raise HTTPException(400, "Solde de points insuffisant")
    tx = PointTransaction(account_id=account.id, type=type_, points=points, note=note, wash_id=wash_id,
                          redemption_id=redemption_id, created_by_id=created_by_id)
    db.add(tx)
    return tx


def visits_in_period(db: Session, user_id: int, center: Center) -> int:
    since = utcnow() - timedelta(days=center.loyal_period_days)
    return db.scalar(select(func.count(Wash.id)).where(Wash.center_id == center.id, Wash.user_id == user_id,
                                                       Wash.created_at >= since)) or 0


def is_loyal(db: Session, user_id: int, center: Center) -> bool:
    return visits_in_period(db, user_id, center) >= center.loyal_min_visits


def promotion_applies(db: Session, promo: Promotion, user: User | None, center: Center,
                      account: LoyaltyAccount | None) -> bool:
    if promo.target == PromotionTarget.all:
        return True
    if user is None:
        return False
    if promo.target == PromotionTarget.loyal:
        return is_loyal(db, user.id, center)
    if promo.target == PromotionTarget.new:
        return account is None or account.visits == 0
    if promo.target == PromotionTarget.inactive:
        if account is None or account.last_visit_at is None:
            return False
        return (utcnow() - account.last_visit_at).days >= center.inactive_after_days
    return False


def active_promotions(db: Session, center_id: int, service_type_id: int | None = None,
                      vehicle_type_id: int | None = None) -> list[Promotion]:
    now = utcnow()
    q = select(Promotion).where(Promotion.center_id == center_id, Promotion.is_active.is_(True),
                                Promotion.starts_at <= now, Promotion.ends_at >= now)
    promos = list(db.scalars(q))
    return [p for p in promos
            if (p.service_type_id is None or service_type_id is None or p.service_type_id == service_type_id)
            and (p.vehicle_type_id is None or vehicle_type_id is None or p.vehicle_type_id == vehicle_type_id)]


def _apply_referral(db: Session, user: User, center: Center, account: LoyaltyAccount) -> None:
    """Au premier lavage d'un filleul dans un centre, le parrain et le filleul reçoivent leurs bonus."""
    if user.referred_by_id is None or account.referral_rewarded:
        return
    already = db.scalar(select(func.count(LoyaltyAccount.id)).where(LoyaltyAccount.user_id == user.id,
                                                                  LoyaltyAccount.referral_rewarded.is_(True)))
    if already:
        return
    account.referral_rewarded = True
    if center.referral_referee_points > 0:
        add_points(db, account, center.referral_referee_points, TransactionType.referral,
                   note="Bonus de parrainage (filleul)")
    referrer = db.get(User, user.referred_by_id)
    if referrer is not None and center.referral_referrer_points > 0:
        ref_account = get_or_create_account(db, referrer, center)
        add_points(db, ref_account, center.referral_referrer_points, TransactionType.referral,
                   note=f"Parrainage de {user.first_name}")
        notify(db, referrer, "Parrainage récompensé 🎉",
               f"{user.first_name} a effectué son premier lavage chez {center.name}. "
               f"Vous gagnez {center.referral_referrer_points} points !", type_="referral", center_id=center.id)


def record_wash(db: Session, center: Center, *, service_type_id: int, vehicle_type_id: int, user: User | None,
                washer_id: int | None, validated_by: User, booking_id: int | None = None, plate: str | None = None,
                note: str | None = None, price_override: float | None = None) -> Wash:
    service = db.get(ServiceType, service_type_id)
    vehicle = db.get(VehicleType, vehicle_type_id)
    if service is None or service.center_id != center.id:
        raise HTTPException(404, "Service introuvable")
    if vehicle is None or vehicle.center_id != center.id:
        raise HTTPException(404, "Type de véhicule introuvable")
    if washer_id is not None:
        washer = db.get(Washer, washer_id)
        if washer is None or washer.center_id != center.id:
            raise HTTPException(404, "Laveur introuvable")
    rule = db.scalar(select(PricingRule).where(PricingRule.service_type_id == service.id,
                                               PricingRule.vehicle_type_id == vehicle.id,
                                               PricingRule.is_active.is_(True)))
    base_price = rule.price if rule else 0.0
    base_points = rule.points if rule else 0

    account = None
    if user is not None:
        account = db.scalar(select(LoyaltyAccount).where(LoyaltyAccount.user_id == user.id,
                                                         LoyaltyAccount.center_id == center.id))

    points = float(base_points)
    discount_pct = 0.0
    applied_promo: Promotion | None = None
    for promo in active_promotions(db, center.id, service.id, vehicle.id):
        if not promotion_applies(db, promo, user, center, account):
            continue
        candidate = base_points * promo.points_multiplier + promo.bonus_points
        if candidate > points or (applied_promo is None and promo.discount_percent > 0):
            points = max(points, candidate)
            applied_promo = promo
        discount_pct = max(discount_pct, promo.discount_percent)

    price = price_override if price_override is not None else base_price
    discount = round(price * discount_pct / 100, 2)
    water_saved = max(0.0, vehicle.eco_baseline_liters - service.water_used_liters)

    if booking_id is not None:
        booking = db.get(Booking, booking_id)
        if booking is None or booking.center_id != center.id:
            raise HTTPException(404, "Réservation introuvable")
        booking.status = BookingStatus.completed
        if user is None:
            user = booking.user

    wash = Wash(center_id=center.id, user_id=user.id if user else None, service_type_id=service.id,
                vehicle_type_id=vehicle.id, washer_id=washer_id, validated_by_id=validated_by.id,
                booking_id=booking_id, promotion_id=applied_promo.id if applied_promo else None, plate=plate,
                price=price - discount, discount=discount, points_earned=int(round(points)) if user else 0,
                water_saved_liters=water_saved if user else 0, note=note)
    db.add(wash)
    db.flush()

    if user is not None:
        account = account or get_or_create_account(db, user, center)
        if wash.points_earned:
            add_points(db, account, wash.points_earned, TransactionType.earn,
                       note=f"{service.name} · {vehicle.name}", wash_id=wash.id, created_by_id=validated_by.id)
        account.visits += 1
        account.last_visit_at = wash.created_at
        _apply_referral(db, user, center, account)
        notify(db, user, "Merci pour votre visite ✨",
               f"Votre {service.name.lower()} chez {center.name} vous rapporte {wash.points_earned} points. "
               f"Solde : {account.balance} pts.", type_="wash", center_id=center.id,
               data={"wash_id": wash.id, "points": wash.points_earned, "balance": account.balance})
    if center.current_queue > 0:
        center.current_queue -= 1
        center.queue_updated_at = utcnow()
    return wash


def eco_saved_liters(db: Session, user_id: int) -> float:
    return float(db.scalar(select(func.coalesce(func.sum(Wash.water_saved_liters), 0))
                           .where(Wash.user_id == user_id)) or 0)


def reward_lock_reason(db: Session, reward: Reward, user: User | None, balance: int) -> str | None:
    now = utcnow()
    if not reward.is_active:
        return "Offre indisponible"
    if reward.valid_from and reward.valid_from > now:
        return "Pas encore disponible"
    if reward.valid_until and reward.valid_until < now:
        return "Offre expirée"
    if reward.stock is not None and reward.stock <= 0:
        return "Rupture de stock"
    if reward.eco_min_liters_saved and user is not None:
        saved = eco_saved_liters(db, user.id)
        if saved < reward.eco_min_liters_saved:
            return f"Mode Écolo : économisez {reward.eco_min_liters_saved - saved:.0f} L de plus"
    if balance < reward.points_cost:
        return f"Encore {reward.points_cost - balance} points"
    return None


def redeem_reward(db: Session, user: User, reward: Reward) -> Redemption:
    center = db.get(Center, reward.center_id)
    account = get_or_create_account(db, user, center)
    reason = reward_lock_reason(db, reward, user, account.balance)
    if reason:
        raise HTTPException(400, reason)
    code = random_code(8)
    while db.scalar(select(Redemption.id).where(Redemption.code == code)):
        code = random_code(8)
    redemption = Redemption(center_id=center.id, user_id=user.id, reward_id=reward.id, points=reward.points_cost,
                            code=code, status=RedemptionStatus.pending)
    db.add(redemption)
    db.flush()
    add_points(db, account, -reward.points_cost, TransactionType.redeem, note=reward.name,
               redemption_id=redemption.id)
    if reward.stock is not None:
        reward.stock -= 1
    return redemption


def cancel_redemption(db: Session, redemption: Redemption, by: User | None = None) -> None:
    if redemption.status != RedemptionStatus.pending:
        raise HTTPException(400, "Cette récompense ne peut plus être annulée")
    redemption.status = RedemptionStatus.cancelled
    center = db.get(Center, redemption.center_id)
    account = get_or_create_account(db, redemption.user, center)
    add_points(db, account, redemption.points, TransactionType.refund, note="Annulation récompense",
               redemption_id=redemption.id, created_by_id=by.id if by else None)
    reward = db.get(Reward, redemption.reward_id)
    if reward and reward.stock is not None:
        reward.stock += 1

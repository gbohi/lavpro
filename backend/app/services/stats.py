from collections import defaultdict
from datetime import datetime, timedelta

from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.models import (
    Booking,
    Center,
    LoyaltyAccount,
    PointTransaction,
    Redemption,
    RedemptionStatus,
    ServiceType,
    TransactionType,
    User,
    VehicleType,
    Wash,
    Washer,
)
from app.services.timeutils import naive_utc_to_local


def dashboard(db: Session, center: Center, start: datetime, end: datetime) -> dict:
    washes = list(db.scalars(select(Wash).where(Wash.center_id == center.id, Wash.created_at >= start,
                                                Wash.created_at < end)))
    total = len(washes)
    revenue = round(sum(w.price for w in washes), 2)
    client_ids = {w.user_id for w in washes if w.user_id}
    anonymous = sum(1 for w in washes if not w.user_id)

    per_day: dict[str, dict] = {}
    day = naive_utc_to_local(start, center.timezone).date()
    last = naive_utc_to_local(end - timedelta(seconds=1), center.timezone).date()
    while day <= last:
        per_day[day.isoformat()] = {"date": day.isoformat(), "washes": 0, "revenue": 0.0}
        day += timedelta(days=1)
    hours = [0] * 24
    weekdays = [0] * 7
    by_service: dict[int, dict] = defaultdict(lambda: {"count": 0, "revenue": 0.0})
    by_vehicle: dict[int, int] = defaultdict(int)
    by_washer: dict[int | None, dict] = defaultdict(lambda: {"count": 0, "revenue": 0.0})
    for w in washes:
        local = naive_utc_to_local(w.created_at, center.timezone)
        key = local.date().isoformat()
        if key in per_day:
            per_day[key]["washes"] += 1
            per_day[key]["revenue"] = round(per_day[key]["revenue"] + w.price, 2)
        hours[local.hour] += 1
        weekdays[local.weekday()] += 1
        by_service[w.service_type_id]["count"] += 1
        by_service[w.service_type_id]["revenue"] += w.price
        by_vehicle[w.vehicle_type_id] += 1
        by_washer[w.washer_id]["count"] += 1
        by_washer[w.washer_id]["revenue"] += w.price

    services = {s.id: s.name for s in db.scalars(select(ServiceType).where(ServiceType.center_id == center.id))}
    vehicles = {v.id: v.name for v in db.scalars(select(VehicleType).where(VehicleType.center_id == center.id))}
    washers = {w.id: w for w in db.scalars(select(Washer).where(Washer.center_id == center.id))}

    # Fidélité : clients ayant au moins N visites sur la période de référence
    loyal_since = end - timedelta(days=center.loyal_period_days)
    visit_counts = db.execute(select(Wash.user_id, func.count(Wash.id)).where(
        Wash.center_id == center.id, Wash.user_id.is_not(None), Wash.created_at >= loyal_since,
        Wash.created_at < end).group_by(Wash.user_id)).all()
    active_clients = len(visit_counts)
    loyal_clients = sum(1 for _, c in visit_counts if c >= center.loyal_min_visits)
    returning = db.scalar(select(func.count(func.distinct(Wash.user_id))).where(
        Wash.center_id == center.id, Wash.user_id.in_(list(client_ids) or [-1]), Wash.created_at < start)) or 0

    new_clients = db.scalar(select(func.count(LoyaltyAccount.id)).where(
        LoyaltyAccount.center_id == center.id, LoyaltyAccount.created_at >= start,
        LoyaltyAccount.created_at < end)) or 0
    total_clients = db.scalar(select(func.count(LoyaltyAccount.id)).where(LoyaltyAccount.center_id == center.id)) or 0

    tx = db.execute(select(PointTransaction.type, func.sum(PointTransaction.points))
                    .join(LoyaltyAccount, LoyaltyAccount.id == PointTransaction.account_id)
                    .where(LoyaltyAccount.center_id == center.id, PointTransaction.created_at >= start,
                           PointTransaction.created_at < end).group_by(PointTransaction.type)).all()
    tx_map = {t: int(v or 0) for t, v in tx}
    points_issued = sum(v for t, v in tx_map.items() if v > 0 and t != TransactionType.refund)
    points_redeemed = -tx_map.get(TransactionType.redeem, 0) - tx_map.get(TransactionType.refund, 0)

    redemptions = db.execute(select(Redemption.status, func.count(Redemption.id)).where(
        Redemption.center_id == center.id, Redemption.created_at >= start, Redemption.created_at < end)
        .group_by(Redemption.status)).all()
    bookings = db.scalar(select(func.count(Booking.id)).where(
        Booking.center_id == center.id, Booking.start_at >= start, Booking.start_at < end)) or 0

    top_clients_rows = db.execute(select(User.id, User.first_name, User.last_name, func.count(Wash.id),
                                         func.sum(Wash.price))
                                  .join(Wash, Wash.user_id == User.id)
                                  .where(Wash.center_id == center.id, Wash.created_at >= start,
                                         Wash.created_at < end)
                                  .group_by(User.id, User.first_name, User.last_name)
                                  .order_by(func.count(Wash.id).desc()).limit(10)).all()

    days = max((end - start).days, 1)
    return {
        "period": {"from": start, "to": end, "days": days},
        "currency": center.currency,
        "kpis": {
            "washes": total,
            "revenue": revenue,
            "avg_ticket": round(revenue / total, 2) if total else 0,
            "washes_per_day": round(total / days, 2),
            "unique_clients": len(client_ids),
            "anonymous_washes": anonymous,
            "new_clients": new_clients,
            "total_clients": total_clients,
            "returning_clients": returning,
            "loyal_clients": loyal_clients,
            "loyalty_rate": round(loyal_clients / active_clients * 100, 1) if active_clients else 0,
            "points_issued": points_issued,
            "points_redeemed": points_redeemed,
            "redemptions": {s.value: c for s, c in redemptions},
            "bookings": bookings,
            "water_saved_liters": round(sum(w.water_saved_liters for w in washes), 1),
            "queue": center.current_queue,
        },
        "washes_per_day": list(per_day.values()),
        "hourly": [{"hour": h, "washes": c} for h, c in enumerate(hours)],
        "weekdays": [{"day": d, "washes": c} for d, c in enumerate(weekdays)],
        "services": sorted([{"id": k, "name": services.get(k, "?"), "count": v["count"],
                             "revenue": round(v["revenue"], 2),
                             "share": round(v["count"] / total * 100, 1) if total else 0}
                            for k, v in by_service.items()], key=lambda x: -x["count"]),
        "vehicle_types": sorted([{"id": k, "name": vehicles.get(k, "?"), "count": v}
                                 for k, v in by_vehicle.items()], key=lambda x: -x["count"]),
        "washers": sorted([{"id": k, "name": washers[k].full_name if k in washers else "Non attribué",
                            "count": v["count"], "revenue": round(v["revenue"], 2),
                            "commission": round(v["revenue"] * (washers[k].commission_rate if k in washers else 0)
                                                / 100, 2)}
                           for k, v in by_washer.items()], key=lambda x: -x["count"]),
        "top_clients": [{"id": r[0], "name": f"{r[1]} {r[2]}".strip(), "washes": r[3],
                         "spent": round(r[4] or 0, 2)} for r in top_clients_rows],
    }


__all__ = ["dashboard", "RedemptionStatus"]

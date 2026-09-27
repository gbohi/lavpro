"""Lots de points et expiration.

Chaque crédit de points (lavage, bienvenue, parrainage, bonus…) forme un « lot » avec ses points
restants (`remaining`) et, si le centre a fixé une durée de validité, une date d'expiration.
Les dépenses (récompense, paiement en points, ajustement) consomment d'abord les lots qui expirent
le plus tôt ; les lots consommés sont mémorisés sur le débit pour pouvoir être restitués en cas
d'annulation. Une tâche quotidienne fait expirer les lots échus et envoie les relances.
"""

import calendar
import math
from collections import defaultdict
from datetime import datetime, timedelta

from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.db import utcnow
from app.models import Center, LoyaltyAccount, PointTransaction, TransactionType
from app.services.notifications import notify


def add_months(dt: datetime, months: int) -> datetime:
    month = dt.month - 1 + months
    year = dt.year + month // 12
    month = month % 12 + 1
    day = min(dt.day, calendar.monthrange(year, month)[1])
    return dt.replace(year=year, month=month, day=day)


def lot_expiry(center: Center, earned_at: datetime | None = None) -> datetime | None:
    """Date d'expiration d'un lot gagné maintenant (None si le centre n'applique pas d'expiration)."""
    if not center.points_validity_months:
        return None
    return add_months(earned_at or utcnow(), center.points_validity_months)


def _open_lots(db: Session, account_id: int) -> list[PointTransaction]:
    # Les lots qui expirent le plus tôt d'abord ; ceux sans expiration en dernier, du plus ancien au plus récent.
    return list(db.scalars(
        select(PointTransaction)
        .where(PointTransaction.account_id == account_id, PointTransaction.remaining > 0)
        .order_by(PointTransaction.expires_at.asc().nulls_last(), PointTransaction.created_at, PointTransaction.id)
    ))


def consume(db: Session, account_id: int, points: int,
            prefer: PointTransaction | None = None) -> list[dict]:
    """Retire `points` des lots disponibles et renvoie le détail consommé."""
    db.flush()
    lots = _open_lots(db, account_id)
    if prefer is not None and prefer in lots:
        lots.remove(prefer)
        lots.insert(0, prefer)
    detail = []
    need = points
    for lot in lots:
        if need <= 0:
            break
        take = min(lot.remaining, need)
        lot.remaining -= take
        need -= take
        detail.append({"lot": lot.id, "points": take})
    return detail


def restore(db: Session, debit: PointTransaction) -> int:
    """Restitue aux lots d'origine les points consommés par un débit (annulation). Renvoie le total restitué."""
    total = 0
    for item in debit.consumed or []:
        lot = db.get(PointTransaction, item["lot"])
        if lot is not None:
            lot.remaining += item["points"]
            total += item["points"]
    debit.consumed = []
    return total


def on_validity_change(db: Session, center: Center, previous_months: int | None) -> None:
    """Applique un changement de durée de validité aux points déjà gagnés.

    - Activation : les points existants reçoivent une durée complète à partir d'aujourd'hui
      (aucun point n'expire du jour au lendemain).
    - Désactivation : plus aucun point n'expire.
    - Changement de durée : les dates déjà fixées sont conservées, la nouvelle durée vaut pour les prochains gains.
    """
    lots = select(PointTransaction).join(LoyaltyAccount).where(
        LoyaltyAccount.center_id == center.id, PointTransaction.remaining > 0)
    if not center.points_validity_months:
        for lot in db.scalars(lots):
            lot.expires_at = None
            lot.expiry_reminded = None
    elif not previous_months:
        expiry = lot_expiry(center)
        for lot in db.scalars(lots.where(PointTransaction.expires_at.is_(None))):
            lot.expires_at = expiry


def expiry_summary(db: Session, account_id: int) -> tuple[datetime | None, int]:
    """Prochaine date d'expiration et nombre de points concernés ce jour-là."""
    first = db.scalar(select(func.min(PointTransaction.expires_at)).where(
        PointTransaction.account_id == account_id, PointTransaction.remaining > 0,
        PointTransaction.expires_at.is_not(None)))
    if first is None:
        return None, 0
    day_end = first.replace(hour=23, minute=59, second=59)
    points = db.scalar(select(func.coalesce(func.sum(PointTransaction.remaining), 0)).where(
        PointTransaction.account_id == account_id, PointTransaction.remaining > 0,
        PointTransaction.expires_at <= day_end)) or 0
    return first, int(points)


def expire_points(db: Session, now: datetime | None = None) -> int:
    """Fait expirer les lots échus. Renvoie le nombre total de points expirés."""
    now = now or utcnow()
    lots = list(db.scalars(select(PointTransaction).where(
        PointTransaction.remaining > 0, PointTransaction.expires_at.is_not(None), PointTransaction.expires_at <= now)))
    by_account: dict[int, list[PointTransaction]] = defaultdict(list)
    for lot in lots:
        by_account[lot.account_id].append(lot)
    total = 0
    for account_id, account_lots in by_account.items():
        account = db.get(LoyaltyAccount, account_id)
        points = sum(lot.remaining for lot in account_lots)
        points = min(points, account.balance)
        detail = [{"lot": lot.id, "points": lot.remaining} for lot in account_lots]
        for lot in account_lots:
            lot.remaining = 0
        if points <= 0:
            continue
        account.balance -= points
        db.add(PointTransaction(account_id=account_id, type=TransactionType.expire, points=-points,
                                note="Points expirés", consumed=detail))
        total += points
        center = account.center
        notify(db, account.user, "Des points ont expiré",
               f"{points} point{'s' if points > 1 else ''} gagné{'s' if points > 1 else ''} chez {center.name} "
               f"ont expiré. Solde restant : {account.balance} pts.",
               type_="points_expired", center_id=center.id, data={"points": points, "balance": account.balance})
    db.commit()
    return total


def send_expiry_reminders(db: Session, now: datetime | None = None) -> int:
    """Relance les clients dont des points expirent bientôt (délais réglés par chaque centre, ex. J-30 et J-7).

    Une relance par client et par centre et par délai ; chaque lot n'est rappelé qu'une fois par délai.
    """
    now = now or utcnow()
    centers = {c.id: c for c in db.scalars(select(Center).where(Center.points_validity_months.is_not(None)))}
    if not centers:
        return 0
    horizon = now + timedelta(days=max((max(c.points_expiry_reminders or [0]) for c in centers.values()), default=0))
    rows = db.execute(
        select(PointTransaction, LoyaltyAccount).join(LoyaltyAccount)
        .where(LoyaltyAccount.center_id.in_(list(centers)), PointTransaction.remaining > 0,
               PointTransaction.expires_at.is_not(None), PointTransaction.expires_at > now,
               PointTransaction.expires_at <= horizon)
    ).all()
    due: dict[int, dict] = {}
    for lot, account in rows:
        delays = sorted(centers[account.center_id].points_expiry_reminders or [])
        days_left = (lot.expires_at - now).total_seconds() / 86400
        # Plus petit délai de relance atteint (ex. 7 si le lot expire dans 5 jours)
        step = next((d for d in delays if days_left <= d), None)
        if step is None or (lot.expiry_reminded is not None and lot.expiry_reminded <= step):
            continue
        lot.expiry_reminded = step
        entry = due.setdefault(account.id, {"account": account, "points": 0, "first": lot.expires_at})
        entry["points"] += lot.remaining
        entry["first"] = min(entry["first"], lot.expires_at)
    for entry in due.values():
        account, center = entry["account"], entry["account"].center
        date = entry["first"].strftime("%d/%m/%Y")
        days = max(0, math.ceil((entry["first"] - now).total_seconds() / 86400))
        notify(db, account.user, "Vos points vont expirer ⏳",
               f"{entry['points']} point{'s' if entry['points'] > 1 else ''} chez {center.name} expirent le {date} "
               f"(dans {days} jour{'s' if days > 1 else ''}). Profitez-en pour votre prochain lavage ou une récompense !",
               type_="points_expiry", center_id=center.id,
               data={"points": entry["points"], "expires_at": entry["first"].isoformat() + "Z"})
    db.commit()
    return len(due)

"""Rappels intelligents : fréquence de visite du client + météo au centre."""

from datetime import timedelta

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.db import utcnow
from app.models import Center, LoyaltyAccount, Notification, Reward, User, UserRole, Wash
from app.schemas.activity import Suggestion
from app.services.loyalty import active_promotions, promotion_applies
from app.services.notifications import notify
from app.services.platform_settings import get_setting
from app.services.weather import get_forecast, good_weather_window


def usual_interval_days(db: Session, user_id: int, center: Center) -> float:
    n = int(get_setting(db, "reminders.history_size", 6))
    dates = list(db.scalars(select(Wash.created_at).where(Wash.user_id == user_id, Wash.center_id == center.id)
                            .order_by(Wash.created_at.desc()).limit(max(n, 2))))
    if len(dates) < 2:
        return float(center.reminder_default_days)
    gaps = [(dates[i] - dates[i + 1]).total_seconds() / 86400 for i in range(len(dates) - 1)]
    gaps = [g for g in gaps if g >= 0.5] or [float(center.reminder_default_days)]
    return sum(gaps) / len(gaps)


def compute_suggestions(db: Session, user: User, include_offers: bool = True) -> list[Suggestion]:
    now = utcnow()
    factor = float(get_setting(db, "reminders.due_factor", 1.0))
    early = int(get_setting(db, "reminders.early_days", 2))
    out: list[Suggestion] = []
    accounts = list(db.scalars(select(LoyaltyAccount).where(LoyaltyAccount.user_id == user.id)))
    for acc in accounts:
        center = acc.center
        if not center.is_active:
            continue
        if center.reminder_enabled and acc.last_visit_at:
            interval = usual_interval_days(db, user.id, center) * factor
            since = (now - acc.last_visit_at).total_seconds() / 86400
            due_in = round(interval - since)
            forecast = None
            good = None
            if user.weather_reminders and center.lat is not None and center.lng is not None:
                forecast = get_forecast(db, center.lat, center.lng)
                good = good_weather_window(db, forecast)
            weather = forecast[0] if forecast else None
            if due_in <= 0 and good is False:
                out.append(Suggestion(center_id=center.id, center_name=center.name, kind="weather_wait",
                                      title="Pluie en vue 🌧️",
                                      message=f"Il est temps de laver votre véhicule, mais de la pluie est prévue. "
                                              f"Nous vous préviendrons dès le retour du beau temps pour passer chez "
                                              f"{center.name}.", due_in_days=due_in, weather=weather))
            elif due_in <= 0:
                out.append(Suggestion(center_id=center.id, center_name=center.name, kind="reminder",
                                      title="C'est le moment de briller ✨",
                                      message=f"Cela fait {int(since)} jours depuis votre dernier lavage chez "
                                              f"{center.name}" + (" et le beau temps est annoncé." if good else "."),
                                      due_in_days=due_in, weather=weather))
            elif due_in <= early and good:
                out.append(Suggestion(center_id=center.id, center_name=center.name, kind="weather",
                                      title="Beau temps annoncé ☀️",
                                      message=f"Le soleil est prévu ces prochains jours : idéal pour votre lavage "
                                              f"chez {center.name}.", due_in_days=due_in, weather=weather))
        if not include_offers:
            continue
        for promo in active_promotions(db, center.id):
            if promotion_applies(db, promo, user, center, acc):
                out.append(Suggestion(center_id=center.id, center_name=center.name, kind="promotion",
                                      title=promo.name, message=promo.description or
                                      f"Offre spéciale en cours chez {center.name}"))
        reward = db.scalar(select(Reward).where(Reward.center_id == center.id, Reward.is_active.is_(True),
                                                Reward.points_cost <= acc.balance)
                           .order_by(Reward.points_cost.desc()))
        if reward:
            out.append(Suggestion(center_id=center.id, center_name=center.name, kind="reward",
                                  title="Récompense disponible 🎁",
                                  message=f"Vous avez assez de points pour « {reward.name} » chez {center.name}."))
    return out


def run_reminders(db: Session) -> int:
    """À exécuter périodiquement (cron) : crée les notifications de rappel."""
    min_gap = timedelta(days=int(get_setting(db, "reminders.min_days_between", 3)))
    sent = 0
    users = db.scalars(select(User).where(User.role == UserRole.client, User.is_active.is_(True),
                                          User.notifications_enabled.is_(True)))
    for user in users:
        for s in compute_suggestions(db, user, include_offers=False):
            if s.kind not in ("reminder", "weather"):
                continue
            recent = db.scalar(select(Notification.id).where(
                Notification.user_id == user.id, Notification.center_id == s.center_id,
                Notification.type == "reminder", Notification.created_at >= utcnow() - min_gap))
            if recent:
                continue
            notify(db, user, s.title, s.message, type_="reminder", center_id=s.center_id)
            sent += 1
    db.commit()
    return sent

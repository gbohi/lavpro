import logging

import httpx
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.config import get_settings
from app.models import DeviceToken, Notification, User

log = logging.getLogger("lavpro.notifications")


def _push(tokens: list[str], title: str, body: str, data: dict | None) -> None:
    key = get_settings().fcm_server_key
    if not key or not tokens:
        return
    try:
        httpx.post(
            "https://fcm.googleapis.com/fcm/send",
            headers={"Authorization": f"key={key}", "Content-Type": "application/json"},
            json={"registration_ids": tokens, "notification": {"title": title, "body": body},
                  "data": {k: str(v) for k, v in (data or {}).items()}},
            timeout=5,
        )
    except httpx.HTTPError as exc:  # pragma: no cover - dépend du réseau
        log.warning("Échec de l'envoi push: %s", exc)


def notify(db: Session, user: User, title: str, body: str, *, type_: str = "info", center_id: int | None = None,
           data: dict | None = None, push: bool = True) -> Notification:
    notif = Notification(user_id=user.id, center_id=center_id, type=type_, title=title, body=body, data=data)
    db.add(notif)
    if push and user.notifications_enabled:
        tokens = list(db.scalars(select(DeviceToken.token).where(DeviceToken.user_id == user.id)))
        _push(tokens, title, body, data)
    return notif

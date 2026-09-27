"""Expiration des points par lot et relances."""

from datetime import datetime, timedelta

from sqlalchemy import select

from app.db import SessionLocal
from app.models import LoyaltyAccount, Notification, PointTransaction, User
from app.services.points import expire_points, send_expiry_reminders
from tests.conftest import API, auth


def _client(client, center, email):
    user = client.post(f"{API}/auth/register", json={"email": email, "password": "secret1", "first_name": "Zoé"}).json()
    return user, auth(user["access_token"])


def _wash(client, center, user, service=0):
    s, v = center["services"][service], center["vehicles"][0]
    r = client.post(f"{API}/manage/centers/{center['id']}/washes", headers=center["h"], json={
        "client_code": user["user"]["member_code"], "service_type_id": s["id"], "vehicle_type_id": v["id"]})
    assert r.status_code == 201, r.text
    return r.json()


def _lots(user_id):
    with SessionLocal() as db:
        return [(t.id, t.type.value, t.points, t.remaining, t.expires_at) for t in db.scalars(
            select(PointTransaction).join(LoyaltyAccount).where(LoyaltyAccount.user_id == user_id)
            .order_by(PointTransaction.id))]


def _set_expiry(tx_id, when):
    with SessionLocal() as db:
        db.get(PointTransaction, tx_id).expires_at = when
        db.commit()


def _account(client, h):
    return client.get(f"{API}/me/accounts", headers=h).json()[0]


def test_no_expiration_by_default(client, center):
    user, h = _client(client, center, "noexp@x.io")
    _wash(client, center, user)
    lots = _lots(user["user"]["id"])
    assert all(exp is None for *_, exp in lots)
    assert sum(rem for _, _, _, rem, _ in lots) == _account(client, h)["balance"] == 15
    acc = _account(client, h)
    assert acc["next_expiry_at"] is None and acc["points_validity_months"] is None


def test_enable_validity_then_expire_oldest_first(client, center):
    cid, h_owner = center["id"], center["h"]
    user, h = _client(client, center, "exp@x.io")
    _wash(client, center, user)                           # bienvenue 5 + lavage 10 (lots sans expiration)
    r = client.patch(f"{API}/manage/centers/{cid}", headers=h_owner,
                     json={"points_validity_months": 12, "points_expiry_reminders": [7, 30, 30, 500]})
    assert r.status_code == 200 and r.json()["points_expiry_reminders"] == [30, 7]
    lots = _lots(user["user"]["id"])
    # À l'activation, les points existants reçoivent une validité complète à partir d'aujourd'hui
    assert all(exp is not None and exp > datetime.utcnow() + timedelta(days=360) for *_, exp in lots)
    _wash(client, center, user, service=1)                # nouveau lot de 20 points, expire dans 12 mois
    welcome, earn1, earn2 = _lots(user["user"]["id"])
    assert earn2[4] > datetime.utcnow() + timedelta(days=360)

    # Le lot de bienvenue expire demain, le 1er lavage dans 10 jours
    _set_expiry(welcome[0], datetime.utcnow() + timedelta(days=1))
    _set_expiry(earn1[0], datetime.utcnow() + timedelta(days=10))
    acc = _account(client, h)
    assert acc["next_expiry_points"] == 5 and acc["next_expiry_at"]

    # Une dépense consomme d'abord les points qui expirent le plus tôt (5 + 3 sur le lot suivant)
    reward = client.post(f"{API}/manage/centers/{cid}/rewards", headers=h_owner,
                         json={"name": "Senteur", "points_cost": 8}).json()
    red = client.post(f"{API}/me/redemptions", headers=h, json={"reward_id": reward["id"]}).json()
    remaining = {tx_id: rem for tx_id, _, _, rem, _ in _lots(user["user"]["id"])}
    assert remaining[welcome[0]] == 0 and remaining[earn1[0]] == 7 and remaining[earn2[0]] == 20
    # L'annulation restitue les points dans leurs lots d'origine (mêmes dates d'expiration)
    client.post(f"{API}/me/redemptions/{red['id']}/cancel", headers=h)
    remaining = {tx_id: rem for tx_id, _, _, rem, _ in _lots(user["user"]["id"])}
    assert remaining[welcome[0]] == 5 and remaining[earn1[0]] == 10

    # Expiration : seul le lot échu disparaît
    _set_expiry(welcome[0], datetime.utcnow() - timedelta(minutes=1))
    with SessionLocal() as db:
        assert expire_points(db) == 5
        assert expire_points(db) == 0
    assert _account(client, h)["balance"] == 30
    tx = client.get(f"{API}/me/transactions", headers=h).json()
    assert tx[0]["type"] == "expire" and tx[0]["points"] == -5
    notifs = client.get(f"{API}/me/notifications", headers=h).json()
    assert any(n["type"] == "points_expired" for n in notifs)
    stats = client.get(f"{API}/manage/centers/{cid}/stats/dashboard", headers=h_owner).json()
    assert stats["kpis"]["points_expired"] == 5

    # Désactivation : plus rien n'expire
    client.patch(f"{API}/manage/centers/{cid}", headers=h_owner, json={"points_validity_months": None})
    assert all(exp is None for _, _, _, rem, exp in _lots(user["user"]["id"]) if rem)


def test_expiry_reminders_j30_and_j7(client, center):
    cid, h_owner = center["id"], center["h"]
    client.patch(f"{API}/manage/centers/{cid}", headers=h_owner, json={"points_validity_months": 6})
    user, h = _client(client, center, "remind-exp@x.io")
    _wash(client, center, user)
    welcome, earn = _lots(user["user"]["id"])
    _set_expiry(welcome[0], datetime.utcnow() + timedelta(days=20))
    _set_expiry(earn[0], datetime.utcnow() + timedelta(days=20))

    def expiry_notifs():
        with SessionLocal() as db:
            uid = db.scalar(select(User.id).where(User.email == "remind-exp@x.io"))
            return list(db.scalars(select(Notification).where(Notification.user_id == uid,
                                                              Notification.type == "points_expiry")))

    with SessionLocal() as db:
        assert send_expiry_reminders(db) == 1          # J-30 : une seule relance pour les 2 lots
        assert send_expiry_reminders(db) == 0          # pas de doublon
    notifs = expiry_notifs()
    assert len(notifs) == 1 and "15 points" in notifs[0].body
    _set_expiry(earn[0], datetime.utcnow() + timedelta(days=5))
    with SessionLocal() as db:
        assert send_expiry_reminders(db) == 1          # J-7 pour le lot qui approche
        assert send_expiry_reminders(db) == 0
    assert len(expiry_notifs()) == 2 and "10 points" in expiry_notifs()[-1].body


def test_cancel_wash_refunds_points_and_reward(client, center):
    cid, h_owner = center["id"], center["h"]
    s0, v0 = center["services"][0], center["vehicles"][0]
    user, h = _client(client, center, "cancel@x.io")
    client.post(f"{API}/manage/centers/{cid}/points/adjust", headers=h_owner,
                json={"user_id": user["user"]["id"], "points": 100, "note": "Test"})
    client.patch(f"{API}/manage/centers/{cid}", headers=h_owner, json={"points_payment_enabled": True})
    client.put(f"{API}/manage/centers/{cid}/pricing", headers=h_owner, json={"rules": [
        {"service_type_id": s0["id"], "vehicle_type_id": v0["id"], "price": 1000, "points": 10, "points_price": 40}]})
    w = client.post(f"{API}/manage/centers/{cid}/washes", headers=h_owner, json={
        "client_code": user["user"]["member_code"], "service_type_id": s0["id"], "vehicle_type_id": v0["id"],
        "payment_method": "points"}).json()
    assert _account(client, h)["balance"] == 65
    assert client.delete(f"{API}/manage/centers/{cid}/washes/{w['id']}", headers=h_owner).status_code == 204
    assert _account(client, h)["balance"] == 105        # points dépensés remboursés

    reward = client.post(f"{API}/manage/centers/{cid}/rewards", headers=h_owner, json={
        "name": "Lavage offert", "points_cost": 30, "service_type_id": s0["id"]}).json()
    red = client.post(f"{API}/me/redemptions", headers=h, json={"reward_id": reward["id"]}).json()
    w = client.post(f"{API}/manage/centers/{cid}/washes", headers=h_owner, json={
        "client_code": user["user"]["member_code"], "service_type_id": s0["id"], "vehicle_type_id": v0["id"],
        "payment_method": "reward", "redemption_id": red["id"]}).json()
    client.delete(f"{API}/manage/centers/{cid}/washes/{w['id']}", headers=h_owner)
    reds = client.get(f"{API}/me/redemptions", headers=h).json()
    assert reds[0]["status"] == "pending" and reds[0]["wash_id"] is None   # récompense à nouveau utilisable

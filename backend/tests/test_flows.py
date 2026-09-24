from datetime import date, timedelta

from tests.conftest import API, auth


def register(client, email, referral_code=None):
    r = client.post(f"{API}/auth/register", json={"email": email, "password": "secret1", "first_name": "Jean",
                                                  "referral_code": referral_code})
    assert r.status_code == 201, r.text
    return r.json()


def test_health(client):
    assert client.get("/health").json() == {"status": "ok"}


def test_center_registration_seeds_configurable_catalog(client, center):
    assert len(center["services"]) >= 1 and len(center["vehicles"]) >= 1
    me = client.get(f"{API}/auth/me", headers=center["h"]).json()
    assert me["role"] == "staff" and me["memberships"][0]["role"] == "owner"


def test_wash_points_referral_and_redeem(client, center):
    cid, h = center["id"], center["h"]
    sponsor = register(client, "sponsor@x.io")
    friend = register(client, "friend@x.io", sponsor["user"]["referral_code"])
    s, v = center["services"][1], center["vehicles"][0]

    lookup = client.get(f"{API}/manage/centers/{cid}/clients/lookup",
                        params={"code": friend["user"]["qr_payload"]}, headers=h)
    assert lookup.status_code == 200 and lookup.json()["first_name"] == "Jean"

    r = client.post(f"{API}/manage/centers/{cid}/washes", headers=h, json={
        "client_code": friend["user"]["member_code"], "service_type_id": s["id"], "vehicle_type_id": v["id"],
        "washer_id": center["washer"]["id"]})
    assert r.status_code == 201, r.text
    wash = r.json()
    assert wash["points_earned"] == 20 and wash["washer_name"] == "Koffi"

    fh = auth(friend["access_token"])
    acc = client.get(f"{API}/me/accounts", headers=fh).json()[0]
    # 5 bienvenue + 20 lavage + 10 bonus filleul
    assert acc["balance"] == 35 and acc["visits"] == 1
    sponsor_acc = client.get(f"{API}/me/accounts", headers=auth(sponsor["access_token"])).json()[0]
    assert sponsor_acc["balance"] == 5 + 20

    rewards = client.get(f"{API}/centers/{cid}/rewards", headers=fh).json()
    assert rewards[0]["affordable"] is True
    red = client.post(f"{API}/me/redemptions", headers=fh, json={"reward_id": center["reward"]["id"]})
    assert red.status_code == 201, red.text
    code = red.json()["code"]
    assert client.get(f"{API}/me/accounts", headers=fh).json()[0]["balance"] == 5

    ok = client.post(f"{API}/manage/centers/{cid}/redemptions/{code}/validate", headers=h)
    assert ok.status_code == 200 and ok.json()["status"] == "used"
    again = client.post(f"{API}/me/redemptions", headers=fh, json={"reward_id": center["reward"]["id"]})
    assert again.status_code == 400

    stats = client.get(f"{API}/manage/centers/{cid}/stats/dashboard", headers=h).json()
    assert stats["kpis"]["washes"] == 1 and stats["washers"][0]["name"] == "Koffi"
    assert stats["services"][0]["name"] == s["name"]
    report = client.get(f"{API}/manage/centers/{cid}/stats/washers", headers=h).json()
    assert report["washers"][0]["count"] == 1
    csv = client.get(f"{API}/manage/centers/{cid}/washes/export", headers=h)
    assert csv.status_code == 200 and "Koffi" in csv.text

    notifs = client.get(f"{API}/me/notifications", headers=auth(sponsor["access_token"])).json()
    assert any(n["type"] == "referral" for n in notifs)
    ref = client.get(f"{API}/me/referral", headers=auth(sponsor["access_token"])).json()
    assert ref["invited_count"] == 1 and ref["rewarded_count"] == 1
    eco = client.get(f"{API}/me/eco", headers=fh).json()
    assert eco["total_washes"] == 1


def test_promotion_multiplier(client, center):
    cid, h = center["id"], center["h"]
    user = register(client, "promo@x.io")
    today = date.today()
    r = client.post(f"{API}/manage/centers/{cid}/promotions", headers=h, json={
        "name": "Double points", "points_multiplier": 2, "starts_at": f"{today - timedelta(days=1)}T00:00:00Z",
        "ends_at": f"{today + timedelta(days=2)}T00:00:00Z"})
    assert r.status_code == 201, r.text
    s, v = center["services"][0], center["vehicles"][0]
    wash = client.post(f"{API}/manage/centers/{cid}/washes", headers=h, json={
        "client_code": user["user"]["member_code"], "service_type_id": s["id"], "vehicle_type_id": v["id"]}).json()
    assert wash["points_earned"] == 20


def test_booking_slots_and_capacity(client, center):
    cid = center["id"]
    user = register(client, "book@x.io")
    other = register(client, "book2@x.io")
    day = date.today() + timedelta(days=1)
    s, v = center["services"][0], center["vehicles"][0]
    slots = client.get(f"{API}/centers/{cid}/slots", params={"day": day.isoformat(), "service_type_id": s["id"]}).json()
    assert slots and slots[0]["available"] == 1
    # Les créneaux sont exposés en UTC explicite (sinon décalés sur les téléphones hors UTC)
    assert slots[0]["start_at"].endswith(("Z", "+00:00"))
    body = {"center_id": cid, "service_type_id": s["id"], "vehicle_type_id": v["id"], "start_at": slots[0]["start_at"]}
    r = client.post(f"{API}/me/bookings", headers=auth(user["access_token"]), json=body)
    assert r.status_code == 201, r.text
    full = client.post(f"{API}/me/bookings", headers=auth(other["access_token"]), json=body)
    assert full.status_code == 409
    listed = client.get(f"{API}/manage/centers/{cid}/bookings", params={"day": day.isoformat()},
                        headers=center["h"]).json()
    assert len(listed) == 1


def test_public_center_search_and_occupancy(client, center):
    cid, h = center["id"], center["h"]
    client.post(f"{API}/manage/centers/{cid}/queue", headers=h, json={"value": 3})
    centers = client.get(f"{API}/centers", params={"lat": 5.36, "lng": -4.01}).json()
    assert centers[0]["id"] == cid and centers[0]["distance_km"] < 5
    assert centers[0]["occupancy"]["level"] == "high"
    cat = client.get(f"{API}/centers/{cid}/catalog").json()
    assert cat["pricing"]


def test_permissions(client, center):
    user = register(client, "intruder@x.io")
    r = client.get(f"{API}/manage/centers/{center['id']}", headers=auth(user["access_token"]))
    assert r.status_code == 403
    assert client.get(f"{API}/admin/settings", headers=auth(user["access_token"])).status_code == 403


def test_team_member_can_validate(client, center):
    cid, h = center["id"], center["h"]
    r = client.post(f"{API}/manage/centers/{cid}/members", headers=h, json={
        "email": "colleague@clean.io", "first_name": "Marc", "password": "secret1"})
    assert r.status_code == 201, r.text
    tok = client.post(f"{API}/auth/login", json={"email": "colleague@clean.io", "password": "secret1"}).json()
    ch = auth(tok["access_token"])
    s, v = center["services"][0], center["vehicles"][0]
    ok = client.post(f"{API}/manage/centers/{cid}/washes", headers=ch,
                     json={"service_type_id": s["id"], "vehicle_type_id": v["id"]})
    assert ok.status_code == 201 and ok.json()["validated_by_name"] == "Marc"
    # un gestionnaire ne peut pas gérer l'équipe
    assert client.post(f"{API}/manage/centers/{cid}/members", headers=ch, json={
        "email": "x@clean.io", "first_name": "X", "password": "secret1"}).status_code == 403


def test_admin_settings(client):
    tok = client.post(f"{API}/auth/login", json={"email": "admin@test.io", "password": "admin123"}).json()
    h = auth(tok["access_token"])
    settings = client.get(f"{API}/admin/settings", headers=h).json()
    assert any(s["key"] == "eco.levels" for s in settings)
    r = client.put(f"{API}/admin/settings/reminders.min_days_between", headers=h, json={"value": 7})
    assert r.json()["value"] == 7
    assert client.post(f"{API}/admin/jobs/reminders", headers=h).status_code == 200


def test_reminder_suggestion(client, center):
    from datetime import datetime

    from app.db import SessionLocal
    from app.models import LoyaltyAccount, Wash

    cid, h = center["id"], center["h"]
    user = register(client, "remind@x.io")
    s, v = center["services"][0], center["vehicles"][0]
    client.post(f"{API}/manage/centers/{cid}/washes", headers=h, json={
        "client_code": user["user"]["member_code"], "service_type_id": s["id"], "vehicle_type_id": v["id"]})
    with SessionLocal() as db:
        old = datetime.utcnow() - timedelta(days=30)
        for w in db.query(Wash).all():
            w.created_at = old
        for a in db.query(LoyaltyAccount).all():
            a.last_visit_at = old
        db.commit()
    sugg = client.get(f"{API}/me/suggestions", headers=auth(user["access_token"])).json()
    assert any(s["kind"] == "reminder" for s in sugg)

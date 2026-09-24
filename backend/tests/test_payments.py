"""Lavage offert (récompense liée à un service) et paiement direct en points."""

from tests.conftest import API, auth


def _client(client, center, email, points=100):
    r = client.post(f"{API}/auth/register", json={"email": email, "password": "secret1", "first_name": "Léa"})
    user = r.json()
    client.post(f"{API}/manage/centers/{center['id']}/points/adjust", headers=center["h"],
                json={"user_id": user["user"]["id"], "points": points, "note": "Test"})
    return user


def _balance(client, user):
    return client.get(f"{API}/me/accounts", headers=auth(user["access_token"])).json()[0]["balance"]


def test_wash_reward_linked_to_service_and_vehicle(client, center):
    cid, h = center["id"], center["h"]
    s0, s1 = center["services"][0], center["services"][1]
    v0, v1 = center["vehicles"][0], center["vehicles"][1]
    r = client.post(f"{API}/manage/centers/{cid}/rewards", headers=h, json={
        "name": "Lavage simple offert", "category": "wash", "points_cost": 999, "service_type_id": s0["id"],
        "vehicle_costs": [{"vehicle_type_id": v0["id"], "points_cost": 30},
                          {"vehicle_type_id": v1["id"], "points_cost": 50}]})
    assert r.status_code == 201, r.text
    reward = r.json()
    assert reward["is_wash"] and reward["min_cost"] == 30 and reward["points_cost"] == 30
    assert {c["vehicle_type_name"] for c in reward["vehicle_costs"]} == {v0["name"], v1["name"]}

    user = _client(client, center, "reward@x.io")          # 5 (bienvenue) + 100
    uh = auth(user["access_token"])
    listed = next(x for x in client.get(f"{API}/centers/{cid}/rewards", headers=uh).json() if x["id"] == reward["id"])
    assert listed["affordable"] and listed["service_name"] == s0["name"]

    assert client.post(f"{API}/me/redemptions", headers=uh, json={"reward_id": reward["id"]}).status_code == 400
    v2 = center["vehicles"][2]
    assert client.post(f"{API}/me/redemptions", headers=uh,
                       json={"reward_id": reward["id"], "vehicle_type_id": v2["id"]}).status_code == 400
    red = client.post(f"{API}/me/redemptions", headers=uh, json={"reward_id": reward["id"], "vehicle_type_id": v1["id"]})
    assert red.status_code == 201, red.text
    red = red.json()
    assert red["points"] == 50 and red["is_wash"] and red["vehicle_type_id"] == v1["id"]
    assert _balance(client, user) == 55

    # Un lavage offert ne se « remet » pas sans enregistrer le lavage
    assert client.post(f"{API}/manage/centers/{cid}/redemptions/{red['code']}/validate", headers=h).status_code == 409

    base = {"client_code": user["user"]["member_code"], "payment_method": "reward", "redemption_id": red["id"],
            "washer_id": center["washer"]["id"]}
    wrong_service = client.post(f"{API}/manage/centers/{cid}/washes", headers=h,
                                json={**base, "service_type_id": s1["id"], "vehicle_type_id": v1["id"]})
    assert wrong_service.status_code == 400
    wrong_vehicle = client.post(f"{API}/manage/centers/{cid}/washes", headers=h,
                                json={**base, "service_type_id": s0["id"], "vehicle_type_id": v0["id"]})
    assert wrong_vehicle.status_code == 400

    w = client.post(f"{API}/manage/centers/{cid}/washes", headers=h,
                    json={**base, "service_type_id": s0["id"], "vehicle_type_id": v1["id"]})
    assert w.status_code == 201, w.text
    w = w.json()
    assert w["payment_method"] == "reward" and w["price"] == 0 and w["discount"] == 1000
    assert w["points_earned"] == 0 and w["washer_name"] == "Koffi"
    assert _balance(client, user) == 55  # aucun point regagné

    reds = client.get(f"{API}/me/redemptions", headers=uh).json()
    assert reds[0]["status"] == "used" and reds[0]["wash_id"] == w["id"]
    again = client.post(f"{API}/manage/centers/{cid}/washes", headers=h,
                        json={**base, "service_type_id": s0["id"], "vehicle_type_id": v1["id"]})
    assert again.status_code == 400

    stats = client.get(f"{API}/manage/centers/{cid}/stats/dashboard", headers=h).json()
    assert stats["kpis"]["reward_washes"] == 1 and stats["kpis"]["offered_value"] == 1000
    assert stats["kpis"]["revenue"] == 0
    assert stats["washers"][0]["offered_value"] == 1000


def test_points_payment_at_counter(client, center):
    cid, h = center["id"], center["h"]
    s0, v0 = center["services"][0], center["vehicles"][0]
    user = _client(client, center, "points@x.io")          # 105 points
    body = {"client_code": user["user"]["member_code"], "service_type_id": s0["id"], "vehicle_type_id": v0["id"],
            "payment_method": "points"}

    # Désactivé par défaut
    assert client.post(f"{API}/manage/centers/{cid}/washes", headers=h, json=body).status_code == 400
    client.patch(f"{API}/manage/centers/{cid}", headers=h, json={"points_payment_enabled": True})
    # Pas de prix en points dans la grille
    assert client.post(f"{API}/manage/centers/{cid}/washes", headers=h, json=body).status_code == 400

    rule = {"service_type_id": s0["id"], "vehicle_type_id": v0["id"], "price": 1000, "points": 10}
    client.put(f"{API}/manage/centers/{cid}/pricing", headers=h, json={"rules": [{**rule, "points_price": 40}]})
    cat = client.get(f"{API}/centers/{cid}/catalog").json()
    assert any(p["points_price"] == 40 for p in cat["pricing"])
    assert client.get(f"{API}/centers/{cid}").json()["points_payment_enabled"] is True

    w = client.post(f"{API}/manage/centers/{cid}/washes", headers=h, json=body)
    assert w.status_code == 201, w.text
    w = w.json()
    assert w["payment_method"] == "points" and w["points_spent"] == 40 and w["price"] == 0 and w["points_earned"] == 0
    assert _balance(client, user) == 65
    tx = client.get(f"{API}/me/transactions", headers=auth(user["access_token"])).json()
    assert tx[0]["type"] == "wash_payment" and tx[0]["points"] == -40

    client.put(f"{API}/manage/centers/{cid}/pricing", headers=h, json={"rules": [{**rule, "points_price": 1000}]})
    short = client.post(f"{API}/manage/centers/{cid}/washes", headers=h, json=body)
    assert short.status_code == 400 and "insuffisant" in short.json()["detail"]
    walk_in = client.post(f"{API}/manage/centers/{cid}/washes", headers=h, json={**body, "client_code": None})
    assert walk_in.status_code == 400

    stats = client.get(f"{API}/manage/centers/{cid}/stats/dashboard", headers=h).json()
    assert stats["kpis"]["points_washes"] == 1 and stats["kpis"]["points_spent_on_washes"] == 40
    assert stats["kpis"]["points_redeemed"] == 40
    csv = client.get(f"{API}/manage/centers/{cid}/washes/export", headers=h).text
    assert "Payé en points" in csv

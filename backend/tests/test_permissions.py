"""Droits réglables des gestionnaires."""

from tests.conftest import API, auth


def _member(client, center, email, **extra):
    r = client.post(f"{API}/manage/centers/{center['id']}/members", headers=center["h"],
                    json={"email": email, "first_name": "Paul", "password": "secret1", **extra})
    assert r.status_code == 201, r.text
    tok = client.post(f"{API}/auth/login", json={"email": email, "password": "secret1"}).json()
    return r.json(), auth(tok["access_token"]), tok["user"]


def test_default_permissions_and_catalog(client, center):
    m, h, user = _member(client, center, "m1@clean.io")
    assert "manage_washers" in m["permissions"] and "manage_team" not in m["permissions"]
    assert "cancel_washes" not in m["permissions"]
    assert user["memberships"][0]["permissions"] == m["permissions"]
    owner = client.get(f"{API}/auth/me", headers=center["h"]).json()
    assert "manage_team" in owner["memberships"][0]["permissions"]
    cat = client.get(f"{API}/manage/centers/{center['id']}/permissions", headers=h).json()
    assert len(cat["permissions"]) == 8 and cat["is_owner"] is False


def test_restricted_manager_is_blocked_but_can_validate(client, center):
    cid = center["id"]
    _, h, _ = _member(client, center, "m2@clean.io", permissions=[])
    s, v = center["services"][0], center["vehicles"][0]
    base = f"{API}/manage/centers/{cid}"
    assert client.get(f"{base}/stats/dashboard", headers=h).status_code == 403
    assert client.get(f"{base}/washes/export", headers=h).status_code == 403
    assert client.post(f"{base}/washers", headers=h, json={"first_name": "X"}).status_code == 403
    assert client.put(f"{base}/pricing", headers=h, json={"rules": []}).status_code == 403
    assert client.patch(base, headers=h, json={"name": "Hack"}).status_code == 403
    assert client.post(f"{base}/rewards", headers=h, json={"name": "R", "points_cost": 5}).status_code == 403
    # Les actions courantes restent ouvertes
    assert client.get(f"{base}/washers", headers=h).status_code == 200
    w = client.post(f"{base}/washes", headers=h, json={"service_type_id": s["id"], "vehicle_type_id": v["id"]})
    assert w.status_code == 201
    assert client.delete(f"{base}/washes/{w.json()['id']}", headers=h).status_code == 403
    assert client.post(f"{base}/queue", headers=h, json={"delta": 1}).status_code == 200
    denied = client.get(f"{base}/stats/dashboard", headers=h).json()["detail"]
    assert "chiffre d'affaires" in denied


def test_team_manager_cannot_escalate(client, center):
    cid = center["id"]
    lead, h, _ = _member(client, center, "lead@clean.io", permissions=["manage_team", "manage_washers"])
    base = f"{API}/manage/centers/{cid}"
    ok = client.post(f"{base}/members", headers=h, json={
        "email": "new@clean.io", "first_name": "N", "password": "secret1", "permissions": ["manage_washers"]})
    assert ok.status_code == 201, ok.text
    # Sans liste explicite : défauts plateforme limités à ses propres droits
    dflt = client.post(f"{base}/members", headers=h, json={"email": "d@clean.io", "first_name": "D", "password": "secret1"})
    assert dflt.json()["permissions"] == ["manage_washers"]
    too_much = client.post(f"{base}/members", headers=h, json={
        "email": "x@clean.io", "first_name": "X", "password": "secret1", "permissions": ["cancel_washes"]})
    assert too_much.status_code == 403 and "Annuler un lavage" in too_much.json()["detail"]
    owner = client.post(f"{base}/members", headers=h, json={
        "email": "o@clean.io", "first_name": "O", "password": "secret1", "role": "owner", "permissions": []})
    assert owner.status_code == 403
    members = client.get(f"{base}/members", headers=h).json()
    owner_member = next(m for m in members if m["role"] == "owner")
    assert client.patch(f"{base}/members/{owner_member['id']}", headers=h, json={"is_active": False}).status_code == 403
    assert client.delete(f"{base}/members/{owner_member['id']}", headers=h).status_code == 403
    new_id = ok.json()["id"]
    assert client.patch(f"{base}/members/{new_id}", headers=h, json={"permissions": ["view_reports"]}).status_code == 403
    # Le propriétaire, lui, peut tout accorder
    r = client.patch(f"{base}/members/{new_id}", headers=center["h"], json={"permissions": ["view_reports", "cancel_washes"]})
    assert r.status_code == 200 and r.json()["permissions"] == ["view_reports", "cancel_washes"]
    assert lead["permissions"] == ["manage_team", "manage_washers"]

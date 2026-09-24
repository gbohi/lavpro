import os
import tempfile

_tmp = tempfile.mkdtemp()
os.environ["LAVPRO_DATABASE_URL"] = f"sqlite:///{_tmp}/test.db"
os.environ["LAVPRO_UPLOAD_DIR"] = f"{_tmp}/uploads"
os.environ["LAVPRO_SUPERADMIN_EMAIL"] = "admin@test.io"
os.environ["LAVPRO_SUPERADMIN_PASSWORD"] = "admin123"

import pytest  # noqa: E402
from fastapi.testclient import TestClient  # noqa: E402

from app.db import Base, engine  # noqa: E402
from app.main import app  # noqa: E402

API = "/api/v1"


@pytest.fixture()
def client(monkeypatch):
    # Pas d'appel réseau météo pendant les tests
    monkeypatch.setattr("app.services.suggestions.get_forecast", lambda db, lat, lng: None)
    Base.metadata.drop_all(bind=engine)
    with TestClient(app) as c:
        yield c


def auth(token: str) -> dict:
    return {"Authorization": f"Bearer {token}"}


@pytest.fixture()
def center(client):
    """Centre ouvert 7j/7 avec grille tarifaire, laveur et récompense."""
    r = client.post(f"{API}/auth/register-center", json={
        "center_name": "Clean Plus", "city": "Abidjan", "lat": 5.35, "lng": -4.0,
        "owner_email": "owner@clean.io", "owner_password": "secret1", "owner_first_name": "Awa"})
    assert r.status_code == 201, r.text
    data = r.json()
    token = data["access_token"]
    cid = data["user"]["memberships"][0]["center_id"]
    h = auth(token)
    hours = [{"day": d, "open": "00:00", "close": "23:59", "closed": False} for d in range(7)]
    client.patch(f"{API}/manage/centers/{cid}", headers=h, json={
        "opening_hours": hours, "welcome_points": 5, "referral_referrer_points": 20, "referral_referee_points": 10,
        "booking_min_notice_minutes": 0, "capacity": 1})
    services = client.get(f"{API}/manage/centers/{cid}/services", headers=h).json()
    vehicles = client.get(f"{API}/manage/centers/{cid}/vehicle-types", headers=h).json()
    rules = [{"service_type_id": s["id"], "vehicle_type_id": v["id"], "price": 1000 * (i + 1), "points": 10 * (i + 1)}
             for i, s in enumerate(services) for v in vehicles]
    r = client.put(f"{API}/manage/centers/{cid}/pricing", headers=h, json={"rules": rules})
    assert r.status_code == 200, r.text
    washer = client.post(f"{API}/manage/centers/{cid}/washers", headers=h, json={"first_name": "Koffi"}).json()
    reward = client.post(f"{API}/manage/centers/{cid}/rewards", headers=h,
                         json={"name": "Lavage offert", "points_cost": 30, "stock": 5}).json()
    return {"id": cid, "h": h, "services": services, "vehicles": vehicles, "washer": washer, "reward": reward}

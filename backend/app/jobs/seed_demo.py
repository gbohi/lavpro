"""Jeu de données de démonstration : `python -m app.jobs.seed_demo`.

Crée un centre "Lavpro Démo", son équipe, sa grille tarifaire, des récompenses
et des clients avec plusieurs mois d'historique de lavages.
"""

import random
from datetime import timedelta

from sqlalchemy import select

from app.api.routes.auth import create_user
from app.db import SessionLocal, utcnow
from app.main import init_db
from app.models import (
    Center,
    CenterMember,
    ClientVehicle,
    LoyaltyAccount,
    MemberRole,
    PointTransaction,
    PricingRule,
    Promotion,
    Reward,
    RewardVehicleCost,
    ServiceType,
    User,
    UserRole,
    VehicleType,
    Washer,
)
from app.services.loyalty import record_wash
from app.services.platform_settings import get_setting

FIRST = ["Aïcha", "Koffi", "Mariam", "Yao", "Fatou", "Jean", "Awa", "Moussa", "Clarisse", "Ibrahim", "Nadia", "Serge",
         "Aminata", "Didier", "Grâce", "Olivier", "Salimata", "Hervé", "Carine", "Bakary"]
LAST = ["Koné", "Traoré", "Kouassi", "Diallo", "Ouattara", "Bamba", "Yao", "N'Guessan", "Touré", "Coulibaly"]


def run() -> None:
    init_db()
    rnd = random.Random(42)
    with SessionLocal() as db:
        if db.scalar(select(Center.id).where(Center.slug == "lavpro-demo")):
            print("Données de démo déjà présentes.")
            return
        owner = create_user(db, email="demo@lavpro.app", password="demo1234", first_name="Awa", last_name="Koné",
                            role=UserRole.staff)
        center = Center(name="Lavpro Démo – Cocody", slug="lavpro-demo", address="Boulevard Latrille",
                        city="Abidjan", country="Côte d'Ivoire", phone="+225 07 00 00 00", lat=5.3599, lng=-3.9870,
                        currency="XOF", timezone="Africa/Abidjan", capacity=3, welcome_points=10, points_payment_enabled=True,
                        referral_referrer_points=50, referral_referee_points=25,
                        description="Lavage premium, à la main, avec des produits biodégradables.",
                        opening_hours=[{"day": d, "open": "07:30", "close": "20:00", "closed": False} for d in range(7)])
        db.add(center)
        db.flush()
        db.add(CenterMember(center_id=center.id, user_id=owner.id, role=MemberRole.owner))
        manager = create_user(db, email="manager@lavpro.app", password="demo1234", first_name="Serge",
                              last_name="Bamba", role=UserRole.staff)
        db.add(CenterMember(center_id=center.id, user_id=manager.id, role=MemberRole.manager))

        vehicles = [VehicleType(center_id=center.id, sort_order=i, **vt)
                    for i, vt in enumerate(get_setting(db, "center.default_vehicle_types"))]
        services = [ServiceType(center_id=center.id, sort_order=i, **st)
                    for i, st in enumerate(get_setting(db, "center.default_services"))]
        db.add_all(vehicles + services)
        db.flush()
        base = {0: 2000, 1: 5000, 2: 3000, 3: 4000}
        factor = [1, 1.4, 0.5, 1.8, 3.5]
        for si, s in enumerate(services):
            for vi, v in enumerate(vehicles):
                price = round(base.get(si, 3000) * factor[vi % len(factor)], -2)
                db.add(PricingRule(center_id=center.id, service_type_id=s.id, vehicle_type_id=v.id, price=price,
                                   points=int(price // 100), points_price=int(price // 10)))
        washers = [Washer(center_id=center.id, first_name=n, last_name=ln, commission_rate=10)
                   for n, ln in [("Koffi", "Yao"), ("Ibrahim", "Touré"), ("Didier", "Kouassi"), ("Moussa", "Diallo")]]
        db.add_all(washers)
        db.add_all([
            Reward(center_id=center.id, name="Lavage simple offert", category="wash", points_cost=150, sort_order=0,
                   service_type_id=services[0].id,
                   vehicle_costs=[RewardVehicleCost(vehicle_type_id=vehicles[0].id, points_cost=150),
                                  RewardVehicleCost(vehicle_type_id=vehicles[1].id, points_cost=220),
                                  RewardVehicleCost(vehicle_type_id=vehicles[2].id, points_cost=80)]),
            Reward(center_id=center.id, name="Senteur premium", category="fragrance", points_cost=80, stock=40),
            Reward(center_id=center.id, name="Jeu de tapis de sol", category="mat", points_cost=400, stock=10),
            Reward(center_id=center.id, name="Bidon d'huile 4 L", category="oil", points_cost=700, stock=8),
            Reward(center_id=center.id, name="Lavage complet offert", category="wash", points_cost=350,
                   service_type_id=services[1].id),
            Reward(center_id=center.id, name="Lavage sans eau offert", category="eco", points_cost=200,
                   service_type_id=services[3].id,
                   eco_min_liters_saved=300, description="Réservé aux clients ayant économisé 300 L d'eau"),
        ])
        now = utcnow()
        db.add(Promotion(center_id=center.id, name="Mardi double points", points_multiplier=2,
                         description="Tous les points doublés cette semaine !", starts_at=now - timedelta(days=1),
                         ends_at=now + timedelta(days=6)))
        db.flush()

        client = create_user(db, email="client@lavpro.app", password="demo1234", first_name="Mariam",
                             last_name="Ouattara", phone="+225 05 11 22 33")
        db.add(ClientVehicle(user_id=client.id, label="Toyota RAV4", category="4x4 / SUV", plate="AB-1234-CI"))
        clients = [client]
        for i in range(40):
            u = create_user(db, email=f"client{i}@demo.lavpro.app", password="demo1234", first_name=rnd.choice(FIRST),
                            last_name=rnd.choice(LAST), referred_by=client if i < 3 else None)
            u.created_at = now - timedelta(days=rnd.randint(1, 120))
            clients.append(u)
        db.flush()

        # ~4 mois d'historique
        events = []
        for u in clients:
            freq = rnd.choice([7, 10, 14, 21, 30, 45])
            t = now - timedelta(days=rnd.randint(90, 120))
            while t < now - timedelta(hours=2):
                events.append((t + timedelta(hours=rnd.randint(8, 19) - t.hour, minutes=rnd.randint(0, 59)), u))
                t += timedelta(days=max(1, int(rnd.gauss(freq, freq / 4))))
        for _ in range(120):  # clients de passage
            events.append((now - timedelta(days=rnd.randint(0, 110), hours=rnd.randint(0, 10)), None))
        events.sort(key=lambda e: e[0])
        for when, u in events:
            w = record_wash(db, center, service_type_id=rnd.choices(services, weights=[5, 4, 1, 2])[0].id,
                            vehicle_type_id=rnd.choices(vehicles, weights=[6, 4, 2, 2, 1])[0].id, user=u,
                            washer_id=rnd.choice(washers).id, validated_by=rnd.choice([owner, manager]))
            w.created_at = when
            db.flush()
            if u is not None:
                acc = db.scalar(select(LoyaltyAccount).where(LoyaltyAccount.user_id == u.id,
                                                             LoyaltyAccount.center_id == center.id))
                acc.last_visit_at = when
                if acc.visits == 1:
                    acc.created_at = when
                for tx in db.scalars(select(PointTransaction).where(PointTransaction.wash_id == w.id)):
                    tx.created_at = when
        center.current_queue = 2
        db.commit()
        n = db.scalar(select(User.id).where(User.email == "client@lavpro.app"))
        print(f"Démo créée : {len(events)} lavages. Connexion gérant demo@lavpro.app / demo1234 ; client id={n} "
              f"client@lavpro.app / demo1234")


if __name__ == "__main__":
    run()

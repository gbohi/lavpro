"""Paramètres globaux de la plateforme, stockés en base (table app_settings).

Les valeurs ci-dessous ne sont que des valeurs initiales : elles sont insérées au
premier démarrage puis entièrement modifiables par le super-administrateur.
"""

from typing import Any

from sqlalchemy.orm import Session

from app.models import AppSetting

DEFAULTS: dict[str, dict[str, Any]] = {
    "app.name": {"value": "Lavpro", "label": "Nom de l'application", "group": "general"},
    "app.support_email": {"value": "support@lavpro.app", "label": "E-mail du support", "group": "general"},
    "referral.share_message": {
        "value": "Rejoins-moi sur Lavpro avec mon code {code} et gagne des points bonus dès ton premier lavage !",
        "label": "Message de parrainage",
        "description": "{code} est remplacé par le code du client",
        "group": "referral",
    },
    "eco.levels": {
        "value": [
            {"name": "Goutte", "min_liters": 0, "icon": "water_drop"},
            {"name": "Ruisseau", "min_liters": 200, "icon": "waves"},
            {"name": "Rivière", "min_liters": 1000, "icon": "water"},
            {"name": "Océan", "min_liters": 5000, "icon": "public"},
        ],
        "label": "Niveaux du Mode Écolo",
        "group": "eco",
    },
    "eco.equivalences": {
        "value": [
            {"label": "douches", "liters_per_unit": 60, "icon": "shower"},
            {"label": "bouteilles de 1,5 L", "liters_per_unit": 1.5, "icon": "local_drink"},
        ],
        "label": "Équivalences d'eau économisée",
        "group": "eco",
    },
    "reminders.history_size": {"value": 6, "label": "Nombre de visites analysées pour la fréquence", "group": "reminders"},
    "reminders.min_days_between": {"value": 3, "label": "Jours minimum entre deux rappels", "group": "reminders"},
    "reminders.due_factor": {
        "value": 1.0,
        "label": "Facteur de déclenchement",
        "description": "Rappel lorsque (jours depuis la dernière visite) >= facteur x fréquence habituelle",
        "group": "reminders",
    },
    "reminders.early_days": {"value": 2, "label": "Anticipation (jours) si beau temps", "group": "reminders"},
    "weather.enabled": {"value": True, "label": "Prendre en compte la météo", "group": "weather"},
    "weather.rain_threshold_mm": {"value": 1.0, "label": "Seuil de pluie (mm/jour)", "group": "weather"},
    "weather.rain_probability_threshold": {"value": 50, "label": "Seuil de probabilité de pluie (%)", "group": "weather"},
    "weather.lookahead_days": {"value": 2, "label": "Jours de prévision analysés", "group": "weather"},
    "weather.cache_minutes": {"value": 60, "label": "Durée de cache météo (minutes)", "group": "weather"},
    "booking.cancel_min_notice_minutes": {"value": 60, "label": "Délai minimum d'annulation (minutes)", "group": "booking"},
    "centers.search_radius_km": {"value": 50, "label": "Rayon de recherche par défaut (km)", "group": "centers"},
    "vehicle.categories": {
        "value": ["Berline", "4x4 / SUV", "Moto", "Camionnette", "Gros camion"],
        "label": "Catégories de véhicules proposées aux clients",
        "group": "general",
    },
    "center.default_vehicle_types": {
        "value": [
            {"name": "Berline", "icon": "directions_car", "eco_baseline_liters": 200},
            {"name": "4x4 / SUV", "icon": "airport_shuttle", "eco_baseline_liters": 250},
            {"name": "Moto", "icon": "two_wheeler", "eco_baseline_liters": 80},
            {"name": "Camionnette", "icon": "local_shipping", "eco_baseline_liters": 300},
            {"name": "Gros camion", "icon": "fire_truck", "eco_baseline_liters": 600},
        ],
        "label": "Modèle de types de véhicules pour un nouveau centre",
        "group": "onboarding",
    },
    "center.default_services": {
        "value": [
            {"name": "Lavage simple", "icon": "local_car_wash", "duration_minutes": 20, "water_used_liters": 80},
            {"name": "Lavage complet", "icon": "auto_awesome", "duration_minutes": 45, "water_used_liters": 120},
            {"name": "Lavage moteur", "icon": "settings", "duration_minutes": 30, "water_used_liters": 60},
            {"name": "Lavage sans eau", "icon": "eco", "duration_minutes": 30, "water_used_liters": 5, "is_eco": True},
        ],
        "label": "Modèle de services pour un nouveau centre",
        "group": "onboarding",
    },
}


def seed_settings(db: Session) -> None:
    existing = {k for (k,) in db.query(AppSetting.key).all()}
    for key, meta in DEFAULTS.items():
        if key not in existing:
            db.add(AppSetting(key=key, value=meta["value"], label=meta.get("label", key),
                              description=meta.get("description"), group=meta.get("group", "general")))
    db.commit()


def get_setting(db: Session, key: str, default: Any = None) -> Any:
    row = db.get(AppSetting, key)
    if row is not None:
        return row.value
    if key in DEFAULTS:
        return DEFAULTS[key]["value"]
    return default

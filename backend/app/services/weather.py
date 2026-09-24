import logging
from datetime import timedelta

import httpx
from sqlalchemy.orm import Session

from app.core.config import get_settings
from app.db import utcnow
from app.models import WeatherCache
from app.services.platform_settings import get_setting

log = logging.getLogger("lavpro.weather")


def get_forecast(db: Session, lat: float, lng: float) -> list[dict] | None:
    """Prévisions journalières (Open-Meteo par défaut, sans clé API).

    Retourne une liste [{date, precipitation_mm, rain_probability, temp_max, weather_code}].
    """
    if not get_setting(db, "weather.enabled", True):
        return None
    key = f"{round(lat, 2)}:{round(lng, 2)}"
    cache = db.get(WeatherCache, key)
    ttl = timedelta(minutes=int(get_setting(db, "weather.cache_minutes", 60)))
    if cache and utcnow() - cache.fetched_at < ttl:
        return cache.payload.get("days")
    try:
        resp = httpx.get(get_settings().weather_api_url, params={
            "latitude": lat, "longitude": lng, "timezone": "auto", "forecast_days": 7,
            "daily": "precipitation_sum,precipitation_probability_max,temperature_2m_max,weather_code",
        }, timeout=5)
        resp.raise_for_status()
        daily = resp.json()["daily"]
    except (httpx.HTTPError, KeyError, ValueError) as exc:
        log.info("Météo indisponible: %s", exc)
        return cache.payload.get("days") if cache else None
    days = [
        {"date": d, "precipitation_mm": daily["precipitation_sum"][i] or 0,
         "rain_probability": (daily.get("precipitation_probability_max") or [0] * 7)[i] or 0,
         "temp_max": daily["temperature_2m_max"][i], "weather_code": daily["weather_code"][i]}
        for i, d in enumerate(daily["time"])
    ]
    if cache is None:
        cache = WeatherCache(key=key, payload={"days": days})
        db.add(cache)
    else:
        cache.payload = {"days": days}
    cache.fetched_at = utcnow()
    db.commit()
    return days


def is_rainy(db: Session, day: dict) -> bool:
    return (day["precipitation_mm"] >= float(get_setting(db, "weather.rain_threshold_mm", 1.0))
            or day["rain_probability"] >= float(get_setting(db, "weather.rain_probability_threshold", 50)))


def good_weather_window(db: Session, days: list[dict] | None) -> bool | None:
    """True si aucune pluie n'est prévue sur la fenêtre analysée, None si inconnue."""
    if not days:
        return None
    n = int(get_setting(db, "weather.lookahead_days", 2))
    return not any(is_rainy(db, d) for d in days[: max(n, 1)])

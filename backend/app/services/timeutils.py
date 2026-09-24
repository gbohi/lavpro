from datetime import datetime, timezone
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError


def to_naive_utc(dt: datetime) -> datetime:
    if dt.tzinfo is None:
        return dt
    return dt.astimezone(timezone.utc).replace(tzinfo=None)


def zone(name: str | None) -> ZoneInfo:
    try:
        return ZoneInfo(name or "UTC")
    except (ZoneInfoNotFoundError, ValueError):
        return ZoneInfo("UTC")


def local_now(tz_name: str | None) -> datetime:
    return datetime.now(zone(tz_name))


def local_to_naive_utc(dt: datetime, tz_name: str | None) -> datetime:
    return dt.replace(tzinfo=zone(tz_name)).astimezone(timezone.utc).replace(tzinfo=None)


def naive_utc_to_local(dt: datetime, tz_name: str | None) -> datetime:
    return dt.replace(tzinfo=timezone.utc).astimezone(zone(tz_name))

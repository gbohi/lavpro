import math
from datetime import date, datetime, time, timedelta

from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.db import utcnow
from app.models import Booking, BookingStatus, Center
from app.schemas.center import Occupancy
from app.services.timeutils import local_now, local_to_naive_utc

ACTIVE_BOOKING = (BookingStatus.pending, BookingStatus.confirmed)


def _parse(hhmm: str) -> time:
    h, m = hhmm.split(":")
    return time(int(h), int(m))


def day_hours(center: Center, d: date) -> tuple[time, time] | None:
    for entry in center.opening_hours or []:
        if int(entry.get("day", -1)) == d.weekday():
            if entry.get("closed"):
                return None
            return _parse(entry.get("open", "00:00")), _parse(entry.get("close", "23:59"))
    return None


def is_open_now(center: Center) -> bool:
    now = local_now(center.timezone)
    hours = day_hours(center, now.date())
    return bool(hours) and hours[0] <= now.time() < hours[1]


def compute_occupancy(db: Session, center: Center, avg_service_minutes: int | None = None) -> Occupancy:
    now = utcnow()
    active = db.scalar(select(func.count(Booking.id)).where(
        Booking.center_id == center.id, Booking.status.in_(ACTIVE_BOOKING),
        Booking.start_at <= now + timedelta(minutes=center.slot_duration_minutes), Booking.end_at >= now)) or 0
    open_ = is_open_now(center)
    load = center.current_queue + active
    capacity = max(center.capacity, 1)
    ratio = load / capacity
    if not open_:
        level = "closed"
    elif ratio >= center.occupancy_high_ratio:
        level = "high"
    elif ratio >= center.occupancy_moderate_ratio:
        level = "moderate"
    else:
        level = "low"
    per_car = avg_service_minutes or center.slot_duration_minutes
    wait = math.ceil(load / capacity) * per_car if load else 0
    return Occupancy(level=level, queue=center.current_queue, active_bookings=active, capacity=capacity,
                     estimated_wait_minutes=wait, is_open=open_)


def available_slots(db: Session, center: Center, d: date, duration_minutes: int | None = None) -> list[dict]:
    hours = day_hours(center, d)
    if not hours or not center.booking_enabled:
        return []
    step = timedelta(minutes=center.slot_duration_minutes)
    duration = timedelta(minutes=duration_minutes or center.slot_duration_minutes)
    start_local = datetime.combine(d, hours[0])
    close_local = datetime.combine(d, hours[1])
    min_start = utcnow() + timedelta(minutes=center.booking_min_notice_minutes)

    day_start_utc = local_to_naive_utc(start_local, center.timezone)
    day_end_utc = local_to_naive_utc(close_local, center.timezone)
    bookings = list(db.scalars(select(Booking).where(
        Booking.center_id == center.id, Booking.status.in_(ACTIVE_BOOKING),
        Booking.start_at < day_end_utc, Booking.end_at > day_start_utc)))

    slots = []
    cursor = start_local
    while cursor + duration <= close_local:
        s_utc = local_to_naive_utc(cursor, center.timezone)
        e_utc = s_utc + duration
        overlapping = sum(1 for b in bookings if b.start_at < e_utc and b.end_at > s_utc)
        if s_utc >= min_start:
            slots.append({"start_at": s_utc, "end_at": e_utc, "capacity": center.capacity,
                          "available": max(center.capacity - overlapping, 0)})
        cursor += step
    return slots


def haversine_km(lat1: float, lng1: float, lat2: float, lng2: float) -> float:
    r = 6371.0
    p1, p2 = math.radians(lat1), math.radians(lat2)
    dp, dl = math.radians(lat2 - lat1), math.radians(lng2 - lng1)
    a = math.sin(dp / 2) ** 2 + math.cos(p1) * math.cos(p2) * math.sin(dl / 2) ** 2
    return 2 * r * math.asin(math.sqrt(a))

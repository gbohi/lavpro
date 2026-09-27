"""Tâches planifiées quotidiennes : `python -m app.jobs.daily` (ex. cron chaque matin).

1. Expiration des points échus (+ notification « Des points ont expiré »).
2. Relances « Vos points vont expirer » selon les délais de chaque centre (ex. J-30, J-7).
3. Rappels intelligents de lavage (fréquence de visite + météo).
"""

from app.db import SessionLocal
from app.services.points import expire_points, send_expiry_reminders
from app.services.suggestions import run_reminders


def run() -> dict:
    with SessionLocal() as db:
        expired = expire_points(db)
        expiry_reminders = send_expiry_reminders(db)
        wash_reminders = run_reminders(db)
    return {"points_expired": expired, "expiry_reminders": expiry_reminders, "wash_reminders": wash_reminders}


if __name__ == "__main__":
    r = run()
    print(f"{r['points_expired']} point(s) expiré(s), {r['expiry_reminders']} relance(s) d'expiration, "
          f"{r['wash_reminders']} rappel(s) de lavage")

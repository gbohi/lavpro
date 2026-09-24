"""Tâche planifiée : `python -m app.jobs.reminders` (ex. cron toutes les heures)."""

from app.db import SessionLocal
from app.services.suggestions import run_reminders

if __name__ == "__main__":
    with SessionLocal() as db:
        print(f"{run_reminders(db)} rappel(s) envoyé(s)")

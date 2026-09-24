from contextlib import asynccontextmanager
from pathlib import Path

from alembic import command
from alembic.config import Config

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from sqlalchemy import select

from app import models  # noqa: F401  (enregistre les modèles)
from app.api.routes import admin, auth, centers, manage, me, uploads
from app.core.config import get_settings
from app.core.security import hash_password, random_code, random_token
from app.db import SessionLocal
from app.models import User, UserRole
from app.services.platform_settings import seed_settings

settings = get_settings()


BACKEND_DIR = Path(__file__).resolve().parent.parent


def run_migrations() -> None:
    """Applique les migrations Alembic en attente (équivalent de `alembic upgrade head`)."""
    cfg = Config(str(BACKEND_DIR / "alembic.ini"))
    cfg.attributes["configure_logger"] = False
    command.upgrade(cfg, "head")


def init_db() -> None:
    run_migrations()
    with SessionLocal() as db:
        seed_settings(db)
        if settings.superadmin_email and settings.superadmin_password:
            email = settings.superadmin_email.lower()
            if not db.scalar(select(User.id).where(User.email == email)):
                db.add(User(email=email, password_hash=hash_password(settings.superadmin_password),
                            first_name="Super", last_name="Admin", role=UserRole.superadmin,
                            qr_token=random_token(), member_code=random_code(8), referral_code=random_code(6)))
                db.commit()


@asynccontextmanager
async def lifespan(_: FastAPI):
    init_db()
    yield


app = FastAPI(title=settings.app_name, version="1.0.0", lifespan=lifespan,
              description="API REST de Lavpro : fidélisation et gestion des centres de lavage.")
app.add_middleware(CORSMiddleware, allow_origins=settings.cors_origins, allow_credentials=True,
                   allow_methods=["*"], allow_headers=["*"])

for r in (auth.router, centers.router, me.router, manage.router, admin.router, uploads.router):
    app.include_router(r, prefix=settings.api_prefix)

Path(settings.upload_dir).mkdir(parents=True, exist_ok=True)
app.mount("/uploads", StaticFiles(directory=settings.upload_dir), name="uploads")


@app.get("/health", tags=["Santé"])
def health():
    return {"status": "ok"}

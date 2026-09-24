import re
import unicodedata

from fastapi import APIRouter, HTTPException
from sqlalchemy import select

from app.api.deps import DB, CurrentUser, apply_patch
from app.api.serializers import me_out
from app.core.security import create_access_token, hash_password, random_code, random_token, verify_password
from app.models import Center, CenterMember, DeviceToken, MemberRole, ServiceType, User, UserRole, VehicleType
from app.schemas.auth import (
    DeviceTokenIn,
    LoginIn,
    MeOut,
    PasswordChange,
    RegisterIn,
    TokenOut,
    UserUpdate,
)
from app.schemas.center import CenterRegisterIn
from app.services.platform_settings import get_setting

router = APIRouter(prefix="/auth", tags=["Authentification"])


def _unique_code(db, column, length=8) -> str:
    code = random_code(length)
    while db.scalar(select(User.id).where(column == code)):
        code = random_code(length)
    return code


def create_user(db, *, email: str, password: str, first_name: str, last_name: str = "", phone: str | None = None,
                role: UserRole = UserRole.client, referred_by: User | None = None) -> User:
    if db.scalar(select(User.id).where(User.email == email.lower())):
        raise HTTPException(409, "Un compte existe déjà avec cet e-mail")
    user = User(email=email.lower(), password_hash=hash_password(password), first_name=first_name.strip(),
                last_name=last_name.strip(), phone=phone, role=role, qr_token=random_token(),
                member_code=_unique_code(db, User.member_code), referral_code=_unique_code(db, User.referral_code, 6),
                referred_by_id=referred_by.id if referred_by else None)
    db.add(user)
    db.flush()
    return user


def slugify(value: str) -> str:
    value = unicodedata.normalize("NFKD", value).encode("ascii", "ignore").decode()
    return re.sub(r"[^a-z0-9]+", "-", value.lower()).strip("-") or "centre"


def token_for(user: User) -> TokenOut:
    return TokenOut(access_token=create_access_token(user.id, {"role": user.role.value}), user=me_out(user))


@router.post("/register", response_model=TokenOut, status_code=201)
def register(body: RegisterIn, db: DB):
    referrer = None
    if body.referral_code:
        referrer = db.scalar(select(User).where(User.referral_code == body.referral_code.strip().upper()))
        if referrer is None:
            raise HTTPException(400, "Code de parrainage invalide")
    user = create_user(db, email=body.email, password=body.password, first_name=body.first_name,
                       last_name=body.last_name, phone=body.phone, referred_by=referrer)
    db.commit()
    db.refresh(user)
    return token_for(user)


@router.post("/login", response_model=TokenOut)
def login(body: LoginIn, db: DB):
    user = db.scalar(select(User).where(User.email == body.email.lower()))
    if user is None or not verify_password(body.password, user.password_hash):
        raise HTTPException(401, "E-mail ou mot de passe incorrect")
    if not user.is_active:
        raise HTTPException(403, "Compte désactivé")
    return token_for(user)


@router.post("/register-center", response_model=TokenOut, status_code=201)
def register_center(body: CenterRegisterIn, db: DB):
    """Enregistre un centre de lavage (une seule fois) et son gérant propriétaire."""
    owner = db.scalar(select(User).where(User.email == body.owner_email.lower()))
    if owner is not None:
        if not verify_password(body.owner_password, owner.password_hash):
            raise HTTPException(409, "Un compte existe déjà avec cet e-mail (mot de passe incorrect)")
    else:
        owner = create_user(db, email=body.owner_email, password=body.owner_password,
                            first_name=body.owner_first_name, last_name=body.owner_last_name,
                            phone=body.owner_phone, role=UserRole.staff)
    if owner.role == UserRole.client:
        owner.role = UserRole.staff
    base = slugify(f"{body.center_name}-{body.city}")
    slug, i = base, 1
    while db.scalar(select(Center.id).where(Center.slug == slug)):
        i += 1
        slug = f"{base}-{i}"
    center = Center(name=body.center_name, slug=slug, address=body.address, city=body.city, country=body.country,
                    phone=body.phone, lat=body.lat, lng=body.lng, currency=body.currency, email=body.owner_email)
    db.add(center)
    db.flush()
    db.add(CenterMember(center_id=center.id, user_id=owner.id, role=MemberRole.owner))
    # Pré-remplissage depuis les modèles paramétrables par le super-admin (modifiables ensuite)
    for i, vt in enumerate(get_setting(db, "center.default_vehicle_types", []) or []):
        db.add(VehicleType(center_id=center.id, sort_order=i, **vt))
    for i, st in enumerate(get_setting(db, "center.default_services", []) or []):
        db.add(ServiceType(center_id=center.id, sort_order=i, **st))
    db.commit()
    db.refresh(owner)
    return token_for(owner)


@router.get("/me", response_model=MeOut)
def me(user: CurrentUser):
    return me_out(user)


@router.patch("/me", response_model=MeOut)
def update_me(body: UserUpdate, user: CurrentUser, db: DB):
    apply_patch(user, body)
    db.commit()
    return me_out(user)


@router.post("/password", status_code=204)
def change_password(body: PasswordChange, user: CurrentUser, db: DB):
    if not verify_password(body.current_password, user.password_hash):
        raise HTTPException(400, "Mot de passe actuel incorrect")
    user.password_hash = hash_password(body.new_password)
    db.commit()


@router.post("/device-token", status_code=204)
def register_device(body: DeviceTokenIn, user: CurrentUser, db: DB):
    existing = db.scalar(select(DeviceToken).where(DeviceToken.token == body.token))
    if existing:
        existing.user_id = user.id
        existing.platform = body.platform
    else:
        db.add(DeviceToken(user_id=user.id, token=body.token, platform=body.platform))
    db.commit()


@router.post("/qr/regenerate", response_model=MeOut)
def regenerate_qr(user: CurrentUser, db: DB):
    """Régénère le QR code (en cas de perte / capture d'écran partagée)."""
    user.qr_token = random_token()
    db.commit()
    return me_out(user)

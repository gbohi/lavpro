"""Conversion des entités en schémas de sortie enrichis."""

from app.core.permissions import PERMISSIONS, clean
from app.models import Booking, CenterMember, MemberRole, Redemption, User, Wash
from app.schemas.activity import BookingOut, RedemptionOut, WashOut
from app.schemas.auth import MeOut, MembershipOut, UserOut
from app.schemas.center import MemberOut
from app.services.loyalty import QR_PREFIX


def member_permissions(m: CenterMember) -> list[str]:
    return list(PERMISSIONS) if m.role == MemberRole.owner else clean(m.permissions)


def me_out(user: User) -> MeOut:
    data = UserOut.model_validate(user).model_dump()
    return MeOut(**data, qr_payload=f"{QR_PREFIX}{user.qr_token}", memberships=[
        MembershipOut(center_id=m.center_id, center_name=m.center.name, role=m.role, permissions=member_permissions(m))
        for m in user.memberships if m.is_active
    ])


def wash_out(w: Wash) -> WashOut:
    out = WashOut.model_validate(w)
    out.center_name = w.center.name if w.center else None
    out.client_name = w.user.full_name if w.user else None
    out.service_name = w.service_type.name if w.service_type else None
    out.vehicle_type_name = w.vehicle_type.name if w.vehicle_type else None
    out.washer_name = w.washer.full_name if w.washer else None
    out.validated_by_name = w.validated_by.full_name if w.validated_by else None
    return out


def redemption_out(r: Redemption) -> RedemptionOut:
    out = RedemptionOut.model_validate(r)
    out.center_name = r.center.name if r.center else None
    out.client_name = r.user.full_name if r.user else None
    out.reward_name = r.reward.name if r.reward else None
    if r.reward and r.reward.is_wash:
        out.is_wash = True
        out.service_type_id = r.reward.service_type_id
        out.service_name = r.reward.service_name
    out.vehicle_type_name = r.vehicle_type.name if r.vehicle_type else None
    return out


def booking_out(b: Booking) -> BookingOut:
    out = BookingOut.model_validate(b)
    out.center_name = b.center.name if b.center else None
    out.client_name = b.user.full_name if b.user else None
    out.client_phone = b.user.phone if b.user else None
    out.service_name = b.service_type.name if b.service_type else None
    out.vehicle_type_name = b.vehicle_type.name if b.vehicle_type else None
    return out


def member_out(m: CenterMember) -> MemberOut:
    return MemberOut(id=m.id, user_id=m.user_id, role=m.role, permissions=member_permissions(m), is_active=m.is_active,
                     email=m.user.email,
                     first_name=m.user.first_name, last_name=m.user.last_name, phone=m.user.phone,
                     created_at=m.created_at)

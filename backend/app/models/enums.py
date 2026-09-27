import enum


class UserRole(str, enum.Enum):
    client = "client"
    staff = "staff"
    superadmin = "superadmin"


class MemberRole(str, enum.Enum):
    owner = "owner"
    manager = "manager"


class TransactionType(str, enum.Enum):
    earn = "earn"
    redeem = "redeem"
    referral = "referral"
    welcome = "welcome"
    bonus = "bonus"
    adjust = "adjust"
    refund = "refund"
    wash_payment = "wash_payment"
    expire = "expire"


class RedemptionStatus(str, enum.Enum):
    pending = "pending"
    used = "used"
    cancelled = "cancelled"


class BookingStatus(str, enum.Enum):
    pending = "pending"
    confirmed = "confirmed"
    completed = "completed"
    cancelled = "cancelled"
    no_show = "no_show"


class PromotionTarget(str, enum.Enum):
    all = "all"
    loyal = "loyal"
    inactive = "inactive"
    new = "new"


class PaymentMethod(str, enum.Enum):
    standard = "standard"
    reward = "reward"
    points = "points"

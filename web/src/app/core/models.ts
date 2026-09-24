export type MemberRole = 'owner' | 'manager';
export type UserRole = 'client' | 'staff' | 'superadmin';

export interface Membership { center_id: number; center_name: string; role: MemberRole; }

export interface Me {
  id: number; email: string; phone: string | null; first_name: string; last_name: string;
  avatar_url: string | null; role: UserRole; member_code: string; referral_code: string;
  qr_payload: string; memberships: Membership[]; created_at: string;
}

export interface TokenResponse { access_token: string; user: Me; }

export interface OpeningDay { day: number; open: string; close: string; closed: boolean; }

export interface Center {
  id: number; name: string; slug: string; description: string | null; address: string; city: string;
  country: string; phone: string | null; email: string | null; logo_url: string | null; cover_url: string | null;
  lat: number | null; lng: number | null; currency: string; timezone: string; is_active: boolean;
  opening_hours: OpeningDay[]; capacity: number; booking_enabled: boolean; slot_duration_minutes: number;
  booking_min_notice_minutes: number; booking_max_days_ahead: number; occupancy_moderate_ratio: number;
  occupancy_high_ratio: number; welcome_points: number; referral_referrer_points: number;
  referral_referee_points: number; loyal_min_visits: number; loyal_period_days: number;
  inactive_after_days: number; reminder_enabled: boolean; reminder_default_days: number; current_queue: number;
}

export interface Occupancy {
  level: 'low' | 'moderate' | 'high' | 'closed'; queue: number; active_bookings: number; capacity: number;
  estimated_wait_minutes: number; is_open: boolean;
}

export interface VehicleType {
  id: number; center_id: number; name: string; icon: string; eco_baseline_liters: number;
  sort_order: number; is_active: boolean;
}

export interface ServiceType {
  id: number; center_id: number; name: string; description: string | null; icon: string;
  duration_minutes: number; water_used_liters: number; is_eco: boolean; bookable: boolean;
  sort_order: number; is_active: boolean;
}

export interface PricingRule { id?: number; service_type_id: number; vehicle_type_id: number; price: number; points: number; is_active: boolean; }

export interface Reward {
  id: number; center_id: number; name: string; description: string | null; category: string;
  image_url: string | null; points_cost: number; stock: number | null; eco_min_liters_saved: number | null;
  valid_from: string | null; valid_until: string | null; sort_order: number; is_active: boolean;
}

export type PromotionTarget = 'all' | 'loyal' | 'inactive' | 'new';
export interface Promotion {
  id: number; center_id: number; name: string; description: string | null; points_multiplier: number;
  bonus_points: number; discount_percent: number; service_type_id: number | null; vehicle_type_id: number | null;
  target: PromotionTarget; starts_at: string; ends_at: string; notify_clients: boolean; is_active: boolean;
}

export interface Member {
  id: number; user_id: number; role: MemberRole; is_active: boolean; email: string; first_name: string;
  last_name: string; phone: string | null; created_at: string;
}

export interface Washer {
  id: number; first_name: string; last_name: string; full_name: string; phone: string | null;
  photo_url: string | null; commission_rate: number; is_active: boolean; created_at: string;
}

export interface ClientVehicle { id: number; label: string; category: string | null; plate: string | null; brand: string | null; color: string | null; }

export type RedemptionStatus = 'pending' | 'used' | 'cancelled';
export interface Redemption {
  id: number; center_id: number; user_id: number; client_name: string | null; reward_id: number;
  reward_name: string | null; points: number; code: string; status: RedemptionStatus; created_at: string; used_at: string | null;
}

export type BookingStatus = 'pending' | 'confirmed' | 'completed' | 'cancelled' | 'no_show';
export interface Booking {
  id: number; center_id: number; user_id: number; client_name: string | null; client_phone: string | null;
  service_type_id: number; service_name: string | null; vehicle_type_id: number; vehicle_type_name: string | null;
  start_at: string; end_at: string; status: BookingStatus; note: string | null; created_at: string;
}

export interface ClientLookup {
  user_id: number; first_name: string; last_name: string; email: string; phone: string | null; member_code: string;
  balance: number; visits: number; last_visit_at: string | null; vehicles: ClientVehicle[];
  pending_redemptions: Redemption[]; upcoming_bookings: Booking[]; is_loyal: boolean;
}

export interface Wash {
  id: number; center_id: number; user_id: number | null; client_name: string | null; service_type_id: number;
  service_name: string | null; vehicle_type_id: number; vehicle_type_name: string | null; washer_id: number | null;
  washer_name: string | null; validated_by_name: string | null; plate: string | null; price: number; discount: number;
  points_earned: number; water_saved_liters: number; note: string | null; created_at: string;
}

export interface ClientSummary {
  user_id: number; first_name: string; last_name: string; email: string; phone: string | null; member_code: string;
  balance: number; total_earned: number; visits: number; last_visit_at: string | null; is_loyal: boolean; created_at: string;
}

export interface Transaction { id: number; type: string; points: number; note: string | null; created_at: string; }

export interface Dashboard {
  period: { from: string; to: string; days: number };
  currency: string;
  kpis: {
    washes: number; revenue: number; avg_ticket: number; washes_per_day: number; unique_clients: number;
    anonymous_washes: number; new_clients: number; total_clients: number; returning_clients: number;
    loyal_clients: number; loyalty_rate: number; points_issued: number; points_redeemed: number;
    redemptions: Record<string, number>; bookings: number; water_saved_liters: number; queue: number;
  };
  washes_per_day: { date: string; washes: number; revenue: number }[];
  hourly: { hour: number; washes: number }[];
  weekdays: { day: number; washes: number }[];
  services: { id: number; name: string; count: number; revenue: number; share: number }[];
  vehicle_types: { id: number; name: string; count: number }[];
  washers: { id: number | null; name: string; count: number; revenue: number; commission: number; services?: Record<string, number> }[];
  top_clients: { id: number; name: string; washes: number; spent: number }[];
}

export interface AppSetting { key: string; value: unknown; label: string; description: string | null; group: string; updated_at: string; }
export interface AdminCenter { id: number; name: string; city: string; is_active: boolean; created_at: string; washes_count: number; clients_count: number; owner_email: string | null; }
export interface PlatformStats { centers: number; active_centers: number; clients: number; washes: number; washes_30d: number; points_issued: number; }

import 'package:lavpro_core/lavpro_core.dart';

/// Réservation vue par le centre (avec les identifiants pour préremplir la validation).
class StaffBooking {
  StaffBooking({required this.id, required this.clientName, this.clientPhone, required this.serviceId,
      this.serviceName, required this.vehicleTypeId, this.vehicleTypeName, required this.start, required this.end,
      required this.status, this.note, required this.userId});
  final int id;
  final int userId;
  final String clientName;
  final String? clientPhone;
  final int serviceId;
  final String? serviceName;
  final int vehicleTypeId;
  final String? vehicleTypeName;
  final DateTime start;
  final DateTime end;
  final String status;
  final String? note;

  bool get isActive => status == 'confirmed' || status == 'pending';
  String get statusLabel => Booking.labels[status] ?? status;

  factory StaffBooking.fromJson(Map<String, dynamic> j) => StaffBooking(
        id: j['id'], userId: j['user_id'], clientName: j['client_name'] ?? 'Client', clientPhone: j['client_phone'],
        serviceId: j['service_type_id'], serviceName: j['service_name'], vehicleTypeId: j['vehicle_type_id'],
        vehicleTypeName: j['vehicle_type_name'], start: parseDate(j['start_at'])!, end: parseDate(j['end_at'])!,
        status: j['status'], note: j['note'],
      );
}

class ClientLookup {
  ClientLookup({required this.userId, required this.firstName, required this.lastName, required this.memberCode,
      this.phone, required this.balance, required this.visits, this.lastVisit, required this.isLoyal,
      required this.vehicles, required this.pendingRedemptions, required this.upcomingBookings});
  final int userId;
  final String firstName;
  final String lastName;
  final String memberCode;
  final String? phone;
  final int balance;
  final int visits;
  final DateTime? lastVisit;
  final bool isLoyal;
  final List<ClientVehicle> vehicles;
  final List<Redemption> pendingRedemptions;
  final List<StaffBooking> upcomingBookings;

  String get fullName => '$firstName $lastName'.trim();
  String get initials => (firstName.isNotEmpty ? firstName[0] : '') + (lastName.isNotEmpty ? lastName[0] : '');

  factory ClientLookup.fromJson(Map<String, dynamic> j) => ClientLookup(
        userId: j['user_id'], firstName: j['first_name'], lastName: j['last_name'] ?? '', memberCode: j['member_code'],
        phone: j['phone'], balance: j['balance'], visits: j['visits'], lastVisit: parseDate(j['last_visit_at']),
        isLoyal: j['is_loyal'] ?? false, vehicles: parseList(j['vehicles'], ClientVehicle.fromJson),
        pendingRedemptions: parseList(j['pending_redemptions'], Redemption.fromJson),
        upcomingBookings: parseList(j['upcoming_bookings'], StaffBooking.fromJson),
      );
}

class Washer {
  Washer({required this.id, required this.fullName});
  final int id;
  final String fullName;
  factory Washer.fromJson(Map<String, dynamic> j) => Washer(id: j['id'], fullName: j['full_name']);
}

/// Lavage tel qu'affiché dans l'historique du centre.
class CenterWash {
  CenterWash({required this.id, this.clientName, this.serviceName, this.vehicleTypeName, this.washerName,
      this.validatedBy, this.plate, required this.price, required this.discount, required this.points,
      required this.createdAt});
  final int id;
  final String? clientName;
  final String? serviceName;
  final String? vehicleTypeName;
  final String? washerName;
  final String? validatedBy;
  final String? plate;
  final double price;
  final double discount;
  final int points;
  final DateTime createdAt;

  factory CenterWash.fromJson(Map<String, dynamic> j) => CenterWash(
        id: j['id'], clientName: j['client_name'], serviceName: j['service_name'],
        vehicleTypeName: j['vehicle_type_name'], washerName: j['washer_name'], validatedBy: j['validated_by_name'],
        plate: j['plate'], price: toDouble(j['price']), discount: toDouble(j['discount']), points: j['points_earned'],
        createdAt: parseDate(j['created_at'])!,
      );
}

/// Informations du centre utiles à l'application (sous-ensemble de /manage/centers/{id}).
class ManagedCenter {
  ManagedCenter({required this.id, required this.name, required this.currency, required this.city});
  final int id;
  final String name;
  final String currency;
  final String city;
  factory ManagedCenter.fromJson(Map<String, dynamic> j) =>
      ManagedCenter(id: j['id'], name: j['name'], currency: j['currency'] ?? '', city: j['city'] ?? '');
}

/// Données du tableau de bord (voir /stats/dashboard).
class DashboardData {
  DashboardData({required this.kpis, required this.hourly, required this.washers, required this.services,
      required this.perDay, required this.currency});
  final Map<String, dynamic> kpis;
  final List<int> hourly;
  final List<Map<String, dynamic>> washers;
  final List<Map<String, dynamic>> services;
  final List<Map<String, dynamic>> perDay;
  final String currency;

  num kpi(String k) => (kpis[k] as num?) ?? 0;

  factory DashboardData.fromJson(Map<String, dynamic> j) => DashboardData(
        kpis: Map<String, dynamic>.from(j['kpis']),
        hourly: [for (final h in j['hourly'] as List) (h['washes'] as num).toInt()],
        washers: List<Map<String, dynamic>>.from(j['washers']),
        services: List<Map<String, dynamic>>.from(j['services']),
        perDay: List<Map<String, dynamic>>.from(j['washes_per_day']),
        currency: j['currency'] ?? '',
      );
}

/// Référentiel du centre nécessaire pour valider un lavage.
class CenterCatalog {
  CenterCatalog({required this.services, required this.vehicleTypes, required this.pricing, required this.washers});
  final List<ServiceType> services;
  final List<VehicleType> vehicleTypes;
  final List<PricingRule> pricing;
  final List<Washer> washers;

  PricingRule? rule(int? serviceId, int? vehicleId) {
    for (final r in pricing) {
      if (r.serviceId == serviceId && r.vehicleId == vehicleId) return r;
    }
    return null;
  }
}

import 'json.dart';

class OpeningDay {
  OpeningDay({required this.day, required this.open, required this.close, required this.closed});
  final int day;
  final String open;
  final String close;
  final bool closed;
  factory OpeningDay.fromJson(Map<String, dynamic> j) =>
      OpeningDay(day: j['day'], open: j['open'], close: j['close'], closed: j['closed'] ?? false);
}

class Occupancy {
  Occupancy({required this.level, required this.queue, required this.activeBookings, required this.capacity,
      required this.waitMinutes, required this.isOpen});
  final String level; // low | moderate | high | closed
  final int queue;
  final int activeBookings;
  final int capacity;
  final int waitMinutes;
  final bool isOpen;

  factory Occupancy.fromJson(Map<String, dynamic> j) => Occupancy(
      level: j['level'], queue: j['queue'], activeBookings: j['active_bookings'], capacity: j['capacity'],
      waitMinutes: j['estimated_wait_minutes'], isOpen: j['is_open']);
}

class WashCenter {
  WashCenter({
    required this.id, required this.name, this.description, required this.address, required this.city, this.phone,
    this.logoUrl, this.coverUrl, this.lat, this.lng, required this.currency, required this.bookingEnabled,
    required this.openingHours, this.distanceKm, this.occupancy, this.myBalance, this.pointsPaymentEnabled = false,
  });
  final int id;
  final String name;
  final String? description;
  final String address;
  final String city;
  final String? phone;
  final String? logoUrl;
  final String? coverUrl;
  final double? lat;
  final double? lng;
  final String currency;
  final bool bookingEnabled;
  final List<OpeningDay> openingHours;
  final double? distanceKm;
  final Occupancy? occupancy;
  final int? myBalance;
  /// Le centre accepte le règlement d'un lavage en points au comptoir.
  final bool pointsPaymentEnabled;

  String get fullAddress => [address, city].where((e) => e.isNotEmpty).join(', ');

  OpeningDay? get today {
    final wd = DateTime.now().weekday - 1;
    for (final d in openingHours) {
      if (d.day == wd) return d;
    }
    return null;
  }

  factory WashCenter.fromJson(Map<String, dynamic> j) => WashCenter(
        id: j['id'], name: j['name'], description: j['description'], address: j['address'] ?? '',
        city: j['city'] ?? '', phone: j['phone'], logoUrl: j['logo_url'], coverUrl: j['cover_url'],
        lat: (j['lat'] as num?)?.toDouble(), lng: (j['lng'] as num?)?.toDouble(), currency: j['currency'] ?? '',
        bookingEnabled: j['booking_enabled'] ?? false, openingHours: parseList(j['opening_hours'], OpeningDay.fromJson),
        distanceKm: (j['distance_km'] as num?)?.toDouble(),
        occupancy: j['occupancy'] == null ? null : Occupancy.fromJson(j['occupancy']), myBalance: j['my_balance'],
        pointsPaymentEnabled: j['points_payment_enabled'] ?? false,
      );
}

class VehicleType {
  VehicleType({required this.id, required this.name, required this.icon, required this.ecoBaseline});
  final int id;
  final String name;
  final String icon;
  final double ecoBaseline;
  factory VehicleType.fromJson(Map<String, dynamic> j) =>
      VehicleType(id: j['id'], name: j['name'], icon: j['icon'] ?? 'car', ecoBaseline: toDouble(j['eco_baseline_liters']));
}

class ServiceType {
  ServiceType({required this.id, required this.name, this.description, required this.icon, required this.duration,
      required this.waterUsed, required this.isEco, required this.bookable});
  final int id;
  final String name;
  final String? description;
  final String icon;
  final int duration;
  final double waterUsed;
  final bool isEco;
  final bool bookable;
  factory ServiceType.fromJson(Map<String, dynamic> j) => ServiceType(
      id: j['id'], name: j['name'], description: j['description'], icon: j['icon'] ?? 'water',
      duration: j['duration_minutes'], waterUsed: toDouble(j['water_used_liters']), isEco: j['is_eco'] ?? false,
      bookable: j['bookable'] ?? true);
}

class PricingRule {
  PricingRule({required this.serviceId, required this.vehicleId, required this.price, required this.points,
      this.pointsPrice});
  final int serviceId;
  final int vehicleId;
  final double price;
  /// Points gagnés par le client.
  final int points;
  /// Points à dépenser pour payer ce lavage au comptoir (null = non payable en points).
  final int? pointsPrice;
  factory PricingRule.fromJson(Map<String, dynamic> j) => PricingRule(
      serviceId: j['service_type_id'], vehicleId: j['vehicle_type_id'], price: toDouble(j['price']),
      points: toInt(j['points']), pointsPrice: (j['points_price'] as num?)?.toInt());
}

class Promotion {
  Promotion({required this.id, required this.name, this.description, required this.multiplier, required this.bonus,
      required this.discount, required this.endsAt});
  final int id;
  final String name;
  final String? description;
  final double multiplier;
  final int bonus;
  final double discount;
  final DateTime endsAt;
  factory Promotion.fromJson(Map<String, dynamic> j) => Promotion(
      id: j['id'], name: j['name'], description: j['description'], multiplier: toDouble(j['points_multiplier']),
      bonus: toInt(j['bonus_points']), discount: toDouble(j['discount_percent']), endsAt: parseDate(j['ends_at'])!);

  String get perk {
    final parts = <String>[
      if (multiplier != 1) 'Points ×${multiplier.toStringAsFixed(multiplier % 1 == 0 ? 0 : 1)}',
      if (bonus > 0) '+$bonus pts',
      if (discount > 0) '-${discount.toStringAsFixed(0)} %',
    ];
    return parts.join(' · ');
  }
}

class Catalog {
  Catalog({required this.services, required this.vehicleTypes, required this.pricing, required this.promotions});
  final List<ServiceType> services;
  final List<VehicleType> vehicleTypes;
  final List<PricingRule> pricing;
  final List<Promotion> promotions;

  PricingRule? rule(int serviceId, int vehicleId) {
    for (final r in pricing) {
      if (r.serviceId == serviceId && r.vehicleId == vehicleId) return r;
    }
    return null;
  }

  factory Catalog.fromJson(Map<String, dynamic> j) => Catalog(
        services: parseList(j['services'], ServiceType.fromJson),
        vehicleTypes: parseList(j['vehicle_types'], VehicleType.fromJson),
        pricing: parseList(j['pricing'], PricingRule.fromJson),
        promotions: parseList(j['promotions'], Promotion.fromJson),
      );
}

class Slot {
  Slot({required this.start, required this.end, required this.available, required this.capacity});
  final DateTime start;
  final DateTime end;
  final int available;
  final int capacity;
  String get startIso => start.toUtc().toIso8601String();
  factory Slot.fromJson(Map<String, dynamic> j) => Slot(
      start: parseDate(j['start_at'])!, end: parseDate(j['end_at'])!, available: j['available'], capacity: j['capacity']);
}

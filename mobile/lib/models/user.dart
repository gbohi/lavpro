import 'json.dart';

class Membership {
  Membership({required this.centerId, required this.centerName, required this.role});
  final int centerId;
  final String centerName;
  final String role;

  factory Membership.fromJson(Map<String, dynamic> j) =>
      Membership(centerId: j['center_id'], centerName: j['center_name'], role: j['role']);
}

class AppUser {
  AppUser({
    required this.id, required this.email, required this.phone, required this.firstName, required this.lastName,
    required this.avatarUrl, required this.role, required this.memberCode, required this.referralCode,
    required this.qrPayload, required this.ecoMode, required this.notificationsEnabled,
    required this.weatherReminders, required this.memberships, required this.createdAt,
  });

  final int id;
  final String email;
  final String? phone;
  final String firstName;
  final String lastName;
  final String? avatarUrl;
  final String role;
  final String memberCode;
  final String referralCode;
  final String qrPayload;
  final bool ecoMode;
  final bool notificationsEnabled;
  final bool weatherReminders;
  final List<Membership> memberships;
  final DateTime createdAt;

  String get fullName => '$firstName $lastName'.trim();
  String get initials => (firstName.isNotEmpty ? firstName[0] : '') + (lastName.isNotEmpty ? lastName[0] : '');
  bool get isStaff => memberships.isNotEmpty;

  factory AppUser.fromJson(Map<String, dynamic> j) => AppUser(
        id: j['id'], email: j['email'], phone: j['phone'], firstName: j['first_name'], lastName: j['last_name'] ?? '',
        avatarUrl: j['avatar_url'], role: j['role'], memberCode: j['member_code'], referralCode: j['referral_code'],
        qrPayload: j['qr_payload'], ecoMode: j['eco_mode'] ?? true,
        notificationsEnabled: j['notifications_enabled'] ?? true, weatherReminders: j['weather_reminders'] ?? true,
        memberships: parseList(j['memberships'], Membership.fromJson), createdAt: parseDate(j['created_at'])!,
      );
}

class ClientVehicle {
  ClientVehicle({required this.id, required this.label, this.category, this.plate, this.brand, this.color});
  final int id;
  final String label;
  final String? category;
  final String? plate;
  final String? brand;
  final String? color;

  factory ClientVehicle.fromJson(Map<String, dynamic> j) => ClientVehicle(
      id: j['id'], label: j['label'], category: j['category'], plate: j['plate'], brand: j['brand'], color: j['color']);

  Map<String, dynamic> toJson() =>
      {'label': label, 'category': category, 'plate': plate, 'brand': brand, 'color': color};
}

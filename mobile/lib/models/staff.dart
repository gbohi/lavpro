import 'json.dart';
import 'loyalty.dart';
import 'user.dart';

class ClientLookup {
  ClientLookup({required this.userId, required this.firstName, required this.lastName, required this.memberCode,
      required this.balance, required this.visits, required this.isLoyal, required this.vehicles,
      required this.pendingRedemptions, required this.upcomingBookings});
  final int userId;
  final String firstName;
  final String lastName;
  final String memberCode;
  final int balance;
  final int visits;
  final bool isLoyal;
  final List<ClientVehicle> vehicles;
  final List<Redemption> pendingRedemptions;
  final List<Booking> upcomingBookings;

  factory ClientLookup.fromJson(Map<String, dynamic> j) => ClientLookup(
        userId: j['user_id'], firstName: j['first_name'], lastName: j['last_name'] ?? '', memberCode: j['member_code'],
        balance: j['balance'], visits: j['visits'], isLoyal: j['is_loyal'] ?? false,
        vehicles: parseList(j['vehicles'], ClientVehicle.fromJson),
        pendingRedemptions: parseList(j['pending_redemptions'], Redemption.fromJson),
        upcomingBookings: parseList(j['upcoming_bookings'], Booking.fromJson),
      );
}

class Washer {
  Washer({required this.id, required this.fullName});
  final int id;
  final String fullName;
  factory Washer.fromJson(Map<String, dynamic> j) => Washer(id: j['id'], fullName: j['full_name']);
}

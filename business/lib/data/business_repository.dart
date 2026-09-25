import 'package:lavpro_core/lavpro_core.dart';

import '../models/staff.dart';

/// Accès aux endpoints de gestion (/manage/centers/{id}) de l'API Lavpro.
class BusinessRepository {
  BusinessRepository(this.api);
  final ApiClient api;

  Future<AppUser> login(String email, String password) async {
    final r = await api.post<Map<String, dynamic>>('/auth/login', {'email': email, 'password': password});
    await api.saveToken(r['access_token'] as String);
    return AppUser.fromJson(r['user']);
  }

  Future<AppUser> me() async => AppUser.fromJson(await api.get('/auth/me'));

  String _m(int centerId) => '/manage/centers/$centerId';
  String _d(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<ManagedCenter> center(int id) async => ManagedCenter.fromJson(await api.get(_m(id)));

  Future<DashboardData> dashboard(int id, DateTime from, DateTime to) async => DashboardData.fromJson(
      await api.get('${_m(id)}/stats/dashboard', query: {'date_from': _d(from), 'date_to': _d(to)}));

  Future<Occupancy> occupancy(int id) async => Occupancy.fromJson(await api.get('${_m(id)}/occupancy'));
  Future<Occupancy> queue(int id, int delta) async =>
      Occupancy.fromJson(await api.post('${_m(id)}/queue', {'delta': delta}));

  Future<CenterCatalog> catalog(int id) async {
    final r = await Future.wait([
      api.get<List>('${_m(id)}/services'),
      api.get<List>('${_m(id)}/vehicle-types'),
      api.get<List>('${_m(id)}/pricing'),
      api.get<List>('${_m(id)}/washers', query: {'active_only': true}),
    ]);
    bool active(Map<String, dynamic> j) => j['is_active'] != false;
    return CenterCatalog(
      services: parseList(r[0], (j) => j).where(active).map(ServiceType.fromJson).toList(),
      vehicleTypes: parseList(r[1], (j) => j).where(active).map(VehicleType.fromJson).toList(),
      pricing: parseList(r[2], (j) => j).where(active).map(PricingRule.fromJson).toList(),
      washers: parseList(r[3], Washer.fromJson),
    );
  }

  Future<ClientLookup> lookup(int id, String code) async =>
      ClientLookup.fromJson(await api.get('${_m(id)}/clients/lookup', query: {'code': code}));

  Future<CenterWash> validateWash(int id, {String? clientCode, required int serviceId, required int vehicleTypeId,
      int? washerId, int? bookingId, String? plate, String paymentMethod = 'standard', int? redemptionId}) async =>
      CenterWash.fromJson(await api.post('${_m(id)}/washes', {
        'client_code': clientCode, 'service_type_id': serviceId, 'vehicle_type_id': vehicleTypeId,
        'washer_id': washerId, 'booking_id': bookingId, 'plate': (plate?.isEmpty ?? true) ? null : plate,
        'payment_method': paymentMethod, 'redemption_id': redemptionId,
      }));

  Future<List<CenterWash>> washes(int id, DateTime day) async => parseList(
      await api.get<List>('${_m(id)}/washes', query: {'date_from': _d(day), 'date_to': _d(day)}), CenterWash.fromJson);

  Future<Redemption> giveReward(int id, String idOrCode) async =>
      Redemption.fromJson(await api.post('${_m(id)}/redemptions/${Uri.encodeComponent(idOrCode)}/validate'));

  // ---- Laveurs ------------------------------------------------------------------
  Future<List<Washer>> allWashers(int id) async => parseList(await api.get<List>('${_m(id)}/washers'), Washer.fromJson);

  Future<void> saveWasher(int id, {int? washerId, required String firstName, String lastName = '', String? phone,
      double commissionRate = 0, bool isActive = true}) {
    final body = {
      'first_name': firstName, 'last_name': lastName, 'phone': (phone?.isEmpty ?? true) ? null : phone,
      'commission_rate': commissionRate, 'is_active': isActive,
    };
    return washerId == null ? api.post('${_m(id)}/washers', body) : api.patch('${_m(id)}/washers/$washerId', body);
  }

  Future<void> deleteWasher(int id, int washerId) => api.delete('${_m(id)}/washers/$washerId');

  Future<List<StaffBooking>> bookings(int id, DateTime day) async =>
      parseList(await api.get<List>('${_m(id)}/bookings', query: {'day': _d(day)}), StaffBooking.fromJson);

  Future<void> setBookingStatus(int id, int bookingId, String status) =>
      api.patch('${_m(id)}/bookings/$bookingId', {'status': status});
}

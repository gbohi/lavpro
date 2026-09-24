import 'package:lavpro_core/lavpro_core.dart';


/// Accès à l'API REST Lavpro.
class LavproRepository {
  LavproRepository(this.api);
  final ApiClient api;

  // ---- Authentification -----------------------------------------------------
  Future<AppUser> login(String email, String password) async {
    final r = await api.post<Map<String, dynamic>>('/auth/login', {'email': email, 'password': password});
    await api.saveToken(r['access_token'] as String);
    return AppUser.fromJson(r['user']);
  }

  Future<AppUser> register({required String email, required String password, required String firstName,
      String lastName = '', String? phone, String? referralCode}) async {
    final r = await api.post<Map<String, dynamic>>('/auth/register', {
      'email': email, 'password': password, 'first_name': firstName, 'last_name': lastName, 'phone': phone,
      'referral_code': (referralCode?.isEmpty ?? true) ? null : referralCode!.trim().toUpperCase(),
    });
    await api.saveToken(r['access_token'] as String);
    return AppUser.fromJson(r['user']);
  }

  Future<AppUser> me() async => AppUser.fromJson(await api.get('/auth/me'));
  Future<AppUser> updateMe(Map<String, dynamic> patch) async => AppUser.fromJson(await api.patch('/auth/me', patch));
  Future<AppUser> regenerateQr() async => AppUser.fromJson(await api.post('/auth/qr/regenerate'));
  Future<void> changePassword(String current, String next) =>
      api.post('/auth/password', {'current_password': current, 'new_password': next});

  // ---- Centres ----------------------------------------------------------------
  Future<List<WashCenter>> centers({String? q, double? lat, double? lng}) async =>
      parseList(await api.get<List>('/centers', query: {'q': q, 'lat': lat, 'lng': lng}), WashCenter.fromJson);
  Future<WashCenter> center(int id, {double? lat, double? lng}) async =>
      WashCenter.fromJson(await api.get('/centers/$id', query: {'lat': lat, 'lng': lng}));
  Future<Occupancy> occupancy(int id) async => Occupancy.fromJson(await api.get('/centers/$id/occupancy'));
  Future<Catalog> catalog(int id) async => Catalog.fromJson(await api.get('/centers/$id/catalog'));
  Future<List<Reward>> rewards(int centerId) async =>
      parseList(await api.get<List>('/centers/$centerId/rewards'), Reward.fromJson);
  Future<List<Slot>> slots(int centerId, DateTime day, int serviceId) async => parseList(
      await api.get<List>('/centers/$centerId/slots', query: {
        'day': '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}',
        'service_type_id': serviceId,
      }),
      Slot.fromJson);

  // ---- Espace client ------------------------------------------------------------
  Future<List<LoyaltyAccount>> accounts() async => parseList(await api.get<List>('/me/accounts'), LoyaltyAccount.fromJson);
  Future<List<WashRecord>> washes({int? centerId}) async =>
      parseList(await api.get<List>('/me/washes', query: {'center_id': centerId}), WashRecord.fromJson);
  Future<List<PointTx>> transactions({int? centerId}) async =>
      parseList(await api.get<List>('/me/transactions', query: {'center_id': centerId}), PointTx.fromJson);
  Future<List<Redemption>> redemptions() async => parseList(await api.get<List>('/me/redemptions'), Redemption.fromJson);
  Future<Redemption> redeem(int rewardId, {int? vehicleTypeId}) async => Redemption.fromJson(
      await api.post('/me/redemptions', {'reward_id': rewardId, 'vehicle_type_id': vehicleTypeId}));
  Future<void> cancelRedemption(int id) => api.post('/me/redemptions/$id/cancel');
  Future<List<Booking>> bookings({bool upcoming = false}) async =>
      parseList(await api.get<List>('/me/bookings', query: {'upcoming': upcoming}), Booking.fromJson);
  Future<Booking> book({required int centerId, required int serviceId, required int vehicleTypeId,
      required Slot slot, String? note}) async =>
      Booking.fromJson(await api.post('/me/bookings', {
        'center_id': centerId, 'service_type_id': serviceId, 'vehicle_type_id': vehicleTypeId,
        'start_at': slot.startIso, 'note': note,
      }));
  Future<void> cancelBooking(int id) => api.post('/me/bookings/$id/cancel');
  Future<List<AppNotification>> notifications() async =>
      parseList(await api.get<List>('/me/notifications'), AppNotification.fromJson);
  Future<int> unreadCount() async => (await api.get<num>('/me/notifications/unread-count')).toInt();
  Future<void> readAll() => api.post('/me/notifications/read-all');
  Future<List<Suggestion>> suggestions() async => parseList(await api.get<List>('/me/suggestions'), Suggestion.fromJson);
  Future<EcoStats> eco() async => EcoStats.fromJson(await api.get('/me/eco'));
  Future<ReferralStats> referral() async => ReferralStats.fromJson(await api.get('/me/referral'));
  Future<List<ClientVehicle>> vehicles() async => parseList(await api.get<List>('/me/vehicles'), ClientVehicle.fromJson);
  Future<List<String>> vehicleCategories() async => List<String>.from(await api.get<List>('/me/vehicle-categories'));
  Future<void> saveVehicle(ClientVehicle v) =>
      v.id == 0 ? api.post('/me/vehicles', v.toJson()) : api.put('/me/vehicles/${v.id}', v.toJson());
  Future<void> deleteVehicle(int id) => api.delete('/me/vehicles/$id');
}

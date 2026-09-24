import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:geolocator/geolocator.dart';

import '../core/api_client.dart';
import '../data/lavpro_repository.dart';
import '../models/center.dart';
import '../models/loyalty.dart';
import '../models/user.dart';

final apiClientProvider = Provider<ApiClient>((ref) => ApiClient(const FlutterSecureStorage()));
final repoProvider = Provider<LavproRepository>((ref) => LavproRepository(ref.watch(apiClientProvider)));

// ---- Session ---------------------------------------------------------------
sealed class AuthState {
  const AuthState();
}

class AuthLoading extends AuthState {
  const AuthLoading();
}

class AuthSignedOut extends AuthState {
  const AuthSignedOut();
}

class AuthSignedIn extends AuthState {
  const AuthSignedIn(this.user);
  final AppUser user;
}

class AuthController extends Notifier<AuthState> {
  @override
  AuthState build() {
    ref.read(apiClientProvider).onUnauthorized = () => state = const AuthSignedOut();
    _restore();
    return const AuthLoading();
  }

  LavproRepository get _repo => ref.read(repoProvider);

  Future<void> _restore() async {
    final token = await ref.read(apiClientProvider).readToken();
    if (token == null) {
      state = const AuthSignedOut();
      return;
    }
    try {
      state = AuthSignedIn(await _repo.me());
    } on ApiException {
      // Jeton expiré ou serveur injoignable : retour à l'écran d'accueil.
      state = const AuthSignedOut();
    }
  }

  Future<void> login(String email, String password) async => state = AuthSignedIn(await _repo.login(email, password));

  Future<void> register({required String email, required String password, required String firstName,
      String lastName = '', String? phone, String? referralCode}) async {
    state = AuthSignedIn(await _repo.register(email: email, password: password, firstName: firstName,
        lastName: lastName, phone: phone, referralCode: referralCode));
  }

  Future<void> refresh() async => state = AuthSignedIn(await _repo.me());
  Future<void> update(Map<String, dynamic> patch) async => state = AuthSignedIn(await _repo.updateMe(patch));
  Future<void> regenerateQr() async => state = AuthSignedIn(await _repo.regenerateQr());

  Future<void> logout() async {
    await ref.read(apiClientProvider).saveToken(null);
    state = const AuthSignedOut();
  }
}

final authProvider = NotifierProvider<AuthController, AuthState>(AuthController.new);
final currentUserProvider = Provider<AppUser?>((ref) {
  final s = ref.watch(authProvider);
  return s is AuthSignedIn ? s.user : null;
});

// ---- Préférences locales ---------------------------------------------------------
class ThemeModeController extends Notifier<ThemeMode> {
  @override
  ThemeMode build() => ThemeMode.system;
  void set(ThemeMode m) => state = m;
}

final themeModeProvider = NotifierProvider<ThemeModeController, ThemeMode>(ThemeModeController.new);

// ---- Localisation ------------------------------------------------------------------
final positionProvider = FutureProvider<Position?>((ref) async {
  try {
    return await _locate().timeout(const Duration(seconds: 8));
  } catch (_) {
    return null; // Sans position, les centres sont triés par nom.
  }
});

Future<Position?> _locate() async {
  try {
    if (!await Geolocator.isLocationServiceEnabled()) return null;
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
    if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) return null;
    return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium, timeLimit: Duration(seconds: 10)));
  } catch (_) {
    return null;
  }
}

// ---- Données ----------------------------------------------------------------------
final accountsProvider = FutureProvider<List<LoyaltyAccount>>((ref) => ref.watch(repoProvider).accounts());
final suggestionsProvider = FutureProvider<List<Suggestion>>((ref) => ref.watch(repoProvider).suggestions());
final ecoProvider = FutureProvider<EcoStats>((ref) => ref.watch(repoProvider).eco());
final referralProvider = FutureProvider<ReferralStats>((ref) => ref.watch(repoProvider).referral());
final redemptionsProvider = FutureProvider<List<Redemption>>((ref) => ref.watch(repoProvider).redemptions());
final bookingsProvider = FutureProvider<List<Booking>>((ref) => ref.watch(repoProvider).bookings());
final washesProvider = FutureProvider<List<WashRecord>>((ref) => ref.watch(repoProvider).washes());
final transactionsProvider = FutureProvider<List<PointTx>>((ref) => ref.watch(repoProvider).transactions());
final notificationsProvider = FutureProvider<List<AppNotification>>((ref) => ref.watch(repoProvider).notifications());
final unreadProvider = FutureProvider<int>((ref) => ref.watch(repoProvider).unreadCount());
final vehiclesProvider = FutureProvider<List<ClientVehicle>>((ref) => ref.watch(repoProvider).vehicles());

class CenterSearch extends Notifier<String> {
  @override
  String build() => '';
  void set(String q) => state = q;
}

final centerSearchProvider = NotifierProvider<CenterSearch, String>(CenterSearch.new);

final centersProvider = FutureProvider<List<WashCenter>>((ref) async {
  final pos = await ref.watch(positionProvider.future);
  final q = ref.watch(centerSearchProvider);
  return ref.watch(repoProvider).centers(q: q.isEmpty ? null : q, lat: pos?.latitude, lng: pos?.longitude);
});

final centerProvider = FutureProvider.family<WashCenter, int>((ref, id) async {
  final pos = ref.watch(positionProvider).value;
  return ref.watch(repoProvider).center(id, lat: pos?.latitude, lng: pos?.longitude);
});
final catalogProvider = FutureProvider.family<Catalog, int>((ref, id) => ref.watch(repoProvider).catalog(id));
final centerRewardsProvider = FutureProvider.family<List<Reward>, int>((ref, id) => ref.watch(repoProvider).rewards(id));

/// Rafraîchit les données liées aux points après une action.
void refreshLoyalty(WidgetRef ref) {
  ref.invalidate(accountsProvider);
  ref.invalidate(redemptionsProvider);
  ref.invalidate(transactionsProvider);
  ref.invalidate(suggestionsProvider);
  ref.invalidate(centerRewardsProvider);
}

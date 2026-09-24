import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:lavpro_core/lavpro_core.dart';

import '../data/business_repository.dart';
import '../models/staff.dart';

final apiClientProvider = Provider<ApiClient>((ref) => ApiClient(const FlutterSecureStorage()));
final repoProvider = Provider<BusinessRepository>((ref) => BusinessRepository(ref.watch(apiClientProvider)));

// ---- Session (réservée aux gestionnaires de centre) -------------------------------
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

  BusinessRepository get _repo => ref.read(repoProvider);

  Future<void> _restore() async {
    if (await ref.read(apiClientProvider).readToken() == null) {
      state = const AuthSignedOut();
      return;
    }
    try {
      final user = await _repo.me();
      state = user.isStaff ? AuthSignedIn(user) : const AuthSignedOut();
    } on ApiException {
      state = const AuthSignedOut();
    }
  }

  Future<void> login(String email, String password) async {
    final user = await _repo.login(email, password);
    if (!user.isStaff) {
      await ref.read(apiClientProvider).saveToken(null);
      throw ApiException("Ce compte ne gère aucun centre. Les clients utilisent l'application Lavpro.");
    }
    state = AuthSignedIn(user);
  }

  Future<void> logout() async {
    await ref.read(apiClientProvider).saveToken(null);
    ref.invalidate(selectedCenterProvider);
    state = const AuthSignedOut();
  }
}

final authProvider = NotifierProvider<AuthController, AuthState>(AuthController.new);
final currentUserProvider = Provider<AppUser?>((ref) {
  final s = ref.watch(authProvider);
  return s is AuthSignedIn ? s.user : null;
});

/// Centre géré actuellement sélectionné (le premier par défaut).
class SelectedCenter extends Notifier<int?> {
  @override
  int? build() => ref.watch(currentUserProvider)?.memberships.firstOrNull?.centerId;
  void select(int id) => state = id;
}

final selectedCenterProvider = NotifierProvider<SelectedCenter, int?>(SelectedCenter.new);

Membership? currentMembership(WidgetRef ref) {
  final id = ref.watch(selectedCenterProvider);
  return ref.watch(currentUserProvider)?.memberships.where((m) => m.centerId == id).firstOrNull;
}

class ThemeModeController extends Notifier<ThemeMode> {
  @override
  ThemeMode build() => ThemeMode.system;
  void set(ThemeMode m) => state = m;
}

final themeModeProvider = NotifierProvider<ThemeModeController, ThemeMode>(ThemeModeController.new);

// ---- Données du centre sélectionné ---------------------------------------------------
int _cid(Ref ref) {
  final id = ref.watch(selectedCenterProvider);
  if (id == null) throw ApiException('Aucun centre sélectionné');
  return id;
}

final centerInfoProvider = FutureProvider<ManagedCenter>((ref) => ref.watch(repoProvider).center(_cid(ref)));
final catalogProvider = FutureProvider<CenterCatalog>((ref) => ref.watch(repoProvider).catalog(_cid(ref)));
final occupancyProvider = FutureProvider<Occupancy>((ref) => ref.watch(repoProvider).occupancy(_cid(ref)));

/// Période du tableau de bord en jours (0 = aujourd'hui).
class DashboardPeriod extends Notifier<int> {
  @override
  int build() => 0;
  void set(int days) => state = days;
}

final dashboardPeriodProvider = NotifierProvider<DashboardPeriod, int>(DashboardPeriod.new);

final dashboardProvider = FutureProvider<DashboardData>((ref) {
  final days = ref.watch(dashboardPeriodProvider);
  final today = DateUtils.dateOnly(DateTime.now());
  return ref.watch(repoProvider).dashboard(_cid(ref), today.subtract(Duration(days: days)), today);
});

DateTime _day(DateTime d) => DateUtils.dateOnly(d);
final bookingsProvider = FutureProvider.family<List<StaffBooking>, DateTime>(
    (ref, day) => ref.watch(repoProvider).bookings(_cid(ref), _day(day)));
final washesProvider = FutureProvider.family<List<CenterWash>, DateTime>(
    (ref, day) => ref.watch(repoProvider).washes(_cid(ref), _day(day)));

/// À appeler après la validation d'un lavage pour rafraîchir les écrans.
void refreshActivity(WidgetRef ref) {
  ref.invalidate(dashboardProvider);
  ref.invalidate(occupancyProvider);
  ref.invalidate(washesProvider);
  ref.invalidate(bookingsProvider);
}

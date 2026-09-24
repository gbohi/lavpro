import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'state/providers.dart';
import 'ui/screens/auth/login_screen.dart';
import 'ui/screens/auth/register_screen.dart';
import 'ui/screens/auth/welcome_screen.dart';
import 'ui/screens/centers/booking_screen.dart';
import 'ui/screens/centers/center_detail_screen.dart';
import 'ui/screens/centers/centers_screen.dart';
import 'ui/screens/home/card_screen.dart';
import 'ui/screens/home/home_screen.dart';
import 'ui/screens/home/notifications_screen.dart';
import 'ui/screens/profile/bookings_screen.dart';
import 'ui/screens/profile/eco_screen.dart';
import 'ui/screens/profile/history_screen.dart';
import 'ui/screens/profile/profile_screen.dart';
import 'ui/screens/profile/referral_screen.dart';
import 'ui/screens/profile/vehicles_screen.dart';
import 'ui/screens/rewards/rewards_screen.dart';
import 'ui/screens/shell.dart';
import 'ui/screens/splash_screen.dart';
import 'ui/screens/staff/staff_scan_screen.dart';

/// Pont entre l'état d'authentification Riverpod et le rafraîchissement du routeur.
class _AuthListenable extends ChangeNotifier {
  _AuthListenable(Ref ref) {
    ref.listen(authProvider, (_, _) => notifyListeners());
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final listenable = _AuthListenable(ref);
  const publicRoutes = {'/welcome', '/login', '/register'};

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: listenable,
    redirect: (context, state) {
      final auth = ref.read(authProvider);
      final loc = state.matchedLocation;
      if (auth is AuthLoading) return loc == '/splash' ? null : '/splash';
      if (auth is AuthSignedOut) return publicRoutes.contains(loc) ? null : '/welcome';
      if (publicRoutes.contains(loc) || loc == '/splash') return '/home';
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, _) => const SplashScreen()),
      GoRoute(path: '/welcome', builder: (_, _) => const WelcomeScreen()),
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, s) => RegisterScreen(referralCode: s.uri.queryParameters['ref'])),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppShell(shell: shell),
        branches: [
          StatefulShellBranch(routes: [GoRoute(path: '/home', builder: (_, _) => const HomeScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/centers', builder: (_, _) => const CentersScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/card', builder: (_, _) => const CardScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/rewards', builder: (_, _) => const RewardsScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/profile', builder: (_, _) => const ProfileScreen())]),
        ],
      ),
      GoRoute(
        path: '/center/:id',
        builder: (_, s) => CenterDetailScreen(centerId: int.parse(s.pathParameters['id']!)),
        routes: [
          GoRoute(path: 'book', builder: (_, s) => BookingScreen(centerId: int.parse(s.pathParameters['id']!))),
        ],
      ),
      GoRoute(path: '/bookings', builder: (_, _) => const BookingsScreen()),
      GoRoute(path: '/history', builder: (_, _) => const HistoryScreen()),
      GoRoute(path: '/eco', builder: (_, _) => const EcoScreen()),
      GoRoute(path: '/referral', builder: (_, _) => const ReferralScreen()),
      GoRoute(path: '/notifications', builder: (_, _) => const NotificationsScreen()),
      GoRoute(path: '/vehicles', builder: (_, _) => const VehiclesScreen()),
      GoRoute(path: '/staff', builder: (_, _) => const StaffScanScreen()),
    ],
  );
});

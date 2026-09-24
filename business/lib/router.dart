import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'state/providers.dart';
import 'ui/screens/bookings_screen.dart';
import 'ui/screens/dashboard_screen.dart';
import 'ui/screens/login_screen.dart';
import 'ui/screens/more_screen.dart';
import 'ui/screens/scan_screen.dart';
import 'ui/screens/shell.dart';
import 'ui/screens/splash_screen.dart';
import 'ui/screens/validate_screen.dart';
import 'ui/screens/washes_screen.dart';

class _AuthListenable extends ChangeNotifier {
  _AuthListenable(Ref ref) {
    ref.listen(authProvider, (_, _) => notifyListeners());
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final listenable = _AuthListenable(ref);
  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: listenable,
    redirect: (context, state) {
      final auth = ref.read(authProvider);
      final loc = state.matchedLocation;
      if (auth is AuthLoading) return loc == '/splash' ? null : '/splash';
      if (auth is AuthSignedOut) return loc == '/login' ? null : '/login';
      if (loc == '/login' || loc == '/splash') return '/activity';
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, _) => const SplashScreen()),
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => BusinessShell(shell: shell),
        branches: [
          StatefulShellBranch(routes: [GoRoute(path: '/activity', builder: (_, _) => const DashboardScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/bookings', builder: (_, _) => const BookingsScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/scan', builder: (_, _) => const ScanScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/washes', builder: (_, _) => const WashesScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/more', builder: (_, _) => const MoreScreen())]),
        ],
      ),
      GoRoute(
        path: '/validate',
        builder: (_, s) => ValidateScreen(request: s.extra as ValidateRequest? ?? const ValidateRequest.walkIn()),
      ),
    ],
  );
});

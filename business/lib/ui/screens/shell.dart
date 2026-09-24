import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lavpro_core/lavpro_core.dart';

import '../widgets/brand.dart';

/// Navigation : barre du bas sur téléphone, rail latéral sur tablette.
class BusinessShell extends StatelessWidget {
  const BusinessShell({super.key, required this.shell});
  final StatefulNavigationShell shell;

  static const _items = [
    (Icons.space_dashboard_outlined, Icons.space_dashboard_rounded, 'Activité'),
    (Icons.event_note_outlined, Icons.event_note_rounded, 'Réservations'),
    (Icons.qr_code_scanner_rounded, Icons.qr_code_scanner_rounded, 'Scanner'),
    (Icons.local_car_wash_outlined, Icons.local_car_wash_rounded, 'Lavages'),
    (Icons.menu_rounded, Icons.menu_rounded, 'Plus'),
  ];

  void _go(int i) => shell.goBranch(i, initialLocation: i == shell.currentIndex);

  @override
  Widget build(BuildContext context) {
    if (context.isTablet) {
      return Scaffold(
        body: Row(children: [
          NavigationRail(
            selectedIndex: shell.currentIndex,
            onDestinationSelected: _go,
            extended: context.isDesktop,
            labelType: context.isDesktop ? NavigationRailLabelType.none : NavigationRailLabelType.all,
            leading: const Padding(padding: EdgeInsets.symmetric(vertical: 20), child: BusinessBadge()),
            indicatorColor: AppColors.primary.withValues(alpha: .12),
            destinations: [
              for (final (o, s, l) in _items)
                NavigationRailDestination(icon: Icon(o), selectedIcon: Icon(s, color: AppColors.primary), label: Text(l)),
            ],
          ),
          VerticalDivider(width: 1, color: context.borderColor),
          Expanded(child: shell),
        ]),
      );
    }
    return Scaffold(
      body: shell,
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(border: Border(top: BorderSide(color: context.borderColor))),
        child: NavigationBar(
          selectedIndex: shell.currentIndex,
          onDestinationSelected: _go,
          destinations: [
            for (final (i, item) in _items.indexed)
              NavigationDestination(
                icon: i == 2 ? const _ScanIcon() : Icon(item.$1),
                selectedIcon: i == 2 ? const _ScanIcon() : Icon(item.$2, color: AppColors.primary),
                label: item.$3,
              ),
          ],
        ),
      ),
    );
  }
}

class _ScanIcon extends StatelessWidget {
  const _ScanIcon();
  @override
  Widget build(BuildContext context) => Container(
        width: 50, height: 36,
        decoration: BoxDecoration(
          gradient: AppColors.gradient, borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: .35), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: const Icon(Icons.qr_code_scanner_rounded, color: Colors.white),
      );
}

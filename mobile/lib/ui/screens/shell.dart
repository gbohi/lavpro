import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lavpro_core/lavpro_core.dart';


/// Navigation principale : barre du bas sur mobile, rail latéral sur tablette / desktop.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.shell});
  final StatefulNavigationShell shell;

  static const _items = [
    (Icons.home_outlined, Icons.home_rounded, 'Accueil'),
    (Icons.explore_outlined, Icons.explore_rounded, 'Centres'),
    (Icons.qr_code_2_rounded, Icons.qr_code_2_rounded, 'Ma carte'),
    (Icons.redeem_outlined, Icons.redeem_rounded, 'Cadeaux'),
    (Icons.person_outline_rounded, Icons.person_rounded, 'Profil'),
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
            leading: Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Container(
                width: 48, height: 48,
                decoration: BoxDecoration(gradient: AppColors.gradient, borderRadius: BorderRadius.circular(15)),
                child: const Icon(Icons.water_drop_rounded, color: Colors.white),
              ),
            ),
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
                icon: i == 2 ? _CardIcon(selected: shell.currentIndex == 2) : Icon(item.$1),
                selectedIcon: i == 2 ? const _CardIcon(selected: true) : Icon(item.$2, color: AppColors.primary),
                label: item.$3,
              ),
          ],
        ),
      ),
    );
  }
}

class _CardIcon extends StatelessWidget {
  const _CardIcon({required this.selected});
  final bool selected;
  @override
  Widget build(BuildContext context) => Container(
        width: 46, height: 34,
        decoration: BoxDecoration(
          gradient: AppColors.gradient,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: selected ? .45 : .25), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: const Icon(Icons.qr_code_2_rounded, color: Colors.white, size: 22),
      );
}

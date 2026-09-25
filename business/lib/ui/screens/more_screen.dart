import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lavpro_core/lavpro_core.dart';

import '../../state/providers.dart';
import '../widgets/brand.dart';
import '../widgets/center_header.dart';

const permissionLabels = {
  'manage_team': "Gérer l'équipe",
  'manage_washers': 'Gérer les laveurs',
  'manage_catalog': 'Services et prix',
  'manage_rewards': 'Récompenses et promotions',
  'view_reports': "Chiffre d'affaires et rapports",
  'adjust_points': 'Ajuster les points',
  'cancel_washes': 'Annuler un lavage',
  'manage_settings': 'Paramètres du centre',
};

class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final membership = currentMembership(ref);
    final theme = ref.watch(themeModeProvider);
    if (user == null) return const SizedBox.shrink();
    final pad = context.pagePadding;
    return Scaffold(
      body: SafeArea(
        child: ListView(padding: EdgeInsets.fromLTRB(pad, 12, pad, 32), children: [
          MaxWidth(
            maxWidth: 760,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              GradientCard(
                gradient: AppColors.nightGradient,
                child: Row(children: [
                  Avatar(user.initials, size: 60),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(user.fullName, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
                      Text(user.email, style: TextStyle(color: Colors.white.withValues(alpha: .75))),
                      const SizedBox(height: 8),
                      Text(
                        '${membership?.role == 'owner' ? 'Propriétaire' : 'Gestionnaire'} · ${membership?.centerName ?? ''}',
                        style: const TextStyle(color: AppColors.cyan, fontWeight: FontWeight.w700, fontSize: 12),
                      ),
                    ]),
                  ),
                ]),
              ),
              if (user.memberships.length > 1) ...[
                const SizedBox(height: 14),
                AppCard(
                  onTap: () => pickCenter(context, ref),
                  child: Row(children: [
                    const IconBadge(Icons.swap_horiz_rounded, size: 40),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text('Changer de centre (${user.memberships.length})',
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                    ),
                    const Icon(Icons.chevron_right_rounded),
                  ]),
                ),
              ],
              if (can(ref, 'manage_washers')) ...[
                const SectionHeader('Mon équipe'),
                AppCard(
                  onTap: () => context.push('/washers'),
                  child: const Row(children: [
                    IconBadge(Icons.engineering_rounded, gradient: AppColors.ecoGradient, size: 40),
                    SizedBox(width: 14),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Laveurs', style: TextStyle(fontWeight: FontWeight.w800)),
                        Text('Ajouter, modifier, désactiver', style: TextStyle(fontSize: 12)),
                      ]),
                    ),
                    Icon(Icons.chevron_right_rounded),
                  ]),
                ),
              ],
              const SectionHeader('Mes droits'),
              AppCard(
                padding: const EdgeInsets.all(16),
                child: membership == null
                    ? const SizedBox.shrink()
                    : Wrap(spacing: 6, runSpacing: 6, children: [
                        if (membership.isOwner)
                          const Pill('Tous les droits (propriétaire)', icon: Icons.verified_rounded)
                        else if (membership.permissions.isEmpty)
                          const Pill('Validation des lavages uniquement', icon: Icons.task_alt_rounded)
                        else
                          for (final p in membership.permissions)
                            Pill(permissionLabels[p] ?? p, icon: Icons.check_rounded, color: AppColors.eco),
                      ]),
              ),
              const SectionHeader('Préférences'),
              AppCard(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: ListTile(
                  leading: const Icon(Icons.contrast_rounded),
                  title: const Text('Apparence', style: TextStyle(fontWeight: FontWeight.w700)),
                  trailing: SegmentedButton<ThemeMode>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(value: ThemeMode.light, icon: Icon(Icons.light_mode_rounded, size: 18)),
                      ButtonSegment(value: ThemeMode.system, icon: Icon(Icons.brightness_auto_rounded, size: 18)),
                      ButtonSegment(value: ThemeMode.dark, icon: Icon(Icons.dark_mode_rounded, size: 18)),
                    ],
                    selected: {theme},
                    onSelectionChanged: (s) => ref.read(themeModeProvider.notifier).set(s.first),
                  ),
                ),
              ),
              const SectionHeader('Configuration du centre'),
              AppCard(
                color: AppColors.primary.withValues(alpha: .06),
                child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(Icons.desktop_windows_rounded, color: AppColors.primary),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      "Services, prix et points, récompenses, promotions, équipe et rapports détaillés se "
                      "configurent depuis l'Espace Pro web, selon vos droits.",
                      style: TextStyle(fontWeight: FontWeight.w600, height: 1.4),
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(foregroundColor: AppColors.red),
                onPressed: () => ref.read(authProvider.notifier).logout(),
                icon: const Icon(Icons.logout_rounded),
                label: const Text('Se déconnecter'),
              ),
              const SizedBox(height: 20),
              const Center(child: BusinessLogo(light: false, size: 28)),
            ]),
          ),
        ]),
      ),
    );
  }
}

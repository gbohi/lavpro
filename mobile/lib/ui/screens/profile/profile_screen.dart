import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lavpro_core/lavpro_core.dart';

import '../../../state/providers.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  Future<void> _toggle(BuildContext context, WidgetRef ref, String key, bool value) async {
    try {
      await ref.read(authProvider.notifier).update({key: value});
    } catch (e) {
      if (context.mounted) showSnack(context, e.toString(), error: true);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final theme = ref.watch(themeModeProvider);
    if (user == null) return const SizedBox.shrink();
    final pad = context.pagePadding;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.fromLTRB(pad, 12, pad, 40),
          children: [
            MaxWidth(
              maxWidth: 760,
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                GradientCard(
                  gradient: AppColors.nightGradient,
                  child: Row(children: [
                    Avatar(user.initials, size: 64),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(user.fullName, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
                        Text(user.email, style: TextStyle(color: Colors.white.withValues(alpha: .75))),
                        const SizedBox(height: 8),
                        Pill('Code ${user.memberCode}', icon: Icons.badge_rounded, color: AppColors.cyan),
                      ]),
                    ),
                    IconButton(
                      onPressed: () => _editProfile(context, ref),
                      icon: const Icon(Icons.edit_rounded, color: Colors.white),
                    ),
                  ]),
                ),
                if (user.isStaff) ...[
                  const SizedBox(height: 16),
                  AppCard(
                    color: AppColors.primary.withValues(alpha: .06),
                    child: const Row(children: [
                      IconBadge(Icons.storefront_rounded, gradient: AppColors.nightGradient),
                      SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          'Vous gérez un centre de lavage ? Validez les lavages et suivez votre activité avec l\'application Lavpro Business.',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ]),
                  ),
                ],
                const SectionHeader('Mon activité'),
                _Menu(items: [
                  (Icons.directions_car_rounded, 'Mes véhicules', '/vehicles', AppColors.gradient),
                  (Icons.event_available_rounded, 'Mes réservations', '/bookings', AppColors.violetGradient),
                  (Icons.history_rounded, 'Historique des lavages & points', '/history', AppColors.nightGradient),
                  (Icons.eco_rounded, 'Mode Écolo', '/eco', AppColors.ecoGradient),
                  (Icons.card_giftcard_rounded, 'Parrainage', '/referral', AppColors.warmGradient),
                  (Icons.notifications_rounded, 'Notifications', '/notifications', AppColors.gradient),
                ]),
                const SectionHeader('Préférences'),
                AppCard(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Column(children: [
                    SwitchListTile(
                      value: user.notificationsEnabled,
                      onChanged: (v) => _toggle(context, ref, 'notifications_enabled', v),
                      title: const Text('Notifications', style: TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: const Text('Points gagnés, offres et rappels'),
                      secondary: const Icon(Icons.notifications_active_rounded),
                    ),
                    SwitchListTile(
                      value: user.weatherReminders,
                      onChanged: (v) => _toggle(context, ref, 'weather_reminders', v),
                      title: const Text('Rappels selon la météo', style: TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: const Text('Au bon moment, jamais avant la pluie'),
                      secondary: const Icon(Icons.wb_sunny_rounded),
                    ),
                    SwitchListTile(
                      value: user.ecoMode,
                      onChanged: (v) => _toggle(context, ref, 'eco_mode', v),
                      title: const Text('Mode Écolo', style: TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: const Text('Afficher mon impact environnemental'),
                      secondary: const Icon(Icons.eco_rounded),
                    ),
                    ListTile(
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
                  ]),
                ),
                const SizedBox(height: 24),
                OutlinedButton.icon(
                  onPressed: () => _changePassword(context, ref),
                  icon: const Icon(Icons.lock_reset_rounded),
                  label: const Text('Changer mon mot de passe'),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(foregroundColor: AppColors.red),
                  onPressed: () => ref.read(authProvider.notifier).logout(),
                  icon: const Icon(Icons.logout_rounded),
                  label: const Text('Se déconnecter'),
                ),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editProfile(BuildContext context, WidgetRef ref) async {
    final user = ref.read(currentUserProvider)!;
    final first = TextEditingController(text: user.firstName);
    final last = TextEditingController(text: user.lastName);
    final phone = TextEditingController(text: user.phone ?? '');
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (c) => Padding(
        padding: EdgeInsets.fromLTRB(24, 0, 24, MediaQuery.viewInsetsOf(c).bottom + 24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Mon profil', style: c.text.titleLarge),
          const SizedBox(height: 16),
          TextField(controller: first, decoration: const InputDecoration(labelText: 'Prénom')),
          const SizedBox(height: 12),
          TextField(controller: last, decoration: const InputDecoration(labelText: 'Nom')),
          const SizedBox(height: 12),
          TextField(controller: phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Téléphone')),
          const SizedBox(height: 20),
          GradientButton(label: 'Enregistrer', onPressed: () => Navigator.pop(c, true)),
        ]),
      ),
    );
    if (ok == true) {
      await ref.read(authProvider.notifier).update(
          {'first_name': first.text.trim(), 'last_name': last.text.trim(), 'phone': phone.text.trim()});
      if (context.mounted) showSnack(context, 'Profil mis à jour');
    }
  }

  Future<void> _changePassword(BuildContext context, WidgetRef ref) async {
    final current = TextEditingController();
    final next = TextEditingController();
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (c) => Padding(
        padding: EdgeInsets.fromLTRB(24, 0, 24, MediaQuery.viewInsetsOf(c).bottom + 24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Mot de passe', style: c.text.titleLarge),
          const SizedBox(height: 16),
          TextField(controller: current, obscureText: true, decoration: const InputDecoration(labelText: 'Mot de passe actuel')),
          const SizedBox(height: 12),
          TextField(controller: next, obscureText: true, decoration: const InputDecoration(labelText: 'Nouveau mot de passe')),
          const SizedBox(height: 20),
          GradientButton(label: 'Valider', onPressed: () => Navigator.pop(c, true)),
        ]),
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(repoProvider).changePassword(current.text, next.text);
      if (context.mounted) showSnack(context, 'Mot de passe modifié');
    } catch (e) {
      if (context.mounted) showSnack(context, e.toString(), error: true);
    }
  }
}

class _Menu extends StatelessWidget {
  const _Menu({required this.items});
  final List<(IconData, String, String, Gradient)> items;
  @override
  Widget build(BuildContext context) => AppCard(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(children: [
          for (final (icon, label, path, g) in items)
            ListTile(
              onTap: () => context.push(path),
              leading: IconBadge(icon, gradient: g, size: 38),
              title: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
              trailing: const Icon(Icons.chevron_right_rounded),
            ),
        ]),
      );
}

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lavpro_core/lavpro_core.dart';

import '../../models/staff.dart';
import '../../state/providers.dart';

/// Gestion des laveurs depuis le téléphone (droit « Gérer les laveurs »).
class WashersScreen extends ConsumerWidget {
  const WashersScreen({super.key});

  Future<void> _edit(BuildContext context, WidgetRef ref, [Washer? w]) async {
    final first = TextEditingController(text: w?.firstName ?? '');
    final last = TextEditingController(text: w?.lastName ?? '');
    final phone = TextEditingController(text: w?.phone ?? '');
    final commission = TextEditingController(text: w == null || w.commissionRate == 0 ? '' : _pct(w.commissionRate));
    var active = w?.isActive ?? true;
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (c) => StatefulBuilder(
        builder: (c, setState) => Padding(
          padding: EdgeInsets.fromLTRB(24, 0, 24, MediaQuery.viewInsetsOf(c).bottom + 24),
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text(w == null ? 'Nouveau laveur' : 'Modifier le laveur', style: c.text.titleLarge),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(
                  child: TextField(controller: first, textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(labelText: 'Prénom *')),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(controller: last, textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(labelText: 'Nom')),
                ),
              ]),
              const SizedBox(height: 12),
              TextField(controller: phone, keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Téléphone', prefixIcon: Icon(Icons.phone_rounded))),
              const SizedBox(height: 12),
              TextField(
                controller: commission,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Commission (%)', prefixIcon: Icon(Icons.percent_rounded),
                    helperText: 'Pourcentage de la valeur des lavages réalisés'),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: active,
                onChanged: (v) => setState(() => active = v),
                title: const Text('Actif', style: TextStyle(fontWeight: FontWeight.w700)),
                subtitle: const Text('Un laveur inactif n\'est plus proposé lors de la validation'),
              ),
              const SizedBox(height: 12),
              GradientButton(label: 'Enregistrer', icon: Icons.check_rounded, onPressed: () => Navigator.pop(c, true)),
            ]),
          ),
        ),
      ),
    );
    if (ok != true) return;
    if (first.text.trim().isEmpty) {
      if (context.mounted) showSnack(context, 'Le prénom est obligatoire', error: true);
      return;
    }
    final rate = double.tryParse(commission.text.replaceAll(',', '.').trim()) ?? 0;
    if (rate < 0 || rate > 100) {
      if (context.mounted) showSnack(context, 'La commission doit être comprise entre 0 et 100 %', error: true);
      return;
    }
    try {
      await ref.read(repoProvider).saveWasher(ref.read(selectedCenterProvider)!, washerId: w?.id,
          firstName: first.text.trim(), lastName: last.text.trim(), phone: phone.text.trim(), commissionRate: rate,
          isActive: active);
      ref.invalidate(washersProvider);
      ref.invalidate(catalogProvider); // la liste proposée à la validation change
      if (context.mounted) showSnack(context, w == null ? 'Laveur ajouté' : 'Laveur mis à jour');
    } catch (e) {
      if (context.mounted) showSnack(context, e.toString(), error: true);
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, Washer w) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Supprimer ${w.fullName} ?'),
        content: const Text("S'il a déjà effectué des lavages, il sera simplement désactivé pour conserver l'historique."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Annuler')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.red),
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(repoProvider).deleteWasher(ref.read(selectedCenterProvider)!, w.id);
      ref.invalidate(washersProvider);
      ref.invalidate(catalogProvider);
    } catch (e) {
      if (context.mounted) showSnack(context, e.toString(), error: true);
    }
  }

  static String _pct(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final washers = ref.watch(washersProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Laveurs')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(context, ref),
        icon: const Icon(Icons.person_add_rounded),
        label: const Text('Ajouter'),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(washersProvider.future),
        child: ListView(padding: EdgeInsets.fromLTRB(context.pagePadding, 8, context.pagePadding, 100), children: [
          MaxWidth(
            maxWidth: 720,
            child: AsyncView(
              value: washers,
              onRetry: () => ref.invalidate(washersProvider),
              builder: (list) {
                if (list.isEmpty) {
                  return const EmptyState(icon: Icons.engineering_rounded, title: 'Aucun laveur',
                      message: 'Ajoutez vos laveurs pour savoir qui a lavé chaque véhicule.');
                }
                final sorted = [...list]..sort((a, b) => a.isActive == b.isActive
                    ? a.fullName.compareTo(b.fullName) : (a.isActive ? -1 : 1));
                return Column(children: [
                  for (final (i, w) in sorted.indexed)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Opacity(
                        opacity: w.isActive ? 1 : .55,
                        child: AppCard(
                          onTap: () => _edit(context, ref, w),
                          padding: const EdgeInsets.fromLTRB(14, 12, 4, 12),
                          child: Row(children: [
                            Avatar(w.initial, size: 44, gradient: AppColors.ecoGradient),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(w.fullName, style: const TextStyle(fontWeight: FontWeight.w800)),
                                Text(
                                  [w.phone ?? 'Pas de téléphone', if (w.commissionRate > 0) 'commission ${_pct(w.commissionRate)} %']
                                      .join(' · '),
                                  style: TextStyle(color: context.muted, fontSize: 12),
                                ),
                              ]),
                            ),
                            if (!w.isActive) const Pill('Inactif', color: Colors.grey),
                            IconButton(
                              tooltip: 'Supprimer',
                              onPressed: () => _delete(context, ref, w),
                              icon: const Icon(Icons.delete_outline_rounded),
                            ),
                          ]),
                        ),
                      ).animate().fadeIn(delay: (30 * i).ms),
                    ),
                ]);
              },
            ),
          ),
        ]),
      ),
    );
  }
}

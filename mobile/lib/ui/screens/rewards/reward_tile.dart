import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lavpro_core/lavpro_core.dart';

import '../../../state/providers.dart';

/// Tuile de récompense avec échange des points.
class RewardTile extends ConsumerWidget {
  const RewardTile(this.r, {super.key});
  final Reward r;

  Future<void> _redeem(BuildContext context, WidgetRef ref) async {
    final balance = ref.read(accountsProvider).value?.where((a) => a.centerId == r.centerId).firstOrNull?.balance ?? 0;
    int? vehicleId = r.vehicleCosts.where((c) => c.pointsCost <= balance).firstOrNull?.vehicleTypeId;
    final ok = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (c) => StatefulBuilder(
        builder: (c, setState) {
          final cost = r.vehicleCosts.isEmpty
              ? r.pointsCost
              : r.vehicleCosts.where((v) => v.vehicleTypeId == vehicleId).firstOrNull?.pointsCost;
          return Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              IconBadge(rewardIcon(r.category), gradient: r.isWash ? AppColors.gradient : AppColors.violetGradient, size: 70),
              const SizedBox(height: 16),
              Text(r.name, style: c.text.titleLarge, textAlign: TextAlign.center),
              if (r.isWash) ...[
                const SizedBox(height: 4),
                Text('Lavage offert : ${r.serviceName}', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700)),
              ],
              if (r.vehicleCosts.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text('Pour quel véhicule ?', style: TextStyle(color: c.muted, fontWeight: FontWeight.w600)),
                const SizedBox(height: 10),
                Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.center, children: [
                  for (final v in r.vehicleCosts)
                    ChoiceChip(
                      label: Text('${v.vehicleTypeName} · ${fmtNum(v.pointsCost)} pts'),
                      selected: v.vehicleTypeId == vehicleId,
                      showCheckmark: false,
                      selectedColor: AppColors.primary,
                      labelStyle: TextStyle(color: v.vehicleTypeId == vehicleId ? Colors.white : null, fontWeight: FontWeight.w700),
                      onSelected: v.pointsCost > balance ? null : (_) => setState(() => vehicleId = v.vehicleTypeId),
                    ),
                ]),
              ],
              const SizedBox(height: 12),
              Text(
                cost == null
                    ? 'Choisissez le type de véhicule.'
                    : 'Échanger ${fmtNum(cost)} points contre cette récompense ?${r.isWash ? '\nPrésentez ensuite votre carte lors du lavage.' : ''}',
                textAlign: TextAlign.center, style: TextStyle(color: c.muted),
              ),
              const SizedBox(height: 22),
              GradientButton(label: 'Confirmer l\'échange', icon: Icons.redeem_rounded,
                  onPressed: cost == null ? null : () => Navigator.pop(c, true)),
              const SizedBox(height: 8),
              TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Annuler')),
            ]),
          );
        },
      ),
    );
    if (ok != true) return;
    try {
      final red = await ref.read(repoProvider).redeem(r.id, vehicleTypeId: r.vehicleCosts.isEmpty ? null : vehicleId);
      refreshLoyalty(ref);
      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        builder: (c) => AlertDialog(
          icon: const Icon(Icons.celebration_rounded, color: AppColors.amber, size: 48),
          title: const Text('Récompense débloquée !'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(red.isWash ? 'Présentez votre carte Lavpro lors de votre lavage. Votre code :' : 'Présentez ce code au centre pour la retirer :',
                textAlign: TextAlign.center),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: .1), borderRadius: BorderRadius.circular(14)),
              child: Text(red.code, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: 3, color: AppColors.primary)),
            ),
          ]),
          actions: [FilledButton(onPressed: () => Navigator.pop(c), child: const Text('Super !'))],
        ),
      );
    } catch (e) {
      if (context.mounted) showSnack(context, e.toString(), error: true);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locked = !r.affordable;
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          height: 96,
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
            gradient: r.imageUrl == null ? (r.ecoMinLiters != null ? AppColors.ecoGradient : AppColors.gradient) : null,
            image: r.imageUrl == null ? null : DecorationImage(image: NetworkImage(r.imageUrl!), fit: BoxFit.cover),
          ),
          child: Stack(children: [
            if (r.imageUrl == null) Center(child: Icon(rewardIcon(r.category), color: Colors.white, size: 44)),
            Positioned(
              left: 10, bottom: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: Colors.black.withValues(alpha: .55), borderRadius: BorderRadius.circular(20)),
                child: Text('${r.vehicleCosts.length > 1 ? 'dès ' : ''}${fmtNum(r.minCost)} pts', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
              ),
            ),
            if (r.ecoMinLiters != null)
              const Positioned(right: 10, top: 10, child: Pill('Écolo', icon: Icons.eco_rounded, color: AppColors.eco, filled: true)),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(r.name, style: const TextStyle(fontWeight: FontWeight.w800), maxLines: 1, overflow: TextOverflow.ellipsis),
            if (r.isWash)
              Text('Lavage offert · ${r.serviceName}', maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(r.lockedReason ?? (r.description ?? 'Disponible'),
                style: TextStyle(color: locked ? context.muted : AppColors.eco, fontSize: 12, fontWeight: FontWeight.w600),
                maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(42)),
                onPressed: locked ? null : () => _redeem(context, ref),
                icon: Icon(locked ? Icons.lock_rounded : Icons.redeem_rounded, size: 18),
                label: Text(locked ? 'Verrouillé' : 'Échanger'),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}

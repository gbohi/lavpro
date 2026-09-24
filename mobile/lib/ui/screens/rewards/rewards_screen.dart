import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lavpro_core/lavpro_core.dart';

import '../../../state/providers.dart';
import 'reward_tile.dart';

class RewardsScreen extends ConsumerWidget {
  const RewardsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accounts = ref.watch(accountsProvider);
    final redemptions = ref.watch(redemptionsProvider);
    final pad = context.pagePadding;
    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async => refreshLoyalty(ref),
          child: ListView(
            padding: EdgeInsets.fromLTRB(pad, 12, pad, 32),
            children: [
              MaxWidth(
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Text('Récompenses', style: context.text.headlineSmall),
                  const SizedBox(height: 4),
                  Text('Échangez vos points contre des cadeaux dans vos centres.', style: TextStyle(color: context.muted)),
                  redemptions.maybeWhen(
                    data: (list) {
                      final pending = list.where((r) => r.status == 'pending').toList();
                      if (pending.isEmpty) return const SizedBox.shrink();
                      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        const SectionHeader('À retirer au centre'),
                        for (final r in pending) _PendingRedemption(r),
                      ]);
                    },
                    orElse: () => const SizedBox.shrink(),
                  ),
                  AsyncView(
                    value: accounts,
                    onRetry: () => ref.invalidate(accountsProvider),
                    builder: (list) => list.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.only(top: 40),
                            child: EmptyState(
                              icon: Icons.redeem_rounded,
                              title: 'Pas encore de récompenses',
                              message: 'Faites laver votre véhicule dans un centre partenaire pour débloquer ses cadeaux.',
                              action: FilledButton(onPressed: () => context.go('/centers'), child: const Text('Voir les centres')),
                            ),
                          )
                        : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                            for (final a in list) _CenterRewards(a),
                          ]),
                  ),
                  redemptions.maybeWhen(
                    data: (list) {
                      final past = list.where((r) => r.status != 'pending').toList();
                      if (past.isEmpty) return const SizedBox.shrink();
                      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        const SectionHeader('Historique'),
                        AppCard(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          child: Column(children: [
                            for (final r in past)
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: Icon(r.status == 'used' ? Icons.check_circle_rounded : Icons.cancel_rounded,
                                    color: r.status == 'used' ? AppColors.eco : context.muted),
                                title: Text(r.rewardName ?? '', style: const TextStyle(fontWeight: FontWeight.w700)),
                                subtitle: Text('${r.centerName} · ${fmtDate(r.usedAt ?? r.createdAt)}'),
                                trailing: Text('-${r.points}', style: TextStyle(color: context.muted, fontWeight: FontWeight.w700)),
                              ),
                          ]),
                        ),
                      ]);
                    },
                    orElse: () => const SizedBox.shrink(),
                  ),
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PendingRedemption extends ConsumerWidget {
  const _PendingRedemption(this.r);
  final Redemption r;
  @override
  Widget build(BuildContext context, WidgetRef ref) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: GradientCard(
          gradient: AppColors.violetGradient,
          padding: const EdgeInsets.all(18),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(r.rewardName ?? '', style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800)),
                Text(r.centerName ?? '', style: TextStyle(color: Colors.white.withValues(alpha: .85))),
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: r.code));
                    showSnack(context, 'Code copié');
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
                    child: Text(r.code, style: const TextStyle(fontWeight: FontWeight.w800, letterSpacing: 2.5, color: AppColors.violet, fontSize: 18)),
                  ),
                ),
              ]),
            ),
            IconButton(
              tooltip: 'Annuler et récupérer mes points',
              onPressed: () async {
                try {
                  await ref.read(repoProvider).cancelRedemption(r.id);
                  refreshLoyalty(ref);
                  if (context.mounted) showSnack(context, 'Points recrédités');
                } catch (e) {
                  if (context.mounted) showSnack(context, e.toString(), error: true);
                }
              },
              icon: const Icon(Icons.undo_rounded, color: Colors.white),
            ),
          ]),
        ),
      );
}

class _CenterRewards extends ConsumerWidget {
  const _CenterRewards(this.a);
  final LoyaltyAccount a;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rewards = ref.watch(centerRewardsProvider(a.centerId));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SectionHeader(a.centerName, action: '${fmtNum(a.balance)} pts', onAction: () => context.push('/center/${a.centerId}')),
      rewards.when(
        data: (list) => list.isEmpty
            ? Text('Aucune récompense publiée pour le moment.', style: TextStyle(color: context.muted))
            : SizedBox(
                height: 262,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: list.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 12),
                  itemBuilder: (_, i) => SizedBox(width: 230, child: RewardTile(list[i])),
                ),
              ),
        loading: () => const SkeletonList(count: 1, height: 200),
        error: (e, _) => Text(e.toString()),
      ),
    ]);
  }
}

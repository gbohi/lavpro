import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format.dart';
import '../../../core/responsive.dart';
import '../../../core/theme.dart';
import '../../../state/providers.dart';
import '../../widgets/common.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => DefaultTabController(
        length: 2,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Historique'),
            bottom: const TabBar(tabs: [Tab(text: 'Lavages'), Tab(text: 'Points')]),
          ),
          body: TabBarView(children: [_Washes(), _Points()]),
        ),
      );
}

class _Washes extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) => RefreshIndicator(
        onRefresh: () => ref.refresh(washesProvider.future),
        child: ListView(padding: EdgeInsets.all(context.pagePadding), children: [
          MaxWidth(
            maxWidth: 760,
            child: AsyncView(
              value: ref.watch(washesProvider),
              builder: (list) => list.isEmpty
                  ? const EmptyState(icon: Icons.local_car_wash_rounded, title: 'Aucun lavage pour le moment')
                  : Column(children: [
                      for (final w in list)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: AppCard(
                            padding: const EdgeInsets.all(14),
                            child: Row(children: [
                              const IconBadge(Icons.local_car_wash_rounded, size: 42),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text('${w.serviceName} · ${w.vehicleTypeName}', style: const TextStyle(fontWeight: FontWeight.w800)),
                                  Text('${w.centerName} · ${fmtDateTime(w.createdAt)}', style: TextStyle(color: context.muted, fontSize: 12)),
                                  if (w.washerName != null)
                                    Text('Lavé par ${w.washerName}', style: TextStyle(color: context.muted, fontSize: 12)),
                                ]),
                              ),
                              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                                Text('+${w.points}', style: const TextStyle(color: AppColors.eco, fontWeight: FontWeight.w800, fontSize: 16)),
                                if (w.waterSaved > 0)
                                  Text('💧 ${w.waterSaved.round()} L', style: TextStyle(color: context.muted, fontSize: 11)),
                              ]),
                            ]),
                          ),
                        ),
                    ]),
            ),
          ),
        ]),
      );
}

class _Points extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) => RefreshIndicator(
        onRefresh: () => ref.refresh(transactionsProvider.future),
        child: ListView(padding: EdgeInsets.all(context.pagePadding), children: [
          MaxWidth(
            maxWidth: 760,
            child: AsyncView(
              value: ref.watch(transactionsProvider),
              builder: (list) => list.isEmpty
                  ? const EmptyState(icon: Icons.stars_rounded, title: 'Aucun mouvement de points')
                  : AppCard(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      child: Column(children: [
                        for (final t in list)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: CircleAvatar(
                              backgroundColor: (t.points >= 0 ? AppColors.eco : AppColors.violet).withValues(alpha: .12),
                              child: Icon(t.points >= 0 ? Icons.add_rounded : Icons.redeem_rounded,
                                  color: t.points >= 0 ? AppColors.eco : AppColors.violet),
                            ),
                            title: Text(t.label, style: const TextStyle(fontWeight: FontWeight.w700)),
                            subtitle: Text([t.note, t.centerName, fmtDate(t.createdAt)].whereType<String>().join(' · '),
                                maxLines: 2, overflow: TextOverflow.ellipsis),
                            trailing: Text('${t.points > 0 ? '+' : ''}${t.points}',
                                style: TextStyle(
                                    fontWeight: FontWeight.w800, fontSize: 16,
                                    color: t.points >= 0 ? AppColors.eco : AppColors.violet)),
                          ),
                      ]),
                    ),
            ),
          ),
        ]),
      );
}

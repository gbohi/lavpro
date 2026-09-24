import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lavpro_core/lavpro_core.dart';

import '../../state/providers.dart';
import '../widgets/brand.dart';
import '../widgets/center_header.dart';

/// Lavages de la journée : qui a lavé quoi, pour qui, et combien.
class WashesScreen extends ConsumerStatefulWidget {
  const WashesScreen({super.key});
  @override
  ConsumerState<WashesScreen> createState() => _WashesScreenState();
}

class _WashesScreenState extends ConsumerState<WashesScreen> {
  DateTime _day = DateUtils.dateOnly(DateTime.now());

  @override
  Widget build(BuildContext context) {
    final washes = ref.watch(washesProvider(_day));
    final currency = ref.watch(centerInfoProvider).value?.currency ?? '';
    final pad = context.pagePadding;
    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => ref.refresh(washesProvider(_day).future),
          child: ListView(padding: EdgeInsets.fromLTRB(pad, 12, pad, 32), children: [
            MaxWidth(
              maxWidth: 760,
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const CenterHeader(title: 'Lavages'),
                const SizedBox(height: 16),
                DayPicker(day: _day, onChanged: (d) => setState(() => _day = DateUtils.dateOnly(d))),
                const SizedBox(height: 16),
                AsyncView(
                  value: washes,
                  onRetry: () => ref.invalidate(washesProvider(_day)),
                  builder: (list) {
                    if (list.isEmpty) {
                      return const EmptyState(icon: Icons.local_car_wash_rounded, title: 'Aucun lavage ce jour');
                    }
                    final total = list.fold<double>(0, (a, w) => a + w.price);
                    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      Row(children: [
                        Expanded(child: _Total('${list.length}', 'lavages')),
                        const SizedBox(width: 12),
                        Expanded(flex: 2, child: _Total(fmtMoney(total, currency), 'encaissés')),
                      ]),
                      const SizedBox(height: 14),
                      for (final w in list)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: AppCard(
                            padding: const EdgeInsets.all(14),
                            child: Row(children: [
                              Column(children: [
                                Text(fmtTime(w.createdAt), style: const TextStyle(fontWeight: FontWeight.w800)),
                              ]),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text(w.clientName ?? 'Client de passage', style: const TextStyle(fontWeight: FontWeight.w800)),
                                  Text('${w.serviceName} · ${w.vehicleTypeName}${w.plate != null ? ' · ${w.plate}' : ''}',
                                      style: TextStyle(color: context.muted, fontSize: 12)),
                                  Text(
                                    [if (w.washerName != null) 'Lavé par ${w.washerName}', if (w.validatedBy != null) 'validé par ${w.validatedBy}']
                                        .join(' · '),
                                    style: TextStyle(color: context.muted, fontSize: 11),
                                  ),
                                ]),
                              ),
                              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                                switch (w.paymentMethod) {
                                  'reward' => const Pill('Offert', icon: Icons.redeem_rounded, color: AppColors.eco),
                                  'points' => Pill('${w.pointsSpent} pts', icon: Icons.stars_rounded, color: AppColors.violet),
                                  _ => Text(fmtMoney(w.price, currency), style: const TextStyle(fontWeight: FontWeight.w800)),
                                },
                                if (w.points > 0)
                                  Text('+${w.points} pts', style: const TextStyle(color: AppColors.eco, fontWeight: FontWeight.w700, fontSize: 12)),
                              ]),
                            ]),
                          ),
                        ),
                    ]);
                  },
                ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

class _Total extends StatelessWidget {
  const _Total(this.value, this.label);
  final String value;
  final String label;
  @override
  Widget build(BuildContext context) => AppCard(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          FittedBox(child: Text(value, style: context.text.titleLarge?.copyWith(fontWeight: FontWeight.w800))),
          Text(label, style: TextStyle(color: context.muted, fontSize: 12)),
        ]),
      );
}

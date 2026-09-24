import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lavpro_core/lavpro_core.dart';

import '../../../state/providers.dart';

class BookingsScreen extends ConsumerWidget {
  const BookingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookings = ref.watch(bookingsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Mes réservations')),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(bookingsProvider.future),
        child: ListView(
          padding: EdgeInsets.all(context.pagePadding),
          children: [
            MaxWidth(
              maxWidth: 760,
              child: AsyncView(
                value: bookings,
                onRetry: () => ref.invalidate(bookingsProvider),
                builder: (list) {
                  final upcoming = list.where((b) => b.isUpcoming).toList()..sort((a, b) => a.start.compareTo(b.start));
                  final past = list.where((b) => !b.isUpcoming).toList();
                  if (list.isEmpty) {
                    return EmptyState(
                      icon: Icons.event_busy_rounded, title: 'Aucune réservation',
                      message: 'Réservez un créneau pour ne plus faire la queue.',
                      action: FilledButton(onPressed: () => context.go('/centers'), child: const Text('Choisir un centre')),
                    );
                  }
                  return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    if (upcoming.isNotEmpty) ...[
                      Text('À venir', style: context.text.titleLarge),
                      const SizedBox(height: 12),
                      for (final b in upcoming) _BookingCard(b, upcoming: true),
                    ],
                    if (past.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Text('Passées', style: context.text.titleLarge),
                      const SizedBox(height: 12),
                      for (final b in past) _BookingCard(b),
                    ],
                  ]);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BookingCard extends ConsumerWidget {
  const _BookingCard(this.b, {this.upcoming = false});
  final Booking b;
  final bool upcoming;

  Color get _color => switch (b.status) {
        'completed' => AppColors.eco,
        'cancelled' || 'no_show' => AppColors.red,
        _ => AppColors.primary,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: AppCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                width: 58, padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  gradient: upcoming ? AppColors.gradient : null,
                  color: upcoming ? null : context.borderColor,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(children: [
                  Text('${b.start.day}', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: upcoming ? Colors.white : null)),
                  Text(fmtDateShort(b.start).split(' ').last.toUpperCase(),
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: upcoming ? Colors.white70 : context.muted)),
                ]),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(b.centerName ?? '', style: const TextStyle(fontWeight: FontWeight.w800)),
                  Text('${b.serviceName} · ${b.vehicleTypeName}', style: TextStyle(color: context.muted, fontSize: 13)),
                  Text('${fmtTime(b.start)} – ${fmtTime(b.end)}', style: const TextStyle(fontWeight: FontWeight.w700)),
                ]),
              ),
              Pill(b.statusLabel, color: _color),
            ]),
            if (upcoming) ...[
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(42)),
                    onPressed: () => context.push('/center/${b.centerId}'),
                    child: const Text('Voir le centre'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(42), foregroundColor: AppColors.red),
                    onPressed: () async {
                      try {
                        await ref.read(repoProvider).cancelBooking(b.id);
                        ref.invalidate(bookingsProvider);
                        if (context.mounted) showSnack(context, 'Réservation annulée');
                      } catch (e) {
                        if (context.mounted) showSnack(context, e.toString(), error: true);
                      }
                    },
                    child: const Text('Annuler'),
                  ),
                ),
              ]),
            ],
          ]),
        ),
      );
}

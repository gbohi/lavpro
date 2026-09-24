import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lavpro_core/lavpro_core.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/staff.dart';
import '../../state/providers.dart';
import '../widgets/brand.dart';
import '../widgets/center_header.dart';
import 'validate_screen.dart';

/// Réservations du jour : accueillir (valider le lavage), marquer absent, annuler.
class BookingsScreen extends ConsumerStatefulWidget {
  const BookingsScreen({super.key});
  @override
  ConsumerState<BookingsScreen> createState() => _BookingsScreenState();
}

class _BookingsScreenState extends ConsumerState<BookingsScreen> {
  DateTime _day = DateUtils.dateOnly(DateTime.now());

  Future<void> _setStatus(StaffBooking b, String status, String confirm) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(confirm),
        content: Text('${b.clientName} · ${fmtTime(b.start)} · ${b.serviceName}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Retour')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Confirmer')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(repoProvider).setBookingStatus(ref.read(selectedCenterProvider)!, b.id, status);
      ref.invalidate(bookingsProvider(_day));
      ref.invalidate(occupancyProvider);
      if (mounted) showSnack(context, 'Réservation mise à jour');
    } catch (e) {
      if (mounted) showSnack(context, e.toString(), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bookings = ref.watch(bookingsProvider(_day));
    final pad = context.pagePadding;
    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => ref.refresh(bookingsProvider(_day).future),
          child: ListView(padding: EdgeInsets.fromLTRB(pad, 12, pad, 32), children: [
            MaxWidth(
              maxWidth: 760,
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const CenterHeader(title: 'Réservations'),
                const SizedBox(height: 16),
                DayPicker(day: _day, onChanged: (d) => setState(() => _day = DateUtils.dateOnly(d))),
                const SizedBox(height: 16),
                AsyncView(
                  value: bookings,
                  onRetry: () => ref.invalidate(bookingsProvider(_day)),
                  builder: (list) {
                    if (list.isEmpty) {
                      return const EmptyState(icon: Icons.event_busy_rounded, title: 'Aucune réservation',
                          message: 'Les créneaux réservés par vos clients apparaîtront ici.');
                    }
                    final active = list.where((b) => b.isActive).length;
                    final done = list.where((b) => b.status == 'completed').length;
                    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      Wrap(spacing: 8, runSpacing: 8, children: [
                        Pill('${list.length} au total'),
                        Pill('$active à venir', color: AppColors.amber),
                        Pill('$done terminée(s)', color: AppColors.eco),
                      ]),
                      const SizedBox(height: 14),
                      for (final b in list) _BookingCard(b: b, onStatus: _setStatus),
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

class _BookingCard extends StatelessWidget {
  const _BookingCard({required this.b, required this.onStatus});
  final StaffBooking b;
  final Future<void> Function(StaffBooking, String, String) onStatus;

  Color get _color => switch (b.status) {
        'completed' => AppColors.eco,
        'cancelled' || 'no_show' => AppColors.red,
        _ => AppColors.primary,
      };

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Opacity(
          opacity: b.isActive || b.status == 'completed' ? 1 : .55,
          child: AppCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                Column(children: [
                  Text(fmtTime(b.start), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                  Text(fmtTime(b.end), style: TextStyle(color: context.muted, fontSize: 12)),
                ]),
                const SizedBox(width: 14),
                Container(width: 4, height: 48, decoration: BoxDecoration(gradient: AppColors.gradient, borderRadius: BorderRadius.circular(4))),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(b.clientName, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                    Text('${b.serviceName} · ${b.vehicleTypeName}', style: TextStyle(color: context.muted, fontSize: 13)),
                    if (b.note != null && b.note!.isNotEmpty)
                      Text('« ${b.note} »', style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 12)),
                  ]),
                ),
                Pill(b.statusLabel, color: _color),
              ]),
              if (b.isActive) ...[
                const SizedBox(height: 14),
                Row(children: [
                  Expanded(
                    flex: 2,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(44)),
                      onPressed: () => context.push('/validate', extra: ValidateRequest.booking(b)),
                      icon: const Icon(Icons.local_car_wash_rounded, size: 18),
                      label: const Text('Accueillir'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (b.clientPhone != null)
                    IconButton.outlined(
                      tooltip: 'Appeler',
                      onPressed: () => launchUrl(Uri.parse('tel:${b.clientPhone}')),
                      icon: const Icon(Icons.call_rounded),
                    ),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert_rounded),
                    onSelected: (v) => v == 'no_show'
                        ? onStatus(b, 'no_show', 'Marquer le client absent ?')
                        : onStatus(b, 'cancelled', 'Annuler cette réservation ?'),
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'no_show', child: ListTile(leading: Icon(Icons.person_off_rounded), title: Text('Client absent'))),
                      PopupMenuItem(value: 'cancelled', child: ListTile(leading: Icon(Icons.cancel_rounded, color: AppColors.red), title: Text('Annuler'))),
                    ],
                  ),
                ]),
              ],
            ]),
          ),
        ),
      );
}

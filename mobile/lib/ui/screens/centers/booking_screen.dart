import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/format.dart';
import '../../../core/responsive.dart';
import '../../../core/theme.dart';
import '../../../models/center.dart';
import '../../../state/providers.dart';
import '../../widgets/common.dart';
import '../../widgets/icons.dart';

/// Réservation d'un créneau pour éviter les files d'attente.
class BookingScreen extends ConsumerStatefulWidget {
  const BookingScreen({super.key, required this.centerId});
  final int centerId;
  @override
  ConsumerState<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends ConsumerState<BookingScreen> {
  int? _vehicleId;
  int? _serviceId;
  DateTime _day = DateTime.now();
  Slot? _slot;
  Future<List<Slot>>? _slots;
  bool _saving = false;
  final _note = TextEditingController();

  void _loadSlots() {
    if (_serviceId == null) return;
    setState(() {
      _slot = null;
      _slots = ref.read(repoProvider).slots(widget.centerId, _day, _serviceId!);
    });
  }

  Future<void> _confirm(WashCenter center) async {
    setState(() => _saving = true);
    try {
      await ref.read(repoProvider).book(centerId: widget.centerId, serviceId: _serviceId!, vehicleTypeId: _vehicleId!,
          slot: _slot!, note: _note.text.trim().isEmpty ? null : _note.text.trim());
      ref.invalidate(bookingsProvider);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (c) => AlertDialog(
          icon: const Icon(Icons.event_available_rounded, color: AppColors.eco, size: 52),
          title: const Text('Créneau réservé !'),
          content: Text('Rendez-vous ${fmtDayLong(_slot!.start)} à ${fmtTime(_slot!.start)} chez ${center.name}.',
              textAlign: TextAlign.center),
          actions: [FilledButton(onPressed: () => Navigator.pop(c), child: const Text('Parfait'))],
        ),
      );
      if (mounted) context.pushReplacement('/bookings');
    } catch (e) {
      if (mounted) showSnack(context, e.toString(), error: true);
      _loadSlots();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final center = ref.watch(centerProvider(widget.centerId));
    final catalog = ref.watch(catalogProvider(widget.centerId));
    final pad = context.pagePadding;

    return Scaffold(
      appBar: AppBar(title: Text(center.value?.name ?? 'Réserver')),
      body: AsyncView(
        value: catalog,
        builder: (cat) {
          _vehicleId ??= cat.vehicleTypes.firstOrNull?.id;
          final services = cat.services.where((s) => s.bookable).toList();
          final rule = (_serviceId != null && _vehicleId != null) ? cat.rule(_serviceId!, _vehicleId!) : null;
          return ListView(
            padding: EdgeInsets.fromLTRB(pad, 8, pad, 120),
            children: [
              MaxWidth(
                maxWidth: 760,
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  _step(context, 1, 'Votre véhicule'),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    for (final v in cat.vehicleTypes)
                      ChoiceChip(
                        avatar: Icon(iconFor(v.icon), size: 18, color: v.id == _vehicleId ? Colors.white : AppColors.primary),
                        label: Text(v.name),
                        selected: v.id == _vehicleId,
                        showCheckmark: false,
                        selectedColor: AppColors.primary,
                        labelStyle: TextStyle(color: v.id == _vehicleId ? Colors.white : null, fontWeight: FontWeight.w700),
                        onSelected: (_) => setState(() => _vehicleId = v.id),
                      ),
                  ]),
                  _step(context, 2, 'Le service'),
                  for (final s in services)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _SelectableCard(
                        selected: s.id == _serviceId,
                        onTap: () {
                          _serviceId = s.id;
                          _loadSlots();
                        },
                        child: Row(children: [
                          IconBadge(iconFor(s.icon), gradient: s.isEco ? AppColors.ecoGradient : AppColors.gradient, size: 42),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(s.name, style: const TextStyle(fontWeight: FontWeight.w800)),
                              Text('${s.duration} min', style: TextStyle(color: context.muted, fontSize: 12)),
                            ]),
                          ),
                          if (_vehicleId != null && cat.rule(s.id, _vehicleId!) != null)
                            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                              Text(fmtMoney(cat.rule(s.id, _vehicleId!)!.price, center.value?.currency ?? ''),
                                  style: const TextStyle(fontWeight: FontWeight.w800)),
                              Text('+${cat.rule(s.id, _vehicleId!)!.points} pts',
                                  style: const TextStyle(color: AppColors.eco, fontWeight: FontWeight.w700, fontSize: 12)),
                            ]),
                        ]),
                      ),
                    ),
                  if (_serviceId != null) ...[
                    _step(context, 3, 'Le jour'),
                    SizedBox(
                      height: 84,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: 14,
                        separatorBuilder: (_, _) => const SizedBox(width: 10),
                        itemBuilder: (_, i) {
                          final d = DateTime.now().add(Duration(days: i));
                          final sel = DateUtils.isSameDay(d, _day);
                          return Pressable(
                            onTap: () {
                              _day = d;
                              _loadSlots();
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: 64,
                              decoration: BoxDecoration(
                                gradient: sel ? AppColors.gradient : null,
                                color: sel ? null : context.colors.surface,
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(color: sel ? Colors.transparent : context.borderColor),
                              ),
                              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                                Text(i == 0 ? 'Auj.' : capitalize(fmtDayLong(d).substring(0, 3)),
                                    style: TextStyle(color: sel ? Colors.white70 : context.muted, fontSize: 12, fontWeight: FontWeight.w600)),
                                Text('${d.day}', style: TextStyle(color: sel ? Colors.white : null, fontSize: 22, fontWeight: FontWeight.w800)),
                              ]),
                            ),
                          );
                        },
                      ),
                    ),
                    _step(context, 4, "L'heure"),
                    FutureBuilder<List<Slot>>(
                      future: _slots,
                      builder: (context, snap) {
                        if (snap.connectionState != ConnectionState.done) return const SkeletonList(count: 1, height: 100);
                        if (snap.hasError) return Text(snap.error.toString());
                        final slots = snap.data ?? const [];
                        if (slots.isEmpty) {
                          return const EmptyState(icon: Icons.event_busy_rounded, title: 'Aucun créneau ce jour',
                              message: 'Le centre est fermé ou complet. Essayez un autre jour.');
                        }
                        return Wrap(spacing: 8, runSpacing: 8, children: [
                          for (final s in slots)
                            ChoiceChip(
                              label: Text(fmtTime(s.start)),
                              selected: _slot == s,
                              showCheckmark: false,
                              selectedColor: AppColors.primary,
                              labelStyle: TextStyle(
                                color: _slot == s ? Colors.white : (s.available == 0 ? context.muted : null),
                                fontWeight: FontWeight.w700,
                                decoration: s.available == 0 ? TextDecoration.lineThrough : null,
                              ),
                              onSelected: s.available == 0 ? null : (_) => setState(() => _slot = s),
                            ),
                        ]).animate().fadeIn();
                      },
                    ),
                    const SizedBox(height: 18),
                    TextField(controller: _note, decoration: const InputDecoration(labelText: 'Note pour le centre (optionnel)')),
                  ],
                  if (rule != null && _slot != null) ...[
                    const SizedBox(height: 18),
                    AppCard(
                      color: AppColors.primary.withValues(alpha: .06),
                      child: Row(children: [
                        const Icon(Icons.info_outline_rounded, color: AppColors.primary),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '${capitalize(fmtDayLong(_slot!.start))} à ${fmtTime(_slot!.start)} · ${fmtMoney(rule.price, center.value?.currency ?? '')} · +${rule.points} points',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ]),
                    ),
                  ],
                ]),
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.all(16),
        child: MaxWidth(
          maxWidth: 760,
          child: GradientButton(
            label: 'Confirmer la réservation',
            icon: Icons.check_rounded,
            loading: _saving,
            onPressed: _slot == null || _vehicleId == null || center.value == null ? null : () => _confirm(center.value!),
          ),
        ),
      ),
    );
  }

  Widget _step(BuildContext context, int n, String title) => Padding(
        padding: const EdgeInsets.only(top: 22, bottom: 12),
        child: Row(children: [
          Container(
            width: 26, height: 26, alignment: Alignment.center,
            decoration: BoxDecoration(gradient: AppColors.gradient, borderRadius: BorderRadius.circular(9)),
            child: Text('$n', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13)),
          ),
          const SizedBox(width: 10),
          Text(title, style: context.text.titleMedium),
        ]),
      );
}

class _SelectableCard extends StatelessWidget {
  const _SelectableCard({required this.selected, required this.onTap, required this.child});
  final bool selected;
  final VoidCallback onTap;
  final Widget child;
  @override
  Widget build(BuildContext context) => Pressable(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary.withValues(alpha: .08) : context.colors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: selected ? AppColors.primary : context.borderColor, width: selected ? 1.8 : 1),
          ),
          child: child,
        ),
      );
}

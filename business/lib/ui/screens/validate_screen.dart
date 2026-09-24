import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lavpro_core/lavpro_core.dart';

import '../../models/staff.dart';
import '../../state/providers.dart';

/// Ce que l'on valide : un client identifié (éventuellement avec sa réservation) ou un client de passage.
class ValidateRequest {
  const ValidateRequest.client(this.client, {this.booking});
  const ValidateRequest.booking(StaffBooking this.booking) : client = null;
  const ValidateRequest.walkIn()
      : client = null,
        booking = null;

  final ClientLookup? client;
  final StaffBooking? booking;

  bool get isWalkIn => client == null && booking == null;
}

class ValidateScreen extends ConsumerStatefulWidget {
  const ValidateScreen({super.key, required this.request});
  final ValidateRequest request;
  @override
  ConsumerState<ValidateScreen> createState() => _ValidateScreenState();
}

class _ValidateScreenState extends ConsumerState<ValidateScreen> {
  int? _vehicleId;
  int? _serviceId;
  int? _washerId;
  int? _bookingId;
  final _plate = TextEditingController();
  bool _saving = false;
  CenterWash? _done;
  late List<Redemption> _pending = widget.request.client?.pendingRedemptions ?? const [];

  @override
  void initState() {
    super.initState();
    final booking = widget.request.booking ?? widget.request.client?.upcomingBookings.firstOrNull;
    if (booking != null) {
      _bookingId = booking.id;
      _serviceId = booking.serviceId;
      _vehicleId = booking.vehicleTypeId;
    }
    final vehicles = widget.request.client?.vehicles ?? const [];
    if (vehicles.length == 1) _plate.text = vehicles.first.plate ?? '';
  }

  Future<void> _submit() async {
    final id = ref.read(selectedCenterProvider)!;
    setState(() => _saving = true);
    try {
      final w = await ref.read(repoProvider).validateWash(id,
          clientCode: widget.request.client?.memberCode, serviceId: _serviceId!, vehicleTypeId: _vehicleId!,
          washerId: _washerId, bookingId: _bookingId, plate: _plate.text.trim().toUpperCase());
      refreshActivity(ref);
      setState(() => _done = w);
    } catch (e) {
      if (mounted) showSnack(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _give(Redemption r) async {
    try {
      await ref.read(repoProvider).giveReward(ref.read(selectedCenterProvider)!, '${r.id}');
      setState(() => _pending = _pending.where((x) => x.id != r.id).toList());
      if (mounted) showSnack(context, '« ${r.rewardName} » remis');
    } catch (e) {
      if (mounted) showSnack(context, e.toString(), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final catalog = ref.watch(catalogProvider);
    final currency = ref.watch(centerInfoProvider).value?.currency ?? '';
    return Scaffold(
      appBar: AppBar(title: Text(_done != null ? 'Lavage validé' : 'Valider un lavage')),
      body: _done != null
          ? _Success(wash: _done!, request: widget.request, currency: currency)
          : AsyncView(
              value: catalog,
              onRetry: () => ref.invalidate(catalogProvider),
              builder: (cat) => _form(context, cat, currency),
            ),
      bottomNavigationBar: _done != null
          ? null
          : SafeArea(
              minimum: const EdgeInsets.all(16),
              child: MaxWidth(
                maxWidth: 620,
                child: Builder(builder: (context) {
                  final rule = catalog.value?.rule(_serviceId, _vehicleId);
                  return Column(mainAxisSize: MainAxisSize.min, children: [
                    if (rule != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Text(
                          '${fmtMoney(rule.price, currency)}${widget.request.isWalkIn ? '' : '  ·  +${rule.points} points'}',
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                        ),
                      ),
                    GradientButton(
                      label: 'Valider le lavage',
                      icon: Icons.task_alt_rounded,
                      loading: _saving,
                      onPressed: _serviceId == null || _vehicleId == null ? null : _submit,
                    ),
                  ]);
                }),
              ),
            ),
    );
  }

  Widget _form(BuildContext context, CenterCatalog cat, String currency) {
    final r = widget.request;
    final c = r.client;
    return ListView(padding: EdgeInsets.all(context.pagePadding), children: [
      MaxWidth(
        maxWidth: 620,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (c != null)
            GradientCard(
              child: Row(children: [
                Avatar(c.initials, size: 54, gradient: AppColors.nightGradient),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(c.fullName, style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w800)),
                    Text('${c.visits} visite(s)${c.lastVisit != null ? ' · dernière ${relativeDays(c.lastVisit!)}' : ''}',
                        style: const TextStyle(color: Colors.white70, fontSize: 12)),
                    if (c.isLoyal) ...[
                      const SizedBox(height: 6),
                      const Pill('Client fidèle', icon: Icons.workspace_premium_rounded, color: AppColors.amber, filled: true),
                    ],
                  ]),
                ),
                Column(children: [
                  Text(fmtNum(c.balance), style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800)),
                  const Text('points', style: TextStyle(color: Colors.white70, fontSize: 12)),
                ]),
              ]),
            )
          else if (r.booking != null)
            GradientCard(
              child: Row(children: [
                const Icon(Icons.event_available_rounded, color: Colors.white, size: 36),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(r.booking!.clientName, style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w800)),
                    Text('Réservation de ${fmtTime(r.booking!.start)} · les points seront crédités',
                        style: const TextStyle(color: Colors.white70, fontSize: 12)),
                  ]),
                ),
              ]),
            )
          else
            AppCard(
              color: AppColors.amber.withValues(alpha: .1),
              child: const Row(children: [
                Icon(Icons.person_off_rounded, color: AppColors.amber),
                SizedBox(width: 12),
                Expanded(child: Text('Client de passage : le lavage est enregistré sans attribution de points.',
                    style: TextStyle(fontWeight: FontWeight.w600))),
              ]),
            ),
          if (_bookingId != null && c != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: AppCard(
                color: AppColors.primary.withValues(alpha: .06),
                child: const Row(children: [
                  Icon(Icons.event_rounded, color: AppColors.primary),
                  SizedBox(width: 10),
                  Expanded(child: Text('Réservation du client détectée : service et véhicule préremplis.',
                      style: TextStyle(fontWeight: FontWeight.w600))),
                ]),
              ),
            ),
          for (final red in _pending)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: AppCard(
                color: AppColors.eco.withValues(alpha: .08),
                child: Row(children: [
                  const Icon(Icons.redeem_rounded, color: AppColors.eco),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(red.rewardName ?? '', style: const TextStyle(fontWeight: FontWeight.w800)),
                      Text('Récompense à remettre · ${red.code}', style: TextStyle(color: context.muted, fontSize: 12)),
                    ]),
                  ),
                  FilledButton(
                    style: FilledButton.styleFrom(minimumSize: const Size(90, 40), backgroundColor: AppColors.eco),
                    onPressed: () => _give(red),
                    child: const Text('Remettre'),
                  ),
                ]),
              ),
            ),
          _step(context, 1, 'Type de véhicule'),
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
          _step(context, 2, 'Service'),
          for (final s in cat.services)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _ServiceTile(
                service: s,
                rule: cat.rule(s.id, _vehicleId),
                currency: currency,
                showPoints: !r.isWalkIn,
                selected: s.id == _serviceId,
                onTap: () => setState(() => _serviceId = s.id),
              ),
            ),
          _step(context, 3, 'Laveur'),
          Wrap(spacing: 8, runSpacing: 8, children: [
            ChoiceChip(
              label: const Text('Non précisé'),
              selected: _washerId == null,
              showCheckmark: false,
              onSelected: (_) => setState(() => _washerId = null),
            ),
            for (final w in cat.washers)
              ChoiceChip(
                avatar: Icon(Icons.person_rounded, size: 18, color: w.id == _washerId ? Colors.white : AppColors.primary),
                label: Text(w.fullName),
                selected: w.id == _washerId,
                showCheckmark: false,
                selectedColor: AppColors.primary,
                labelStyle: TextStyle(color: w.id == _washerId ? Colors.white : null, fontWeight: FontWeight.w700),
                onSelected: (_) => setState(() => _washerId = w.id),
              ),
          ]),
          const SizedBox(height: 18),
          if (c != null && c.vehicles.isNotEmpty) ...[
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final v in c.vehicles.where((v) => (v.plate ?? '').isNotEmpty))
                ActionChip(
                  avatar: const Icon(Icons.directions_car_rounded, size: 18),
                  label: Text('${v.label} · ${v.plate}'),
                  onPressed: () => setState(() => _plate.text = v.plate!),
                ),
            ]),
            const SizedBox(height: 10),
          ],
          TextField(
            controller: _plate,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(labelText: 'Immatriculation (optionnel)', prefixIcon: Icon(Icons.pin_rounded)),
          ),
          const SizedBox(height: 24),
        ]),
      ),
    ]);
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

class _ServiceTile extends StatelessWidget {
  const _ServiceTile({required this.service, required this.rule, required this.currency, required this.showPoints,
      required this.selected, required this.onTap});
  final ServiceType service;
  final PricingRule? rule;
  final String currency;
  final bool showPoints;
  final bool selected;
  final VoidCallback onTap;

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
          child: Row(children: [
            IconBadge(iconFor(service.icon), gradient: service.isEco ? AppColors.ecoGradient : AppColors.gradient, size: 42),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(service.name, style: const TextStyle(fontWeight: FontWeight.w800)),
                Text('${service.duration} min', style: TextStyle(color: context.muted, fontSize: 12)),
              ]),
            ),
            if (rule != null)
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(fmtMoney(rule!.price, currency), style: const TextStyle(fontWeight: FontWeight.w800)),
                if (showPoints)
                  Text('+${rule!.points} pts', style: const TextStyle(color: AppColors.eco, fontWeight: FontWeight.w700, fontSize: 12)),
              ])
            else
              Text('Tarif non défini', style: TextStyle(color: context.muted, fontSize: 12)),
          ]),
        ),
      );
}

class _Success extends StatelessWidget {
  const _Success({required this.wash, required this.request, required this.currency});
  final CenterWash wash;
  final ValidateRequest request;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final client = request.client;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 116, height: 116,
              decoration: BoxDecoration(
                gradient: AppColors.ecoGradient, shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: AppColors.eco.withValues(alpha: .4), blurRadius: 40)],
              ),
              child: const Icon(Icons.check_rounded, color: Colors.white, size: 68),
            ).animate().scale(curve: Curves.easeOutBack, duration: 500.ms),
            const SizedBox(height: 24),
            Text('Lavage validé !', style: context.text.headlineSmall),
            const SizedBox(height: 6),
            Text(
              [wash.serviceName, wash.vehicleTypeName, if (wash.washerName != null) 'par ${wash.washerName}']
                  .whereType<String>().join(' · '),
              textAlign: TextAlign.center, style: TextStyle(color: context.muted),
            ),
            const SizedBox(height: 24),
            Row(children: [
              Expanded(child: _Stat('Montant', fmtMoney(wash.price, currency))),
              if (wash.clientName != null) ...[
                const SizedBox(width: 12),
                Expanded(child: _Stat('Points gagnés', '+${wash.points}', color: AppColors.eco)),
                if (client != null) ...[
                  const SizedBox(width: 12),
                  Expanded(child: _Stat('Nouveau solde', fmtNum(client.balance + wash.points))),
                ],
              ],
            ]),
            if (wash.discount > 0) ...[
              const SizedBox(height: 10),
              Pill('Remise promotion : ${fmtMoney(wash.discount, currency)}', color: AppColors.violet),
            ],
            const SizedBox(height: 28),
            GradientButton(
              label: 'Client suivant', icon: Icons.qr_code_scanner_rounded,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ]),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value, {this.color});
  final String label;
  final String value;
  final Color? color;
  @override
  Widget build(BuildContext context) => AppCard(
        padding: const EdgeInsets.all(14),
        child: Column(children: [
          FittedBox(child: Text(value, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20, color: color))),
          Text(label, style: TextStyle(color: context.muted, fontSize: 11)),
        ]),
      );
}

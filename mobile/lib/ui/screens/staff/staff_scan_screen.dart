import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../core/format.dart';
import '../../../core/responsive.dart';
import '../../../core/theme.dart';
import '../../../models/center.dart';
import '../../../models/loyalty.dart';
import '../../../models/staff.dart';
import '../../../state/providers.dart';
import '../../widgets/common.dart';
import '../../widgets/icons.dart';

/// Mode gestionnaire : scanner le QR code d'un client puis valider son lavage depuis le téléphone.
class StaffScanScreen extends ConsumerStatefulWidget {
  const StaffScanScreen({super.key});
  @override
  ConsumerState<StaffScanScreen> createState() => _StaffScanScreenState();
}

class _StaffScanScreenState extends ConsumerState<StaffScanScreen> {
  int? _centerId;
  ClientLookup? _client;
  bool _busy = false;
  final _code = TextEditingController();

  List<ServiceType> _services = [];
  List<VehicleType> _vehicles = [];
  List<PricingRule> _pricing = [];
  List<Washer> _washers = [];
  int? _serviceId;
  int? _vehicleId;
  int? _washerId;
  WashRecord? _done;

  @override
  void initState() {
    super.initState();
    final m = ref.read(currentUserProvider)?.memberships ?? const [];
    if (m.isNotEmpty) _selectCenter(m.first.centerId);
  }

  Future<void> _selectCenter(int id) async {
    setState(() => _centerId = id);
    final repo = ref.read(repoProvider);
    final r = await Future.wait([repo.staffServices(id), repo.staffVehicleTypes(id), repo.staffPricing(id), repo.washers(id)]);
    if (!mounted) return;
    setState(() {
      _services = (r[0] as List<ServiceType>);
      _vehicles = (r[1] as List<VehicleType>);
      _pricing = r[2] as List<PricingRule>;
      _washers = r[3] as List<Washer>;
    });
  }

  Future<void> _lookup(String code) async {
    if (_busy || _centerId == null || code.isEmpty) return;
    setState(() => _busy = true);
    try {
      final c = await ref.read(repoProvider).lookupClient(_centerId!, code);
      setState(() {
        _client = c;
        _done = null;
      });
    } catch (e) {
      if (mounted) showSnack(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  PricingRule? get _rule {
    for (final r in _pricing) {
      if (r.serviceId == _serviceId && r.vehicleId == _vehicleId) return r;
    }
    return null;
  }

  Future<void> _validate() async {
    setState(() => _busy = true);
    try {
      final w = await ref.read(repoProvider).validateWash(_centerId!, {
        'client_code': _client!.memberCode, 'service_type_id': _serviceId, 'vehicle_type_id': _vehicleId,
        'washer_id': _washerId,
      });
      setState(() => _done = w);
    } catch (e) {
      if (mounted) showSnack(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _reset() => setState(() {
        _client = null;
        _done = null;
        _serviceId = null;
        _code.clear();
      });

  @override
  Widget build(BuildContext context) {
    final memberships = ref.watch(currentUserProvider)?.memberships ?? const [];
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mode gestionnaire'),
        actions: [
          if (memberships.length > 1)
            PopupMenuButton<int>(
              icon: const Icon(Icons.storefront_rounded),
              onSelected: _selectCenter,
              itemBuilder: (_) => [for (final m in memberships) PopupMenuItem(value: m.centerId, child: Text(m.centerName))],
            ),
        ],
      ),
      body: MaxWidth(
        maxWidth: 640,
        child: _done != null ? _success() : (_client == null ? _scanner(context) : _form(context)),
      ),
    );
  }

  Widget _scanner(BuildContext context) => ListView(padding: EdgeInsets.all(context.pagePadding), children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: AspectRatio(
            aspectRatio: 1,
            child: Stack(fit: StackFit.expand, children: [
              MobileScanner(
                onDetect: (capture) {
                  final v = capture.barcodes.firstOrNull?.rawValue;
                  if (v != null) _lookup(v);
                },
              ),
              Center(
                child: Container(
                  width: 230, height: 230,
                  decoration: BoxDecoration(border: Border.all(color: AppColors.cyan, width: 3), borderRadius: BorderRadius.circular(24)),
                ).animate(onPlay: (c) => c.repeat(reverse: true)).scaleXY(begin: .96, end: 1.02, duration: 1100.ms),
              ),
              if (_busy) Container(color: Colors.black45, child: const Center(child: CircularProgressIndicator())),
            ]),
          ),
        ),
        const SizedBox(height: 18),
        Text('Ou saisissez le code membre', style: TextStyle(color: context.muted, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
            child: TextField(
              controller: _code,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(hintText: 'Ex : K7M2XQ9P', prefixIcon: Icon(Icons.badge_rounded)),
              onSubmitted: (v) => _lookup(v.trim()),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            height: 54,
            child: FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size(60, 54)),
              onPressed: () => _lookup(_code.text.trim()),
              child: const Icon(Icons.search_rounded),
            ),
          ),
        ]),
      ]);

  Widget _form(BuildContext context) {
    final c = _client!;
    return ListView(padding: EdgeInsets.all(context.pagePadding), children: [
      GradientCard(
        child: Row(children: [
          Avatar('${c.firstName[0]}${c.lastName.isNotEmpty ? c.lastName[0] : ''}', size: 54, gradient: AppColors.nightGradient),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${c.firstName} ${c.lastName}', style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w800)),
              Text('${c.visits} visite(s)${c.isLoyal ? ' · client fidèle ⭐' : ''}', style: const TextStyle(color: Colors.white70)),
            ]),
          ),
          Column(children: [
            Text(fmtNum(c.balance), style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800)),
            const Text('points', style: TextStyle(color: Colors.white70, fontSize: 12)),
          ]),
        ]),
      ),
      for (final r in c.pendingRedemptions)
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: AppCard(
            color: AppColors.eco.withValues(alpha: .08),
            child: Row(children: [
              const Icon(Icons.redeem_rounded, color: AppColors.eco),
              const SizedBox(width: 10),
              Expanded(child: Text('${r.rewardName} (code ${r.code})', style: const TextStyle(fontWeight: FontWeight.w700))),
              TextButton(
                onPressed: () async {
                  await ref.read(repoProvider).giveReward(_centerId!, r.id);
                  if (context.mounted) showSnack(context, 'Récompense remise');
                  _lookup(c.memberCode);
                },
                child: const Text('Remettre'),
              ),
            ]),
          ),
        ),
      const SectionHeader('Type de véhicule'),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final v in _vehicles)
          ChoiceChip(
            avatar: Icon(iconFor(v.icon), size: 18, color: v.id == _vehicleId ? Colors.white : AppColors.primary),
            label: Text(v.name), selected: v.id == _vehicleId, showCheckmark: false, selectedColor: AppColors.primary,
            labelStyle: TextStyle(color: v.id == _vehicleId ? Colors.white : null, fontWeight: FontWeight.w700),
            onSelected: (_) => setState(() => _vehicleId = v.id),
          ),
      ]),
      const SectionHeader('Service'),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final s in _services)
          ChoiceChip(
            avatar: Icon(iconFor(s.icon), size: 18, color: s.id == _serviceId ? Colors.white : AppColors.primary),
            label: Text(s.name), selected: s.id == _serviceId, showCheckmark: false, selectedColor: AppColors.primary,
            labelStyle: TextStyle(color: s.id == _serviceId ? Colors.white : null, fontWeight: FontWeight.w700),
            onSelected: (_) => setState(() => _serviceId = s.id),
          ),
      ]),
      const SectionHeader('Laveur'),
      DropdownButtonFormField<int?>(
        initialValue: _washerId,
        items: [
          const DropdownMenuItem(value: null, child: Text('Non précisé')),
          for (final w in _washers) DropdownMenuItem(value: w.id, child: Text(w.fullName)),
        ],
        onChanged: (v) => setState(() => _washerId = v),
      ),
      const SizedBox(height: 24),
      if (_rule != null)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text('+${_rule!.points} points · ${_rule!.price.round()}',
              textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.eco, fontSize: 16)),
        ),
      GradientButton(
        label: 'Valider le lavage', icon: Icons.task_alt_rounded, loading: _busy,
        onPressed: _serviceId == null || _vehicleId == null ? null : _validate,
      ),
      TextButton(onPressed: _reset, child: const Text('Annuler')),
    ]);
  }

  Widget _success() => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 110, height: 110,
              decoration: BoxDecoration(gradient: AppColors.ecoGradient, shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: AppColors.eco.withValues(alpha: .4), blurRadius: 40)]),
              child: const Icon(Icons.check_rounded, color: Colors.white, size: 64),
            ).animate().scale(curve: Curves.easeOutBack, duration: 500.ms),
            const SizedBox(height: 22),
            Text('Lavage validé !', style: context.text.headlineSmall),
            const SizedBox(height: 6),
            Text('${_done!.serviceName} · +${_done!.points} points pour ${_client!.firstName}',
                textAlign: TextAlign.center, style: TextStyle(color: context.muted)),
            const SizedBox(height: 28),
            GradientButton(label: 'Client suivant', icon: Icons.qr_code_scanner_rounded, onPressed: _reset),
          ]),
        ),
      );
}

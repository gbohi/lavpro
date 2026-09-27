import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:lavpro_core/lavpro_core.dart';

import '../../../state/providers.dart';
import '../rewards/reward_tile.dart';

const _days = ['Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi', 'Dimanche'];

class CenterDetailScreen extends ConsumerStatefulWidget {
  const CenterDetailScreen({super.key, required this.centerId});
  final int centerId;
  @override
  ConsumerState<CenterDetailScreen> createState() => _CenterDetailScreenState();
}

class _CenterDetailScreenState extends ConsumerState<CenterDetailScreen> {
  Timer? _live;
  int? _vehicleId;

  @override
  void initState() {
    super.initState();
    _live = Timer.periodic(const Duration(seconds: 30), (_) => ref.invalidate(centerProvider(widget.centerId)));
  }

  @override
  void dispose() {
    _live?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final center = ref.watch(centerProvider(widget.centerId));
    return Scaffold(
      body: center.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Scaffold(appBar: AppBar(), body: EmptyState(icon: Icons.cloud_off_rounded, title: e.toString())),
        data: (c) => _content(context, c),
      ),
    );
  }

  Widget _content(BuildContext context, WashCenter c) {
    final catalog = ref.watch(catalogProvider(c.id));
    final rewards = ref.watch(centerRewardsProvider(c.id));
    final pad = context.pagePadding;
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(centerProvider(c.id));
        ref.invalidate(catalogProvider(c.id));
        ref.invalidate(centerRewardsProvider(c.id));
      },
      child: CustomScrollView(slivers: [
        SliverAppBar(
          expandedHeight: 230,
          pinned: true,
          stretch: true,
          backgroundColor: AppColors.ink,
          foregroundColor: Colors.white,
          flexibleSpace: FlexibleSpaceBar(
            title: Text(c.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18)),
            background: Stack(fit: StackFit.expand, children: [
              if (c.coverUrl != null)
                Image.network(c.coverUrl!, fit: BoxFit.cover)
              else
                Container(decoration: const BoxDecoration(gradient: AppColors.nightGradient),
                    child: Icon(Icons.local_car_wash_rounded, size: 120, color: Colors.white.withValues(alpha: .08))),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Color(0xCC0B1220)]),
                ),
              ),
            ]),
          ),
        ),
        SliverToBoxAdapter(
          child: MaxWidth(
            maxWidth: 900,
            child: Padding(
              padding: EdgeInsets.fromLTRB(pad, 20, pad, 40),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                _LiveOccupancy(c),
                const SizedBox(height: 16),
                Row(children: [
                  if (c.bookingEnabled)
                    Expanded(
                      flex: 2,
                      child: GradientButton(
                        label: 'Réserver', icon: Icons.event_available_rounded,
                        onPressed: () => context.push('/center/${c.id}/book'),
                      ),
                    ),
                  if (c.lat != null) ...[
                    const SizedBox(width: 10),
                    _RoundAction(Icons.directions_rounded, 'Itinéraire', () => launchUrl(
                        Uri.parse('https://www.google.com/maps/dir/?api=1&destination=${c.lat},${c.lng}'),
                        mode: LaunchMode.externalApplication)),
                  ],
                  if (c.phone != null) ...[
                    const SizedBox(width: 10),
                    _RoundAction(Icons.call_rounded, 'Appeler', () => launchUrl(Uri.parse('tel:${c.phone}'))),
                  ],
                ]),
                if (c.myBalance != null) ...[
                  const SizedBox(height: 16),
                  AppCard(
                    child: Row(children: [
                      const IconBadge(Icons.stars_rounded, gradient: AppColors.warmGradient),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('Mon solde dans ce centre', style: TextStyle(color: context.muted, fontWeight: FontWeight.w600)),
                          Text(
                            c.pointsValidityMonths == null
                                ? 'Vos points n\'expirent pas'
                                : 'Points valables ${c.pointsValidityMonths} mois après chaque gain',
                            style: TextStyle(color: context.muted, fontSize: 11),
                          ),
                        ]),
                      ),
                      Text('${fmtNum(c.myBalance!)} pts', style: context.text.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                    ]),
                  ),
                ],
                if (c.description != null && c.description!.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  Text(c.description!, style: TextStyle(color: context.muted, height: 1.5)),
                ],
                catalog.maybeWhen(
                  data: (cat) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    if (cat.promotions.isNotEmpty) ...[
                      const SectionHeader('Offres du moment'),
                      for (final p in cat.promotions) _PromoCard(p),
                    ],
                    const SectionHeader('Services & points'),
                    if (c.pointsPaymentEnabled && cat.pricing.any((r) => r.pointsPrice != null))
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text('💳 Ce centre accepte le paiement de vos lavages en points.',
                            style: TextStyle(color: context.muted, fontWeight: FontWeight.w600)),
                      ),
                    _Pricing(cat: cat, currency: c.currency, pointsPayment: c.pointsPaymentEnabled, vehicleId: _vehicleId ?? cat.vehicleTypes.firstOrNull?.id,
                        onVehicle: (id) => setState(() => _vehicleId = id)),
                  ]),
                  orElse: () => const SkeletonList(),
                ),
                const SectionHeader('Récompenses'),
                rewards.when(
                  data: (list) => list.isEmpty
                      ? Text('Ce centre n\'a pas encore publié de récompenses.', style: TextStyle(color: context.muted))
                      : _RewardsGrid(list),
                  loading: () => const SkeletonList(count: 2),
                  error: (e, _) => Text(e.toString()),
                ),
                const SectionHeader('Horaires'),
                AppCard(
                  child: Column(children: [
                    for (final d in [...c.openingHours]..sort((a, b) => a.day.compareTo(b.day)))
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(children: [
                          Expanded(
                            child: Text(_days[d.day],
                                style: TextStyle(
                                  fontWeight: d.day == DateTime.now().weekday - 1 ? FontWeight.w800 : FontWeight.w500,
                                  color: d.day == DateTime.now().weekday - 1 ? AppColors.primary : null,
                                )),
                          ),
                          Text(d.closed ? 'Fermé' : '${d.open} – ${d.close}',
                              style: TextStyle(color: d.closed ? AppColors.red : null, fontWeight: FontWeight.w600)),
                        ]),
                      ),
                  ]),
                ),
                if (c.fullAddress.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Row(children: [
                    Icon(Icons.place_rounded, color: context.muted),
                    const SizedBox(width: 8),
                    Expanded(child: Text(c.fullAddress, style: TextStyle(color: context.muted))),
                  ]),
                ],
              ]),
            ),
          ),
        ),
      ]),
    );
  }
}

class _RoundAction extends StatelessWidget {
  const _RoundAction(this.icon, this.tooltip, this.onTap);
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Tooltip(
        message: tooltip,
        child: Pressable(
          onTap: onTap,
          child: Container(
            width: 56, height: 56,
            decoration: BoxDecoration(
              color: context.colors.surface, borderRadius: BorderRadius.circular(18), border: Border.all(color: context.borderColor)),
            child: Icon(icon, color: AppColors.primary),
          ),
        ),
      );
}

class _LiveOccupancy extends StatelessWidget {
  const _LiveOccupancy(this.c);
  final WashCenter c;
  @override
  Widget build(BuildContext context) {
    final o = c.occupancy;
    final (label, color, icon) = OccupancyBadge.describe(o);
    final ratio = o == null ? 0.0 : ((o.queue + o.activeBookings) / (o.capacity == 0 ? 1 : o.capacity)).clamp(0, 1).toDouble();
    return AppCard(
      child: Row(children: [
        Stack(alignment: Alignment.center, children: [
          SizedBox(
            width: 64, height: 64,
            child: CircularProgressIndicator(
              value: o?.isOpen == true ? ratio : 0, strokeWidth: 7, backgroundColor: context.borderColor,
              valueColor: AlwaysStoppedAnimation(color), strokeCap: StrokeCap.round),
          ),
          Icon(icon, color: color),
        ]),
        const SizedBox(width: 16),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle))
                  .animate(onPlay: (c) => c.repeat(reverse: true)).fade(begin: 1, end: .3, duration: 900.ms),
              const SizedBox(width: 6),
              Text('Affluence en direct', style: TextStyle(color: context.muted, fontSize: 12, fontWeight: FontWeight.w700)),
            ]),
            const SizedBox(height: 2),
            Text(label, style: context.text.titleLarge?.copyWith(color: color, fontWeight: FontWeight.w800)),
            if (o != null && o.isOpen)
              Text(o.waitMinutes == 0 ? 'Pas d\'attente, venez maintenant !' : '${o.queue} véhicule(s) en attente · ~${o.waitMinutes} min',
                  style: TextStyle(color: context.muted, fontSize: 13)),
          ]),
        ),
      ]),
    );
  }
}

class _PromoCard extends StatelessWidget {
  const _PromoCard(this.p);
  final Promotion p;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: GradientCard(
          gradient: AppColors.violetGradient,
          padding: const EdgeInsets.all(18),
          child: Row(children: [
            const Icon(Icons.local_offer_rounded, color: Colors.white, size: 30),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(p.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
                if (p.description != null) Text(p.description!, style: TextStyle(color: Colors.white.withValues(alpha: .9))),
                const SizedBox(height: 4),
                Text("${p.perk} · jusqu'au ${fmtDateShort(p.endsAt)}",
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)),
              ]),
            ),
          ]),
        ),
      );
}

class _Pricing extends StatelessWidget {
  const _Pricing({required this.cat, required this.currency, required this.vehicleId, required this.onVehicle,
      this.pointsPayment = false});
  final Catalog cat;
  final String currency;
  final bool pointsPayment;
  final int? vehicleId;
  final ValueChanged<int> onVehicle;

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SizedBox(
          height: 44,
          child: ListView(scrollDirection: Axis.horizontal, children: [
            for (final v in cat.vehicleTypes)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  avatar: Icon(iconFor(v.icon), size: 18, color: v.id == vehicleId ? Colors.white : AppColors.primary),
                  label: Text(v.name),
                  selected: v.id == vehicleId,
                  selectedColor: AppColors.primary,
                  labelStyle: TextStyle(color: v.id == vehicleId ? Colors.white : null, fontWeight: FontWeight.w700),
                  showCheckmark: false,
                  onSelected: (_) => onVehicle(v.id),
                ),
              ),
          ]),
        ),
        const SizedBox(height: 12),
        for (final s in cat.services)
          Builder(builder: (context) {
            final r = vehicleId == null ? null : cat.rule(s.id, vehicleId!);
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: AppCard(
                padding: const EdgeInsets.all(14),
                child: Row(children: [
                  IconBadge(iconFor(s.icon), gradient: s.isEco ? AppColors.ecoGradient : AppColors.gradient, size: 44),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(s.name, style: const TextStyle(fontWeight: FontWeight.w800)),
                      Text('${s.duration} min${s.isEco ? ' · écologique' : ''}', style: TextStyle(color: context.muted, fontSize: 12)),
                    ]),
                  ),
                  if (r == null)
                    Text('—', style: TextStyle(color: context.muted))
                  else
                    Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Text(fmtMoney(r.price, currency), style: const TextStyle(fontWeight: FontWeight.w800)),
                      if (pointsPayment && r.pointsPrice != null)
                        Text('ou ${fmtNum(r.pointsPrice!)} pts', style: const TextStyle(color: AppColors.violet, fontWeight: FontWeight.w700, fontSize: 12)),
                      Pill('+${r.points} pts', color: AppColors.eco),
                    ]),
                ]),
              ),
            );
          }),
      ]);
}

class _RewardsGrid extends StatelessWidget {
  const _RewardsGrid(this.rewards);
  final List<Reward> rewards;
  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, c) {
        final cols = (c.maxWidth / 280).floor().clamp(1, 3);
        final w = (c.maxWidth - (cols - 1) * 12) / cols;
        return Wrap(spacing: 12, runSpacing: 12, children: [
          for (final r in rewards) SizedBox(width: w, child: RewardTile(r)),
        ]);
      });
}

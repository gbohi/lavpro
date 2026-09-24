import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/format.dart';
import '../../../core/responsive.dart';
import '../../../core/theme.dart';
import '../../../models/center.dart';
import '../../../state/providers.dart';
import '../../widgets/common.dart';

class CentersScreen extends ConsumerStatefulWidget {
  const CentersScreen({super.key});
  @override
  ConsumerState<CentersScreen> createState() => _CentersScreenState();
}

class _CentersScreenState extends ConsumerState<CentersScreen> {
  bool _map = false;
  Timer? _debounce;
  Timer? _live;

  @override
  void initState() {
    super.initState();
    // Affluence en temps réel
    _live = Timer.periodic(const Duration(seconds: 45), (_) => ref.invalidate(centersProvider));
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _live?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final centers = ref.watch(centersProvider);
    final pos = ref.watch(positionProvider).value;
    final pad = context.pagePadding;
    final showSplit = context.isDesktop;

    final list = RefreshIndicator(
      onRefresh: () => ref.refresh(centersProvider.future),
      child: ListView(
        padding: EdgeInsets.fromLTRB(pad, 4, pad, 24),
        children: [
          AsyncView(
            value: centers,
            onRetry: () => ref.invalidate(centersProvider),
            builder: (items) => items.isEmpty
                ? const EmptyState(icon: Icons.search_off_rounded, title: 'Aucun centre trouvé',
                    message: 'Essayez une autre recherche ou élargissez la zone.')
                : Column(children: [
                    if (pos != null && items.first.distanceKm != null) _NearestBanner(items.first),
                    for (final (i, c) in items.indexed)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: _CenterCard(c).animate().fadeIn(delay: (40 * i).ms).slideY(begin: .06),
                      ),
                  ]),
          ),
        ],
      ),
    );

    final map = centers.maybeWhen(
      data: (items) => _CentersMap(centers: items, me: pos == null ? null : LatLng(pos.latitude, pos.longitude)),
      orElse: () => const Center(child: CircularProgressIndicator()),
    );

    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: EdgeInsets.fromLTRB(pad, 12, pad, 12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text('Centres de lavage', style: context.text.headlineSmall)),
                if (!showSplit)
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(value: false, icon: Icon(Icons.view_agenda_rounded)),
                      ButtonSegment(value: true, icon: Icon(Icons.map_rounded)),
                    ],
                    selected: {_map},
                    showSelectedIcon: false,
                    onSelectionChanged: (s) => setState(() => _map = s.first),
                  ),
              ]),
              const SizedBox(height: 14),
              TextField(
                decoration: InputDecoration(
                  hintText: 'Rechercher un centre, une ville…',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: pos != null ? const Tooltip(message: 'Triés par distance', child: Icon(Icons.my_location_rounded, color: AppColors.primary)) : null,
                ),
                onChanged: (v) {
                  _debounce?.cancel();
                  _debounce = Timer(const Duration(milliseconds: 350), () => ref.read(centerSearchProvider.notifier).set(v.trim()));
                },
              ),
            ]),
          ),
          Expanded(
            child: showSplit
                ? Row(children: [
                    SizedBox(width: 460, child: list),
                    Expanded(child: Padding(padding: const EdgeInsets.fromLTRB(0, 0, 20, 20), child: ClipRRect(borderRadius: BorderRadius.circular(24), child: map))),
                  ])
                : AnimatedSwitcher(duration: const Duration(milliseconds: 250), child: _map ? map : list),
          ),
        ]),
      ),
    );
  }
}

class _NearestBanner extends StatelessWidget {
  const _NearestBanner(this.c);
  final WashCenter c;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: GradientCard(
          onTap: () => context.push('/center/${c.id}'),
          padding: const EdgeInsets.all(18),
          child: Row(children: [
            const Icon(Icons.near_me_rounded, color: Colors.white, size: 34),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Le plus proche · ${c.distanceKm!.toStringAsFixed(1)} km',
                    style: TextStyle(color: Colors.white.withValues(alpha: .85), fontWeight: FontWeight.w600)),
                Text(c.name, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
              ]),
            ),
            if (c.occupancy != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(30)),
                child: Text(OccupancyBadge.describe(c.occupancy).$1,
                    style: TextStyle(color: OccupancyBadge.describe(c.occupancy).$2, fontWeight: FontWeight.w800, fontSize: 12)),
              ),
          ]),
        ),
      );
}

class _CenterCard extends StatelessWidget {
  const _CenterCard(this.c);
  final WashCenter c;

  @override
  Widget build(BuildContext context) => AppCard(
        padding: EdgeInsets.zero,
        onTap: () => context.push('/center/${c.id}'),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Container(
            height: 110,
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
              gradient: c.coverUrl == null ? AppColors.nightGradient : null,
              image: c.coverUrl == null ? null : DecorationImage(image: NetworkImage(c.coverUrl!), fit: BoxFit.cover),
            ),
            padding: const EdgeInsets.all(14),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              OccupancyBadge(c.occupancy),
              const Spacer(),
              if (c.distanceKm != null)
                Pill('${c.distanceKm!.toStringAsFixed(1)} km', icon: Icons.near_me_rounded, color: Colors.white, filled: false),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(c.name, style: context.text.titleMedium),
                  const SizedBox(height: 2),
                  Text(c.fullAddress, style: TextStyle(color: context.muted, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 6),
                  Row(children: [
                    Icon(Icons.schedule_rounded, size: 14, color: context.muted),
                    const SizedBox(width: 4),
                    Text(
                      c.today == null || c.today!.closed ? "Fermé aujourd'hui" : "Aujourd'hui ${c.today!.open} – ${c.today!.close}",
                      style: TextStyle(color: context.muted, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ]),
                ]),
              ),
              if (c.myBalance != null)
                Column(children: [
                  Text(fmtNum(c.myBalance!), style: context.text.titleLarge?.copyWith(color: AppColors.primary, fontWeight: FontWeight.w800)),
                  Text('mes pts', style: TextStyle(color: context.muted, fontSize: 11)),
                ]),
            ]),
          ),
        ]),
      );
}

class _CentersMap extends StatelessWidget {
  const _CentersMap({required this.centers, this.me});
  final List<WashCenter> centers;
  final LatLng? me;

  @override
  Widget build(BuildContext context) {
    final located = centers.where((c) => c.lat != null && c.lng != null).toList();
    final initial = me ?? (located.isNotEmpty ? LatLng(located.first.lat!, located.first.lng!) : const LatLng(5.35, -4.0));
    return FlutterMap(
      options: MapOptions(initialCenter: initial, initialZoom: 12.5),
      children: [
        TileLayer(
          urlTemplate: context.isDark
              ? 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png'
              : 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
          subdomains: const ['a', 'b', 'c', 'd'],
          userAgentPackageName: 'app.lavpro',
        ),
        MarkerLayer(markers: [
          if (me != null)
            Marker(
              point: me!, width: 26, height: 26,
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.primary, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 4),
                  boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: .5), blurRadius: 12)],
                ),
              ),
            ),
          for (final c in located)
            Marker(
              point: LatLng(c.lat!, c.lng!), width: 140, height: 64, alignment: Alignment.topCenter,
              child: GestureDetector(
                onTap: () => context.push('/center/${c.id}'),
                child: Column(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: context.colors.surface, borderRadius: BorderRadius.circular(12),
                      boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8)],
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Container(width: 8, height: 8, decoration: BoxDecoration(color: OccupancyBadge.describe(c.occupancy).$2, shape: BoxShape.circle)),
                      const SizedBox(width: 6),
                      Flexible(child: Text(c.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11))),
                    ]),
                  ),
                  const Icon(Icons.location_on_rounded, color: AppColors.primary, size: 30),
                ]),
              ),
            ),
        ]),
        const RichAttributionWidget(attributions: [TextSourceAttribution('© OpenStreetMap · CARTO')]),
      ],
    );
  }
}

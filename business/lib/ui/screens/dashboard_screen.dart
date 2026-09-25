import 'dart:async';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lavpro_core/lavpro_core.dart';

import '../../models/staff.dart';
import '../../state/providers.dart';
import '../widgets/center_header.dart';

/// Tableau de bord du jour : affluence, chiffres clés, heures de pointe, laveurs.
class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});
  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  Timer? _live;

  @override
  void initState() {
    super.initState();
    _live = Timer.periodic(const Duration(seconds: 30), (_) {
      ref.invalidate(occupancyProvider);
      if (can(ref, 'view_reports')) ref.invalidate(dashboardProvider);
    });
  }

  @override
  void dispose() {
    _live?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final period = ref.watch(dashboardPeriodProvider);
    final canReports = can(ref, 'view_reports');
    final data = canReports ? ref.watch(dashboardProvider) : null;
    final pad = context.pagePadding;
    const periods = [(0, "Aujourd'hui"), (6, '7 jours'), (29, '30 jours')];

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(occupancyProvider);
            if (!can(ref, 'view_reports')) return;
            ref.invalidate(dashboardProvider);
            await ref.read(dashboardProvider.future);
          },
          child: ListView(padding: EdgeInsets.fromLTRB(pad, 12, pad, 32), children: [
            MaxWidth(
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const CenterHeader(title: 'Activité'),
                const SizedBox(height: 18),
                const _QueueCard(),
                const SizedBox(height: 18),
                if (data == null)
                  AppCard(
                    color: AppColors.primary.withValues(alpha: .06),
                    child: const Row(children: [
                      Icon(Icons.lock_outline_rounded, color: AppColors.primary),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          "Le chiffre d'affaires et les statistiques sont réservés aux gestionnaires qui en ont le droit. "
                          'Vous pouvez valider les lavages, gérer la file et les réservations.',
                          style: TextStyle(fontWeight: FontWeight.w600, height: 1.4),
                        ),
                      ),
                    ]),
                  )
                else ...[
                Wrap(spacing: 8, children: [
                  for (final (d, label) in periods)
                    ChoiceChip(
                      label: Text(label),
                      selected: period == d,
                      showCheckmark: false,
                      selectedColor: AppColors.primary,
                      labelStyle: TextStyle(color: period == d ? Colors.white : null, fontWeight: FontWeight.w700),
                      onSelected: (_) => ref.read(dashboardPeriodProvider.notifier).set(d),
                    ),
                ]),
                const SizedBox(height: 14),
                AsyncView(
                  value: data,
                  onRetry: () => ref.invalidate(dashboardProvider),
                  builder: (d) => _Body(d),
                ),
                ],
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

class _QueueCard extends ConsumerStatefulWidget {
  const _QueueCard();
  @override
  ConsumerState<_QueueCard> createState() => _QueueCardState();
}

class _QueueCardState extends ConsumerState<_QueueCard> {
  bool _busy = false;

  Future<void> _change(int delta) async {
    final id = ref.read(selectedCenterProvider);
    if (id == null || _busy) return;
    setState(() => _busy = true);
    try {
      await ref.read(repoProvider).queue(id, delta);
      ref.invalidate(occupancyProvider);
    } catch (e) {
      if (mounted) showSnack(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final occ = ref.watch(occupancyProvider).value;
    final (label, color, _) = OccupancyBadge.describe(occ);
    return GradientCard(
      gradient: AppColors.nightGradient,
      padding: const EdgeInsets.all(20),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(width: 9, height: 9, decoration: BoxDecoration(color: color, shape: BoxShape.circle))
                  .animate(onPlay: (c) => c.repeat(reverse: true)).fade(begin: 1, end: .3, duration: 900.ms),
              const SizedBox(width: 8),
              Text('File d\'attente · $label',
                  style: TextStyle(color: Colors.white.withValues(alpha: .85), fontWeight: FontWeight.w700, fontSize: 13)),
            ]),
            const SizedBox(height: 6),
            Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('${occ?.queue ?? '–'}',
                  style: const TextStyle(color: Colors.white, fontSize: 44, fontWeight: FontWeight.w800, height: 1)),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text('véhicule(s)', style: TextStyle(color: Colors.white.withValues(alpha: .7))),
              ),
            ]),
            const SizedBox(height: 4),
            Text(
              occ == null ? '' : "~${occ.waitMinutes} min d'attente · ${occ.activeBookings} réservation(s) en cours",
              style: TextStyle(color: Colors.white.withValues(alpha: .7), fontSize: 12),
            ),
            const SizedBox(height: 6),
            Text('Visible en direct par vos clients', style: TextStyle(color: Colors.white.withValues(alpha: .5), fontSize: 11)),
          ]),
        ),
        Column(children: [
          _RoundBtn(icon: Icons.add_rounded, onTap: _busy ? null : () => _change(1), primary: true),
          const SizedBox(height: 10),
          _RoundBtn(icon: Icons.remove_rounded, onTap: _busy || (occ?.queue ?? 0) == 0 ? null : () => _change(-1)),
        ]),
      ]),
    );
  }
}

class _RoundBtn extends StatelessWidget {
  const _RoundBtn({required this.icon, required this.onTap, this.primary = false});
  final IconData icon;
  final VoidCallback? onTap;
  final bool primary;
  @override
  Widget build(BuildContext context) => Opacity(
        opacity: onTap == null ? .4 : 1,
        child: Pressable(
          onTap: onTap,
          child: Container(
            width: 58, height: 58,
            decoration: BoxDecoration(
              gradient: primary ? AppColors.gradient : null,
              color: primary ? null : Colors.white.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(icon, color: Colors.white, size: 30),
          ),
        ),
      );
}

class _Body extends StatelessWidget {
  const _Body(this.d);
  final DashboardData d;

  @override
  Widget build(BuildContext context) {
    final kpis = [
      (Icons.local_car_wash_rounded, 'Lavages', fmtNum(d.kpi('washes')), AppColors.gradient),
      (Icons.payments_rounded, "Chiffre d'affaires", fmtMoney(d.kpi('revenue'), d.currency), AppColors.violetGradient),
      (Icons.groups_rounded, 'Clients', fmtNum(d.kpi('unique_clients')), AppColors.warmGradient),
      (Icons.stars_rounded, 'Points distribués', fmtNum(d.kpi('points_issued')), AppColors.ecoGradient),
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      LayoutBuilder(builder: (context, c) {
        final cols = c.maxWidth > 700 ? 4 : 2;
        final w = (c.maxWidth - (cols - 1) * 12) / cols;
        return Wrap(spacing: 12, runSpacing: 12, children: [
          for (final (i, (icon, label, value, g)) in kpis.indexed)
            SizedBox(
              width: w,
              child: AppCard(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  IconBadge(icon, gradient: g, size: 38),
                  const SizedBox(height: 12),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(value, style: context.text.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                  ),
                  Text(label, style: TextStyle(color: context.muted, fontSize: 12, fontWeight: FontWeight.w600)),
                ]),
              ).animate().fadeIn(delay: (50 * i).ms).slideY(begin: .1),
            ),
        ]);
      }),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: _MiniStat('Clients fidèles', '${d.kpi('loyalty_rate')} %', Icons.workspace_premium_rounded, AppColors.amber)),
        const SizedBox(width: 12),
        Expanded(child: _MiniStat('Clients de passage', fmtNum(d.kpi('anonymous_washes')), Icons.person_outline_rounded, AppColors.cyan)),
      ]),
      const SectionHeader("Heures d'affluence"),
      AppCard(child: SizedBox(height: 180, child: _HourlyChart(d.hourly))),
      const SectionHeader('Point par laveur'),
      if (d.washers.isEmpty)
        Text('Aucun lavage sur la période.', style: TextStyle(color: context.muted))
      else
        AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(children: [
            for (final (i, w) in d.washers.indexed)
              _WasherRow(rank: i + 1, washer: w, max: (d.washers.first['count'] as num).toInt(), currency: d.currency),
          ]),
        ),
      if (d.services.isNotEmpty) ...[
        const SectionHeader('Services les plus demandés'),
        AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(children: [
            for (final s in d.services.take(5))
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(s['name'] as String, style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text(fmtMoney(s['revenue'] as num, d.currency)),
                trailing: Pill('${s['count']} · ${s['share']} %'),
              ),
          ]),
        ),
      ],
    ]);
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat(this.label, this.value, this.icon, this.color);
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  @override
  Widget build(BuildContext context) => AppCard(
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          Icon(icon, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
              Text(label, style: TextStyle(color: context.muted, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
            ]),
          ),
        ]),
      );
}

class _WasherRow extends StatelessWidget {
  const _WasherRow({required this.rank, required this.washer, required this.max, required this.currency});
  final int rank;
  final Map<String, dynamic> washer;
  final int max;
  final String currency;
  @override
  Widget build(BuildContext context) {
    final count = (washer['count'] as num).toInt();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(children: [
        Container(
          width: 28, height: 28, alignment: Alignment.center,
          decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: .1), borderRadius: BorderRadius.circular(9)),
          child: Text('$rank', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w800)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(washer['name'] as String, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: max == 0 ? 0 : count / max, minHeight: 6, backgroundColor: context.borderColor,
                valueColor: const AlwaysStoppedAnimation(AppColors.cyan)),
            ),
          ]),
        ),
        const SizedBox(width: 12),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('$count lavage${count > 1 ? 's' : ''}', style: const TextStyle(fontWeight: FontWeight.w800)),
          Text(fmtMoney(washer['revenue'] as num, currency), style: TextStyle(color: context.muted, fontSize: 11)),
        ]),
      ]),
    );
  }
}

class _HourlyChart extends StatelessWidget {
  const _HourlyChart(this.hourly);
  final List<int> hourly;
  @override
  Widget build(BuildContext context) {
    const from = 6, to = 22;
    final values = hourly.sublist(from, to);
    final maxY = values.fold<int>(0, (a, b) => b > a ? b : a);
    return BarChart(BarChartData(
      maxY: (maxY == 0 ? 1 : maxY) * 1.15,
      gridData: const FlGridData(show: false),
      borderData: FlBorderData(show: false),
      barTouchData: BarTouchData(enabled: true),
      titlesData: FlTitlesData(
        leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            getTitlesWidget: (v, _) => v.toInt() % 2 == 0
                ? Padding(padding: const EdgeInsets.only(top: 4),
                    child: Text('${v.toInt() + from}h', style: TextStyle(color: context.muted, fontSize: 10)))
                : const SizedBox.shrink(),
          ),
        ),
      ),
      barGroups: [
        for (final (i, v) in values.indexed)
          BarChartGroupData(x: i, barRods: [
            BarChartRodData(toY: v.toDouble(), width: 12, borderRadius: BorderRadius.circular(4), gradient: AppColors.gradient),
          ]),
      ],
    ));
  }
}

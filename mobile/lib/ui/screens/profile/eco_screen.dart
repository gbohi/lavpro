import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format.dart';
import '../../../core/responsive.dart';
import '../../../core/theme.dart';
import '../../../models/loyalty.dart';
import '../../../state/providers.dart';
import '../../widgets/common.dart';
import '../../widgets/icons.dart';

class EcoScreen extends ConsumerWidget {
  const EcoScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
        appBar: AppBar(title: const Text('Mode Écolo')),
        body: RefreshIndicator(
          onRefresh: () => ref.refresh(ecoProvider.future),
          child: ListView(padding: EdgeInsets.all(context.pagePadding), children: [
            MaxWidth(maxWidth: 760, child: AsyncView(value: ref.watch(ecoProvider), builder: (e) => _Body(e))),
          ]),
        ),
      );
}

class _Body extends StatelessWidget {
  const _Body(this.e);
  final EcoStats e;

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        GradientCard(
          gradient: AppColors.ecoGradient,
          child: Column(children: [
            Stack(alignment: Alignment.center, children: [
              SizedBox(
                width: 150, height: 150,
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: e.progress),
                  duration: const Duration(milliseconds: 1200),
                  curve: Curves.easeOutCubic,
                  builder: (_, v, _) => CircularProgressIndicator(
                    value: v, strokeWidth: 10, strokeCap: StrokeCap.round,
                    backgroundColor: Colors.white24, valueColor: const AlwaysStoppedAnimation(Colors.white)),
                ),
              ),
              Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(iconFor(e.level?.icon, fallback: Icons.water_drop_rounded), color: Colors.white, size: 34),
                Text(fmtNum(e.totalLiters.round()), style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w800)),
                const Text("litres d'eau économisés", style: TextStyle(color: Colors.white, fontSize: 11)),
              ]),
            ]),
            const SizedBox(height: 18),
            Text('Niveau ${e.level?.name ?? '—'}', style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(
              e.nextLevel == null
                  ? 'Niveau maximum atteint, bravo ! 🌍'
                  : 'Plus que ${fmtNum((e.nextLevel!.minLiters - e.totalLiters).round())} L pour atteindre « ${e.nextLevel!.name} »',
              textAlign: TextAlign.center, style: TextStyle(color: Colors.white.withValues(alpha: .9)),
            ),
          ]),
        ).animate().fadeIn().scaleXY(begin: .96),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(child: _stat(context, '${e.totalWashes}', 'lavages', Icons.local_car_wash_rounded)),
          const SizedBox(width: 12),
          Expanded(child: _stat(context, '${e.ecoWashes}', 'lavages écologiques', Icons.eco_rounded)),
        ]),
        if (e.equivalences.isNotEmpty) ...[
          const SectionHeader("C'est l'équivalent de…"),
          Wrap(spacing: 12, runSpacing: 12, children: [
            for (final q in e.equivalences)
              SizedBox(
                width: 220,
                child: AppCard(
                  child: Row(children: [
                    IconBadge(iconFor(q['icon'] as String?, fallback: Icons.water_drop_rounded), gradient: AppColors.ecoGradient, size: 40),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(fmtNum(q['value'] as num), style: context.text.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                        Text(q['label'] as String, style: TextStyle(color: context.muted, fontSize: 12)),
                      ]),
                    ),
                  ]),
                ),
              ),
          ]),
        ],
        if (e.monthly.isNotEmpty) ...[
          const SectionHeader('Eau économisée par mois'),
          AppCard(
            child: SizedBox(
              height: 220,
              child: BarChart(BarChartData(
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (v, _) {
                        final m = e.monthly[v.toInt()]['month'] as String;
                        return Padding(padding: const EdgeInsets.only(top: 6), child: Text(m.substring(5), style: TextStyle(color: context.muted, fontSize: 11)));
                      },
                    ),
                  ),
                ),
                barGroups: [
                  for (final (i, m) in e.monthly.indexed)
                    BarChartGroupData(x: i, barRods: [
                      BarChartRodData(
                        toY: (m['liters'] as num).toDouble(), width: 18,
                        borderRadius: BorderRadius.circular(6), gradient: AppColors.ecoGradient),
                    ]),
                ],
              )),
            ),
          ),
        ],
        const SizedBox(height: 16),
        AppCard(
          color: AppColors.eco.withValues(alpha: .08),
          child: Row(children: [
            const Icon(Icons.lightbulb_rounded, color: AppColors.eco),
            const SizedBox(width: 12),
            Expanded(
              child: Text('Choisissez les services marqués « écologique » et débloquez les offres réservées aux clients écoresponsables.',
                  style: TextStyle(color: context.isDark ? Colors.white : AppColors.ink)),
            ),
          ]),
        ),
      ]);

  Widget _stat(BuildContext context, String v, String l, IconData icon) => AppCard(
        child: Row(children: [
          Icon(icon, color: AppColors.eco),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(v, style: context.text.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
              Text(l, style: TextStyle(color: context.muted, fontSize: 12)),
            ]),
          ),
        ]),
      );
}

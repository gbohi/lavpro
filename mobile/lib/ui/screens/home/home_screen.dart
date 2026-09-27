import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lavpro_core/lavpro_core.dart';

import '../../../state/providers.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  Future<void> _refresh(WidgetRef ref) async {
    refreshLoyalty(ref);
    ref.invalidate(bookingsProvider);
    ref.invalidate(unreadProvider);
    ref.invalidate(ecoProvider);
    await ref.read(accountsProvider.future);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final accounts = ref.watch(accountsProvider);
    final suggestions = ref.watch(suggestionsProvider);
    final bookings = ref.watch(bookingsProvider);
    final unread = ref.watch(unreadProvider).value ?? 0;
    final eco = ref.watch(ecoProvider);
    final hour = DateTime.now().hour;
    final greet = hour < 12 ? 'Bonjour' : hour < 18 ? 'Bon après-midi' : 'Bonsoir';
    final pad = context.pagePadding;

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => _refresh(ref),
          child: ListView(
            padding: EdgeInsets.fromLTRB(pad, 12, pad, 32),
            children: [
              MaxWidth(
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Row(children: [
                    Avatar(user?.initials ?? '', size: 48),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(greet, style: TextStyle(color: context.muted, fontWeight: FontWeight.w600)),
                        Text('${user?.firstName ?? ''} ✨', style: context.text.headlineSmall),
                      ]),
                    ),
                    _Bell(unread: unread),
                  ]),
                  const SizedBox(height: 22),
                  accounts.when(
                    data: (list) => _PointsHero(accounts: list),
                    loading: () => const SkeletonList(count: 1, height: 180),
                    error: (e, _) => const SizedBox.shrink(),
                  ),
                  suggestions.maybeWhen(
                    data: (list) => list.isEmpty ? const SizedBox.shrink() : _Suggestions(list),
                    orElse: () => const SizedBox.shrink(),
                  ),
                  bookings.maybeWhen(
                    data: (list) {
                      final next = list.where((b) => b.isUpcoming).toList()..sort((a, b) => a.start.compareTo(b.start));
                      return next.isEmpty ? const SizedBox.shrink() : _NextBooking(next.first);
                    },
                    orElse: () => const SizedBox.shrink(),
                  ),
                  const SectionHeader('Accès rapide'),
                  const _QuickActions(),
                  SectionHeader('Mes centres', action: 'Explorer', onAction: () => context.go('/centers')),
                  accounts.when(
                    data: (list) => list.isEmpty
                        ? AppCard(
                            child: EmptyState(
                              icon: Icons.local_car_wash_rounded,
                              title: 'Votre premier lavage vous attend',
                              message: 'Présentez votre carte Lavpro dans un centre partenaire pour commencer à cumuler des points.',
                              action: FilledButton.icon(
                                onPressed: () => context.go('/centers'),
                                icon: const Icon(Icons.near_me_rounded),
                                label: const Text('Trouver un centre'),
                              ),
                            ),
                          )
                        : _AccountsGrid(list),
                    loading: () => const SkeletonList(),
                    error: (e, _) => EmptyState(icon: Icons.cloud_off_rounded, title: e.toString()),
                  ),
                  if (user?.ecoMode ?? true)
                    eco.maybeWhen(data: (e) => _EcoTeaser(e), orElse: () => const SizedBox.shrink()),
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Bell extends StatelessWidget {
  const _Bell({required this.unread});
  final int unread;
  @override
  Widget build(BuildContext context) => Pressable(
        onTap: () => context.push('/notifications'),
        child: Container(
          width: 48, height: 48,
          decoration: BoxDecoration(
            color: context.colors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: context.borderColor)),
          child: Stack(alignment: Alignment.center, children: [
            const Icon(Icons.notifications_none_rounded),
            if (unread > 0)
              Positioned(
                top: 8, right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(color: AppColors.red, borderRadius: BorderRadius.circular(10)),
                  child: Text(unread > 9 ? '9+' : '$unread',
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800)),
                ),
              ),
          ]),
        ),
      );
}

class _PointsHero extends StatelessWidget {
  const _PointsHero({required this.accounts});
  final List<LoyaltyAccount> accounts;

  @override
  Widget build(BuildContext context) {
    final total = accounts.fold<int>(0, (a, b) => a + b.balance);
    final visits = accounts.fold<int>(0, (a, b) => a + b.visits);
    return GradientCard(
      onTap: () => context.go('/card'),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Mes points Lavpro', style: TextStyle(color: Colors.white.withValues(alpha: .85), fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: total.toDouble()),
                duration: const Duration(milliseconds: 1100),
                curve: Curves.easeOutCubic,
                builder: (_, v, _) => Text(fmtNum(v.round()),
                    style: const TextStyle(color: Colors.white, fontSize: 44, fontWeight: FontWeight.w800, letterSpacing: -1.5, height: 1)),
              ),
              const Padding(
                padding: EdgeInsets.only(left: 6, bottom: 6),
                child: Text('pts', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w700)),
              ),
            ]),
            const SizedBox(height: 14),
            Wrap(spacing: 8, runSpacing: 8, children: [
              _glass(Icons.storefront_rounded, '${accounts.length} centre${accounts.length > 1 ? 's' : ''}'),
              _glass(Icons.local_car_wash_rounded, '$visits lavage${visits > 1 ? 's' : ''}'),
            ]),
          ]),
        ),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
          child: const Icon(Icons.qr_code_2_rounded, size: 56, color: AppColors.ink),
        ).animate(onPlay: (c) => c.repeat(reverse: true)).moveY(begin: -2, end: 2, duration: 1600.ms),
      ]),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: .08);
  }

  Widget _glass(IconData icon, String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: .18), borderRadius: BorderRadius.circular(40)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 5),
          Text(text, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)),
        ]),
      );
}

class _Suggestions extends StatelessWidget {
  const _Suggestions(this.items);
  final List<Suggestion> items;

  (IconData, Gradient) _style(String kind) => switch (kind) {
        'weather' => (Icons.wb_sunny_rounded, AppColors.warmGradient),
        'weather_wait' => (Icons.umbrella_rounded, AppColors.nightGradient),
        'promotion' => (Icons.local_offer_rounded, AppColors.violetGradient),
        'reward' => (Icons.redeem_rounded, AppColors.ecoGradient),
        _ => (Icons.auto_awesome_rounded, AppColors.gradient),
      };

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SectionHeader('Pour vous'),
        SizedBox(
          height: 150,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            clipBehavior: Clip.none,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, i) {
              final s = items[i];
              final (icon, gradient) = _style(s.kind);
              return SizedBox(
                width: 290,
                child: AppCard(
                  onTap: () => context.push('/center/${s.centerId}'),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    IconBadge(icon, gradient: gradient),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(s.title, style: context.text.titleSmall?.copyWith(fontWeight: FontWeight.w800), maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 4),
                        Expanded(
                          child: Text(s.message, style: TextStyle(color: context.muted, fontSize: 13, height: 1.35),
                              maxLines: 4, overflow: TextOverflow.ellipsis),
                        ),
                        if (s.weather != null)
                          Text('${(s.weather!['temp_max'] as num?)?.round() ?? '–'}°C · pluie ${s.weather!['rain_probability'] ?? 0} %',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primary)),
                      ]),
                    ),
                  ]),
                ),
              ).animate().fadeIn(delay: (80 * i).ms).slideX(begin: .1);
            },
          ),
        ),
      ]);
}

class _NextBooking extends StatelessWidget {
  const _NextBooking(this.b);
  final Booking b;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 18),
        child: AppCard(
          onTap: () => context.push('/bookings'),
          child: Row(children: [
            Container(
              width: 60, padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: .1), borderRadius: BorderRadius.circular(16)),
              child: Column(children: [
                Text(fmtDateShort(b.start).split(' ').first,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.primary)),
                Text(fmtDateShort(b.start).split(' ').last.toUpperCase(),
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primary)),
              ]),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Pill('Prochaine réservation', icon: Icons.event_available_rounded),
                const SizedBox(height: 6),
                Text('${b.serviceName} · ${fmtTime(b.start)}', style: context.text.titleMedium),
                Text(b.centerName ?? '', style: TextStyle(color: context.muted)),
              ]),
            ),
            const Icon(Icons.chevron_right_rounded),
          ]),
        ),
      );
}

class _QuickActions extends StatelessWidget {
  const _QuickActions();
  @override
  Widget build(BuildContext context) {
    final actions = [
      (Icons.near_me_rounded, 'Centre\nproche', AppColors.gradient, '/centers', true),
      (Icons.event_available_rounded, 'Mes\nréservations', AppColors.violetGradient, '/bookings', false),
      (Icons.eco_rounded, 'Mode\nÉcolo', AppColors.ecoGradient, '/eco', false),
      (Icons.card_giftcard_rounded, 'Parrainer\nun ami', AppColors.warmGradient, '/referral', false),
    ];
    return LayoutBuilder(builder: (context, c) {
      final cols = c.maxWidth > 600 ? 4 : 4;
      final w = (c.maxWidth - (cols - 1) * 12) / cols;
      return Wrap(spacing: 12, runSpacing: 12, children: [
        for (final (i, (icon, label, g, path, tab)) in actions.indexed)
          SizedBox(
            width: w,
            child: Pressable(
              onTap: () => tab ? context.go(path) : context.push(path),
              child: Column(children: [
                Container(
                  height: 64,
                  decoration: BoxDecoration(
                    gradient: g, borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(color: g.colors.first.withValues(alpha: .3), blurRadius: 14, offset: const Offset(0, 6))],
                  ),
                  child: Center(child: Icon(icon, color: Colors.white, size: 28)),
                ),
                const SizedBox(height: 8),
                Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, height: 1.2)),
              ]),
            ).animate().fadeIn(delay: (60 * i).ms).scaleXY(begin: .9),
          ),
      ]);
    });
  }
}

class _AccountsGrid extends StatelessWidget {
  const _AccountsGrid(this.accounts);
  final List<LoyaltyAccount> accounts;
  @override
  Widget build(BuildContext context) {
    final cols = context.columns(minTileWidth: 340);
    return LayoutBuilder(builder: (context, c) {
      final w = (c.maxWidth - (cols - 1) * 14) / cols;
      return Wrap(spacing: 14, runSpacing: 14, children: [
        for (final a in accounts) SizedBox(width: w, child: _AccountCard(a)),
      ]);
    });
  }
}

class _AccountCard extends StatelessWidget {
  const _AccountCard(this.a);
  final LoyaltyAccount a;
  @override
  Widget build(BuildContext context) => AppCard(
        onTap: () => context.push('/center/${a.centerId}'),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Avatar(a.centerName.isNotEmpty ? a.centerName[0] : '?', size: 42, gradient: AppColors.nightGradient),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(a.centerName, style: context.text.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(a.lastVisit != null ? 'Dernière visite ${relativeDays(a.lastVisit!)}' : 'Aucune visite',
                    style: TextStyle(color: context.muted, fontSize: 12)),
              ]),
            ),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(fmtNum(a.balance), style: context.text.titleLarge?.copyWith(color: AppColors.primary, fontWeight: FontWeight.w800)),
              Text('points', style: TextStyle(color: context.muted, fontSize: 11)),
            ]),
          ]),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: a.progress),
              duration: const Duration(milliseconds: 900),
              curve: Curves.easeOutCubic,
              builder: (_, v, _) => LinearProgressIndicator(
                value: v, minHeight: 8, backgroundColor: context.borderColor,
                valueColor: const AlwaysStoppedAnimation(AppColors.cyan),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            a.nextRewardName == null
                ? '🎉 Toutes les récompenses sont à votre portée !'
                : 'Encore ${a.nextRewardPoints! - a.balance} pts pour « ${a.nextRewardName} »',
            style: TextStyle(color: context.muted, fontSize: 12, fontWeight: FontWeight.w600),
          ),
          if (a.nextExpiryAt != null && a.nextExpiryPoints > 0) ...[
            const SizedBox(height: 8),
            _ExpiryLine(a),
          ],
        ]),
      );
}

class _EcoTeaser extends StatelessWidget {
  const _EcoTeaser(this.e);
  final EcoStats e;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 22),
        child: GradientCard(
          gradient: AppColors.ecoGradient,
          onTap: () => context.push('/eco'),
          child: Row(children: [
            const Icon(Icons.eco_rounded, color: Colors.white, size: 40),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Niveau ${e.level?.name ?? '—'}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18)),
                Text('${fmtNum(e.totalLiters.round())} L d\'eau économisés grâce à vos lavages',
                    style: TextStyle(color: Colors.white.withValues(alpha: .9))),
              ]),
            ),
            const Icon(Icons.chevron_right_rounded, color: Colors.white),
          ]),
        ),
      );
}


/// « ⏳ 150 pts expirent le 12 mars » — mis en avant quand l'échéance approche.
class _ExpiryLine extends StatelessWidget {
  const _ExpiryLine(this.a);
  final LoyaltyAccount a;
  @override
  Widget build(BuildContext context) {
    final soon = a.expiresWithin(30);
    final color = soon ? AppColors.amber : context.muted;
    return Container(
      padding: soon ? const EdgeInsets.symmetric(horizontal: 10, vertical: 6) : EdgeInsets.zero,
      decoration: soon
          ? BoxDecoration(color: AppColors.amber.withValues(alpha: .12), borderRadius: BorderRadius.circular(10))
          : null,
      child: Row(children: [
        Icon(Icons.hourglass_bottom_rounded, size: 15, color: color),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            '${fmtNum(a.nextExpiryPoints)} pts expirent le ${fmtDate(a.nextExpiryAt!)}',
            style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ),
      ]),
    );
  }
}

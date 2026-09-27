import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lavpro_core/lavpro_core.dart';

import '../../../state/providers.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});
  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    // Les notifications affichées sont considérées comme lues.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ref.read(repoProvider).readAll();
      if (mounted) ref.invalidate(unreadProvider);
    });
  }

  (IconData, Gradient) _style(String type) => switch (type) {
        'wash' => (Icons.local_car_wash_rounded, AppColors.gradient),
        'reminder' => (Icons.alarm_rounded, AppColors.warmGradient),
        'referral' => (Icons.card_giftcard_rounded, AppColors.violetGradient),
        'promotion' => (Icons.local_offer_rounded, AppColors.violetGradient),
        'bonus' => (Icons.redeem_rounded, AppColors.ecoGradient),
        'booking' => (Icons.event_rounded, AppColors.nightGradient),
        'points_expiry' => (Icons.hourglass_bottom_rounded, AppColors.warmGradient),
        'points_expired' => (Icons.hourglass_disabled_rounded, AppColors.nightGradient),
        _ => (Icons.notifications_rounded, AppColors.gradient),
      };

  @override
  Widget build(BuildContext context) {
    final list = ref.watch(notificationsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(notificationsProvider.future),
        child: ListView(
          padding: EdgeInsets.all(context.pagePadding),
          children: [
            MaxWidth(
              maxWidth: 720,
              child: AsyncView(
                value: list,
                onRetry: () => ref.invalidate(notificationsProvider),
                builder: (items) => items.isEmpty
                    ? const EmptyState(icon: Icons.notifications_off_rounded, title: 'Aucune notification',
                        message: 'Vos rappels, cadeaux et offres apparaîtront ici.')
                    : Column(children: [
                        for (final n in items)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: AppCard(
                              color: n.isRead ? null : AppColors.primary.withValues(alpha: context.isDark ? .12 : .05),
                              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                IconBadge(_style(n.type).$1, gradient: _style(n.type).$2, size: 42),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    Text(n.title, style: const TextStyle(fontWeight: FontWeight.w800)),
                                    const SizedBox(height: 3),
                                    Text(n.body, style: TextStyle(color: context.muted, height: 1.35)),
                                    const SizedBox(height: 6),
                                    Text(relativeDays(n.createdAt), style: TextStyle(color: context.muted, fontSize: 11)),
                                  ]),
                                ),
                                if (!n.isRead)
                                  Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle)),
                              ]),
                            ),
                          ),
                      ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

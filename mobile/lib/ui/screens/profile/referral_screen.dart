import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/format.dart';
import '../../../core/responsive.dart';
import '../../../core/theme.dart';
import '../../../models/json.dart';
import '../../../state/providers.dart';
import '../../widgets/common.dart';

class ReferralScreen extends ConsumerWidget {
  const ReferralScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
        appBar: AppBar(title: const Text('Parrainage')),
        body: ListView(padding: EdgeInsets.all(context.pagePadding), children: [
          MaxWidth(
            maxWidth: 760,
            child: AsyncView(
              value: ref.watch(referralProvider),
              builder: (r) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                GradientCard(
                  gradient: AppColors.warmGradient,
                  child: Column(children: [
                    const Icon(Icons.card_giftcard_rounded, color: Colors.white, size: 54),
                    const SizedBox(height: 10),
                    const Text('Invitez vos amis,\ngagnez des points ensemble',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800, height: 1.2)),
                    const SizedBox(height: 8),
                    Text('Vous et votre ami recevez des points bonus dès son premier lavage.',
                        textAlign: TextAlign.center, style: TextStyle(color: Colors.white.withValues(alpha: .9))),
                    const SizedBox(height: 20),
                    GestureDetector(
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: r.code));
                        showSnack(context, 'Code copié');
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Text(r.code, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: 4, color: AppColors.ink)),
                          const SizedBox(width: 12),
                          const Icon(Icons.copy_rounded, color: AppColors.amber),
                        ]),
                      ),
                    ),
                  ]),
                ),
                const SizedBox(height: 16),
                GradientButton(
                  label: 'Partager mon code',
                  icon: Icons.ios_share_rounded,
                  onPressed: () => SharePlus.instance.share(ShareParams(text: r.shareMessage)),
                ),
                const SizedBox(height: 16),
                Row(children: [
                  Expanded(child: _stat(context, '${r.invited}', 'amis inscrits')),
                  const SizedBox(width: 10),
                  Expanded(child: _stat(context, '${r.rewarded}', 'parrainages validés')),
                  const SizedBox(width: 10),
                  Expanded(child: _stat(context, fmtNum(r.points), 'points gagnés')),
                ]),
                if (r.friends.isNotEmpty) ...[
                  const SectionHeader('Mes filleuls'),
                  AppCard(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    child: Column(children: [
                      for (final f in r.friends)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Avatar((f['first_name'] as String).substring(0, 1), size: 40, gradient: AppColors.warmGradient),
                          title: Text(f['first_name'] as String, style: const TextStyle(fontWeight: FontWeight.w700)),
                          subtitle: Text('Inscrit ${relativeDays(parseDate(f['joined_at'])!)}'),
                          trailing: f['rewarded'] == true
                              ? const Pill('Validé', icon: Icons.check_rounded, color: AppColors.eco)
                              : const Pill('1er lavage en attente', color: AppColors.amber),
                        ),
                    ]),
                  ),
                ],
              ]),
            ),
          ),
        ]),
      );

  Widget _stat(BuildContext context, String v, String l) => AppCard(
        padding: const EdgeInsets.all(14),
        child: Column(children: [
          Text(v, style: context.text.titleLarge?.copyWith(fontWeight: FontWeight.w800, color: AppColors.amber)),
          Text(l, textAlign: TextAlign.center, style: TextStyle(color: context.muted, fontSize: 11)),
        ]),
      );
}

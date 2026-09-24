import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/format.dart';
import '../../../core/theme.dart';
import '../../../state/providers.dart';
import '../../widgets/common.dart';

/// Carte de fidélité : QR code unique à présenter au centre.
class CardScreen extends ConsumerWidget {
  const CardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final accounts = ref.watch(accountsProvider).value ?? const [];
    if (user == null) return const SizedBox.shrink();
    final total = accounts.fold<int>(0, (a, b) => a + b.balance);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.nightGradient),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(children: [
                  const Text('Ma carte Lavpro', style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  Text('Présentez ce code au gérant pour cumuler vos points',
                      textAlign: TextAlign.center, style: TextStyle(color: Colors.white.withValues(alpha: .7))),
                  const SizedBox(height: 28),
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(32),
                      boxShadow: [BoxShadow(color: AppColors.cyan.withValues(alpha: .35), blurRadius: 60, offset: const Offset(0, 20))],
                    ),
                    child: Column(children: [
                      Row(children: [
                        Avatar(user.initials, size: 44),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(user.fullName, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: AppColors.ink)),
                            Text('Membre depuis ${fmtDate(user.createdAt)}', style: const TextStyle(color: Color(0xFF64748B), fontSize: 12)),
                          ]),
                        ),
                        ShaderMask(
                          shaderCallback: (r) => AppColors.gradient.createShader(r),
                          child: const Icon(Icons.water_drop_rounded, color: Colors.white, size: 30),
                        ),
                      ]),
                      const SizedBox(height: 20),
                      QrImageView(
                        data: user.qrPayload,
                        size: 240,
                        eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.circle, color: AppColors.ink),
                        dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.circle, color: AppColors.ink),
                      ).animate().fadeIn(duration: 500.ms).scaleXY(begin: .9),
                      const SizedBox(height: 16),
                      Pressable(
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: user.memberCode));
                          showSnack(context, 'Code membre copié');
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                          decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(14)),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Text(user.memberCode.split('').join(' '),
                                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, letterSpacing: 2, color: AppColors.ink)),
                            const SizedBox(width: 10),
                            const Icon(Icons.copy_rounded, size: 18, color: Color(0xFF64748B)),
                          ]),
                        ),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 24),
                  Row(children: [
                    Expanded(child: _stat('Points', fmtNum(total))),
                    const SizedBox(width: 12),
                    Expanded(child: _stat('Centres', '${accounts.length}')),
                  ]),
                  const SizedBox(height: 20),
                  TextButton.icon(
                    onPressed: () async {
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (c) => AlertDialog(
                          title: const Text('Régénérer mon QR code ?'),
                          content: const Text("L'ancien code ne fonctionnera plus. Utile si quelqu'un a pu le copier."),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Annuler')),
                            FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Régénérer')),
                          ],
                        ),
                      );
                      if (ok == true) {
                        await ref.read(authProvider.notifier).regenerateQr();
                        if (context.mounted) showSnack(context, 'Nouveau QR code généré');
                      }
                    },
                    icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
                    label: const Text('Régénérer le QR code', style: TextStyle(color: Colors.white70)),
                  ),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _stat(String label, String value) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: .1)),
        ),
        child: Column(children: [
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800)),
          Text(label, style: TextStyle(color: Colors.white.withValues(alpha: .7))),
        ]),
      );
}

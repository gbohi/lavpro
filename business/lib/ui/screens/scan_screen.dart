import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lavpro_core/lavpro_core.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../state/providers.dart';
import '../widgets/center_header.dart';
import 'validate_screen.dart';

/// Scan du QR code client (ou saisie du code membre), client de passage, remise d'une récompense.
class ScanScreen extends ConsumerStatefulWidget {
  const ScanScreen({super.key});
  @override
  ConsumerState<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends ConsumerState<ScanScreen> {
  final _code = TextEditingController();
  final _rewardCode = TextEditingController();
  final _scanner = MobileScannerController(detectionSpeed: DetectionSpeed.noDuplicates);
  bool _busy = false;
  bool _camera = true;

  @override
  void dispose() {
    _scanner.dispose();
    super.dispose();
  }

  Future<void> _lookup(String code) async {
    final id = ref.read(selectedCenterProvider);
    if (_busy || id == null || code.trim().isEmpty) return;
    setState(() => _busy = true);
    try {
      final client = await ref.read(repoProvider).lookup(id, code.trim());
      if (!mounted) return;
      _code.clear();
      await _scanner.stop();
      if (!mounted) return;
      await context.push('/validate', extra: ValidateRequest.client(client));
      if (mounted && _camera) await _scanner.start();
    } catch (e) {
      if (mounted) showSnack(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _giveReward() async {
    final id = ref.read(selectedCenterProvider);
    final code = _rewardCode.text.trim().toUpperCase();
    if (id == null || code.isEmpty) return;
    try {
      final r = await ref.read(repoProvider).giveReward(id, code);
      _rewardCode.clear();
      if (mounted) showSnack(context, '« ${r.rewardName} » remis au client 🎁');
    } catch (e) {
      if (mounted) showSnack(context, e.toString(), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pad = context.pagePadding;
    return Scaffold(
      body: SafeArea(
        child: ListView(padding: EdgeInsets.fromLTRB(pad, 12, pad, 32), children: [
          MaxWidth(
            maxWidth: 620,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              CenterHeader(
                title: 'Scanner un client',
                trailing: IconButton.filledTonal(
                  tooltip: _camera ? 'Couper la caméra' : 'Activer la caméra',
                  onPressed: () async {
                    setState(() => _camera = !_camera);
                    _camera ? await _scanner.start() : await _scanner.stop();
                  },
                  icon: Icon(_camera ? Icons.videocam_off_rounded : Icons.videocam_rounded),
                ),
              ),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: AspectRatio(
                  aspectRatio: 1,
                  child: Stack(fit: StackFit.expand, children: [
                    if (_camera)
                      MobileScanner(
                        controller: _scanner,
                        onDetect: (capture) {
                          final v = capture.barcodes.firstOrNull?.rawValue;
                          if (v != null) _lookup(v);
                        },
                        errorBuilder: (context, error) => _CameraPlaceholder(message: 'Caméra indisponible : ${error.errorCode.name}'),
                      )
                    else
                      const _CameraPlaceholder(message: 'Caméra en pause'),
                    Center(
                      child: Container(
                        width: 220, height: 220,
                        decoration: BoxDecoration(
                            border: Border.all(color: AppColors.cyan, width: 3), borderRadius: BorderRadius.circular(26)),
                      ).animate(onPlay: (c) => c.repeat(reverse: true)).scaleXY(begin: .95, end: 1.03, duration: 1100.ms),
                    ),
                    if (_busy) Container(color: Colors.black45, child: const Center(child: CircularProgressIndicator())),
                  ]),
                ),
              ),
              const SizedBox(height: 18),
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: _code,
                    textCapitalization: TextCapitalization.characters,
                    textInputAction: TextInputAction.search,
                    decoration: const InputDecoration(hintText: 'Code membre du client', prefixIcon: Icon(Icons.badge_rounded)),
                    onSubmitted: _lookup,
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  height: 56,
                  child: FilledButton(
                    style: FilledButton.styleFrom(minimumSize: const Size(62, 56)),
                    onPressed: () => _lookup(_code.text),
                    child: const Icon(Icons.search_rounded),
                  ),
                ),
              ]),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => context.push('/validate', extra: const ValidateRequest.walkIn()),
                icon: const Icon(Icons.person_off_rounded),
                label: const Text('Client de passage (sans compte)'),
              ),
              const SectionHeader('Remettre une récompense'),
              AppCard(
                child: Row(children: [
                  Expanded(
                    child: TextField(
                      controller: _rewardCode,
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(hintText: 'Code de retrait', prefixIcon: Icon(Icons.redeem_rounded)),
                      onSubmitted: (_) => _giveReward(),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    height: 56,
                    child: FilledButton(
                      style: FilledButton.styleFrom(minimumSize: const Size(90, 56), backgroundColor: AppColors.eco),
                      onPressed: _giveReward,
                      child: const Text('Valider'),
                    ),
                  ),
                ]),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _CameraPlaceholder extends StatelessWidget {
  const _CameraPlaceholder({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => Container(
        decoration: const BoxDecoration(gradient: AppColors.nightGradient),
        alignment: Alignment.center,
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.qr_code_2_rounded, size: 80, color: Colors.white.withValues(alpha: .35)),
          const SizedBox(height: 10),
          Text(message, textAlign: TextAlign.center, style: TextStyle(color: Colors.white.withValues(alpha: .7))),
        ]),
      );
}

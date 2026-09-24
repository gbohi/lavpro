import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/theme.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Container(
          decoration: const BoxDecoration(gradient: AppColors.nightGradient),
          alignment: Alignment.center,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 96, height: 96,
              decoration: BoxDecoration(
                gradient: AppColors.gradient, borderRadius: BorderRadius.circular(30),
                boxShadow: [BoxShadow(color: AppColors.cyan.withValues(alpha: .5), blurRadius: 40)],
              ),
              child: const Icon(Icons.water_drop_rounded, color: Colors.white, size: 52),
            ).animate(onPlay: (c) => c.repeat(reverse: true)).scaleXY(begin: .92, end: 1.04, duration: 900.ms),
            const SizedBox(height: 22),
            const Text('Lavpro', style: TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w800, letterSpacing: -1)),
            const SizedBox(height: 4),
            Text('Gagnez, soyez récompensé, roulez propre', style: TextStyle(color: Colors.white.withValues(alpha: .7))),
          ]),
        ),
      );
}

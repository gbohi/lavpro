import 'package:flutter/material.dart';
import 'package:lavpro_core/lavpro_core.dart';

import '../widgets/brand.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
        body: Container(
          decoration: const BoxDecoration(gradient: AppColors.nightGradient),
          alignment: Alignment.center,
          child: const Column(mainAxisSize: MainAxisSize.min, children: [
            BusinessLogo(size: 48),
            SizedBox(height: 28),
            SizedBox(width: 26, height: 26, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white)),
          ]),
        ),
      );
}

import 'package:flutter/material.dart';
import 'package:lavpro_core/lavpro_core.dart';


class AuthScaffold extends StatelessWidget {
  const AuthScaffold({super.key, required this.title, required this.subtitle, required this.child});
  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Stack(children: [
          Container(height: 380, decoration: const BoxDecoration(gradient: AppColors.nightGradient)),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                    ),
                    const SizedBox(height: 8),
                    Text(title, style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w800, letterSpacing: -.8)),
                    const SizedBox(height: 6),
                    Text(subtitle, style: TextStyle(color: Colors.white.withValues(alpha: .75))),
                    const SizedBox(height: 26),
                    Container(
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        color: context.colors.surface,
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .1), blurRadius: 40, offset: const Offset(0, 20))],
                      ),
                      child: child,
                    ),
                  ]),
                ),
              ),
            ),
          ),
        ]),
      );
}

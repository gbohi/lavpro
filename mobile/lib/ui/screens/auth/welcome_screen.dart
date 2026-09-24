import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:lavpro_core/lavpro_core.dart';


class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});
  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  final _page = PageController();
  int _index = 0;

  static const _slides = [
    (Icons.qr_code_2_rounded, 'Une carte, tous vos lavages',
        'Présentez votre QR code Lavpro au centre : vos points sont crédités instantanément.', AppColors.gradient),
    (Icons.redeem_rounded, 'Des récompenses généreuses',
        'Lavages offerts, senteurs, tapis, bidons d\'huile… Chaque centre a ses cadeaux.', AppColors.violetGradient),
    (Icons.near_me_rounded, 'Le bon centre, au bon moment',
        'Trouvez le centre le plus proche, voyez l\'affluence en direct et réservez votre créneau.', AppColors.warmGradient),
    (Icons.eco_rounded, 'Roulez propre, pensez vert',
        'Suivez l\'eau économisée grâce à vos lavages et débloquez des offres écoresponsables.', AppColors.ecoGradient),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.nightGradient),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                  child: Row(children: [
                    Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(gradient: AppColors.gradient, borderRadius: BorderRadius.circular(12)),
                      child: const Icon(Icons.water_drop_rounded, color: Colors.white),
                    ),
                    const SizedBox(width: 10),
                    const Text('Lavpro', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
                  ]),
                ),
                Expanded(
                  child: PageView.builder(
                    controller: _page,
                    itemCount: _slides.length,
                    onPageChanged: (i) => setState(() => _index = i),
                    itemBuilder: (_, i) {
                      final (icon, title, text, gradient) = _slides[i];
                      return Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Container(
                            width: 180, height: 180,
                            decoration: BoxDecoration(
                              gradient: gradient, shape: BoxShape.circle,
                              boxShadow: [BoxShadow(color: gradient.colors.first.withValues(alpha: .5), blurRadius: 60)],
                            ),
                            child: Icon(icon, size: 84, color: Colors.white),
                          ).animate(key: ValueKey(i)).scale(duration: 500.ms, curve: Curves.easeOutBack).fadeIn(),
                          const SizedBox(height: 48),
                          Text(title, textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w800, height: 1.15, letterSpacing: -.8))
                              .animate(key: ValueKey('t$i')).fadeIn(delay: 100.ms).slideY(begin: .2),
                          const SizedBox(height: 14),
                          Text(text, textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.white.withValues(alpha: .72), fontSize: 16, height: 1.5))
                              .animate(key: ValueKey('s$i')).fadeIn(delay: 200.ms),
                        ]),
                      );
                    },
                  ),
                ),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  for (var i = 0; i < _slides.length; i++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: i == _index ? 26 : 8, height: 8,
                      decoration: BoxDecoration(
                        color: i == _index ? AppColors.cyan : Colors.white24, borderRadius: BorderRadius.circular(8)),
                    ),
                ]),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 12),
                  child: GradientButton(
                    label: _index == _slides.length - 1 ? 'Créer mon compte' : 'Suivant',
                    icon: Icons.arrow_forward_rounded,
                    onPressed: () => _index == _slides.length - 1
                        ? context.push('/register')
                        : _page.nextPage(duration: const Duration(milliseconds: 350), curve: Curves.easeOutCubic),
                  ),
                ),
                TextButton(
                  onPressed: () => context.push('/login'),
                  child: const Text("J'ai déjà un compte", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                ),
                const SizedBox(height: 12),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

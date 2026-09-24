import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lavpro_core/lavpro_core.dart';

import '../../state/providers.dart';
import '../widgets/brand.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  bool _obscure = true;

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await ref.read(authProvider.notifier).login(_email.text.trim(), _password.text);
    } catch (e) {
      if (mounted) showSnack(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Container(
          decoration: const BoxDecoration(gradient: AppColors.nightGradient),
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    const Center(child: BusinessLogo(size: 44)),
                    const SizedBox(height: 36),
                    const Text('Pilotez votre centre\ndepuis votre téléphone',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800, height: 1.15, letterSpacing: -.8))
                        .animate().fadeIn().slideY(begin: .15),
                    const SizedBox(height: 10),
                    Text('Scannez vos clients, validez les lavages, suivez votre activité en temps réel.',
                        textAlign: TextAlign.center, style: TextStyle(color: Colors.white.withValues(alpha: .75), height: 1.4)),
                    const SizedBox(height: 30),
                    Container(
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(color: context.colors.surface, borderRadius: BorderRadius.circular(28)),
                      child: Form(
                        key: _form,
                        child: AutofillGroup(
                          child: Column(children: [
                            TextFormField(
                              controller: _email,
                              keyboardType: TextInputType.emailAddress,
                              autofillHints: const [AutofillHints.email],
                              decoration: const InputDecoration(labelText: 'E-mail professionnel', prefixIcon: Icon(Icons.mail_outline_rounded)),
                              validator: (v) => (v == null || !v.contains('@')) ? 'E-mail invalide' : null,
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _password,
                              obscureText: _obscure,
                              autofillHints: const [AutofillHints.password],
                              onFieldSubmitted: (_) => _submit(),
                              decoration: InputDecoration(
                                labelText: 'Mot de passe',
                                prefixIcon: const Icon(Icons.lock_outline_rounded),
                                suffixIcon: IconButton(
                                  icon: Icon(_obscure ? Icons.visibility_rounded : Icons.visibility_off_rounded),
                                  onPressed: () => setState(() => _obscure = !_obscure),
                                ),
                              ),
                              validator: (v) => (v == null || v.isEmpty) ? 'Mot de passe requis' : null,
                            ),
                            const SizedBox(height: 22),
                            GradientButton(label: 'Se connecter', icon: Icons.login_rounded, loading: _loading, onPressed: _submit),
                          ]),
                        ),
                      ),
                    ).animate().fadeIn(delay: 150.ms).slideY(begin: .08),
                    const SizedBox(height: 22),
                    Text("Votre centre n'est pas encore inscrit ? Créez-le depuis l'Espace Pro web.",
                        textAlign: TextAlign.center, style: TextStyle(color: Colors.white.withValues(alpha: .6), fontSize: 13)),
                  ]),
                ),
              ),
            ),
          ),
        ),
      );
}

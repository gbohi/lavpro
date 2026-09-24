import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme.dart';
import '../../../state/providers.dart';
import '../../widgets/common.dart';
import 'auth_scaffold.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key, this.referralCode});
  final String? referralCode;
  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _form = GlobalKey<FormState>();
  final _first = TextEditingController();
  final _last = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  late final _referral = TextEditingController(text: widget.referralCode ?? '');
  bool _loading = false;
  bool _showReferral = false;

  @override
  void initState() {
    super.initState();
    _showReferral = (widget.referralCode ?? '').isNotEmpty;
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await ref.read(authProvider.notifier).register(
            email: _email.text.trim(), password: _password.text, firstName: _first.text.trim(),
            lastName: _last.text.trim(), phone: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
            referralCode: _referral.text.trim(),
          );
    } catch (e) {
      if (mounted) showSnack(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => AuthScaffold(
        title: 'Rejoignez Lavpro',
        subtitle: 'Une seule inscription, valable dans tous les centres partenaires.',
        child: Form(
          key: _form,
          child: Column(children: [
            Row(children: [
              Expanded(
                child: TextFormField(
                  controller: _first,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Prénom'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Requis' : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _last,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Nom'),
                ),
              ),
            ]),
            const SizedBox(height: 14),
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'E-mail', prefixIcon: Icon(Icons.mail_outline_rounded)),
              validator: (v) => (v == null || !v.contains('@')) ? 'E-mail invalide' : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Téléphone (optionnel)', prefixIcon: Icon(Icons.phone_rounded)),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _password,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Mot de passe', prefixIcon: Icon(Icons.lock_outline_rounded)),
              validator: (v) => (v == null || v.length < 6) ? '6 caractères minimum' : null,
            ),
            const SizedBox(height: 10),
            if (_showReferral)
              TextFormField(
                controller: _referral,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(labelText: 'Code de parrainage', prefixIcon: Icon(Icons.card_giftcard_rounded)),
              )
            else
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => setState(() => _showReferral = true),
                  icon: const Icon(Icons.card_giftcard_rounded, color: AppColors.violet),
                  label: const Text("J'ai un code de parrainage"),
                ),
              ),
            const SizedBox(height: 18),
            GradientButton(label: 'Créer mon compte', icon: Icons.arrow_forward_rounded, loading: _loading, onPressed: _submit),
            const SizedBox(height: 10),
            TextButton(onPressed: () => context.pushReplacement('/login'), child: const Text("J'ai déjà un compte")),
          ]),
        ),
      );
}

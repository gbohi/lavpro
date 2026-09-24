import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme.dart';
import '../models/center.dart';

/// Carte avec dégradé et reflets, utilisée pour les éléments "héros".
class GradientCard extends StatelessWidget {
  const GradientCard({super.key, required this.child, this.gradient = AppColors.gradient,
      this.padding = const EdgeInsets.all(22), this.radius = 26, this.onTap});
  final Widget child;
  final Gradient gradient;
  final EdgeInsets padding;
  final double radius;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = (gradient as LinearGradient).colors;
    return Pressable(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(radius),
          boxShadow: [BoxShadow(color: colors.first.withValues(alpha: .35), blurRadius: 28, offset: const Offset(0, 12))],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: Stack(children: [
            Positioned(right: -50, top: -60, child: _bubble(170)),
            Positioned(right: 40, bottom: -70, child: _bubble(120)),
            Padding(padding: padding, child: child),
          ]),
        ),
      ),
    );
  }

  Widget _bubble(double s) => Container(
      width: s, height: s, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: .1)));
}

/// Carte standard du design system.
class AppCard extends StatelessWidget {
  const AppCard({super.key, required this.child, this.padding = const EdgeInsets.all(18), this.onTap, this.color});
  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) => Pressable(
        onTap: onTap,
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: color ?? context.colors.surface,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: context.borderColor),
            boxShadow: context.isDark
                ? null
                : [BoxShadow(color: const Color(0xFF0F172A).withValues(alpha: .05), blurRadius: 20, offset: const Offset(0, 8))],
          ),
          child: child,
        ),
      );
}

/// Léger effet d'enfoncement au toucher.
class Pressable extends StatefulWidget {
  const Pressable({super.key, required this.child, this.onTap});
  final Widget child;
  final VoidCallback? onTap;
  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;
  @override
  Widget build(BuildContext context) {
    if (widget.onTap == null) return widget.child;
    return GestureDetector(
      onTapDown: (_) => setState(() => _down = true),
      onTapCancel: () => setState(() => _down = false),
      onTapUp: (_) => setState(() => _down = false),
      onTap: widget.onTap,
      child: AnimatedScale(scale: _down ? .97 : 1, duration: const Duration(milliseconds: 120), child: widget.child),
    );
  }
}

class IconBadge extends StatelessWidget {
  const IconBadge(this.icon, {super.key, this.gradient = AppColors.gradient, this.size = 46});
  final IconData icon;
  final Gradient gradient;
  final double size;
  @override
  Widget build(BuildContext context) => Container(
        width: size, height: size,
        decoration: BoxDecoration(gradient: gradient, borderRadius: BorderRadius.circular(size * .3)),
        child: Icon(icon, color: Colors.white, size: size * .5),
      );
}

class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.action, this.onAction});
  final String title;
  final String? action;
  final VoidCallback? onAction;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 26, bottom: 12),
        child: Row(children: [
          Expanded(child: Text(title, style: context.text.titleLarge)),
          if (action != null)
            TextButton(onPressed: onAction, child: Text(action!, style: const TextStyle(fontWeight: FontWeight.w700))),
        ]),
      );
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, this.message, this.action});
  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 88, height: 88,
            decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: .1), borderRadius: BorderRadius.circular(28)),
            child: Icon(icon, size: 42, color: AppColors.primary),
          ).animate().scale(duration: 400.ms, curve: Curves.easeOutBack),
          const SizedBox(height: 18),
          Text(title, style: context.text.titleMedium, textAlign: TextAlign.center),
          if (message != null) ...[
            const SizedBox(height: 6),
            Text(message!, style: TextStyle(color: context.muted), textAlign: TextAlign.center),
          ],
          if (action != null) ...[const SizedBox(height: 18), action!],
        ]),
      );
}

/// Affiche une valeur asynchrone avec états de chargement et d'erreur soignés.
class AsyncView<T> extends StatelessWidget {
  const AsyncView({super.key, required this.value, required this.builder, this.onRetry, this.loading});
  final AsyncValue<T> value;
  final Widget Function(T data) builder;
  final VoidCallback? onRetry;
  final Widget? loading;

  @override
  Widget build(BuildContext context) => value.when(
        skipLoadingOnRefresh: true,
        data: builder,
        loading: () => loading ?? const SkeletonList(),
        error: (e, _) => EmptyState(
          icon: Icons.cloud_off_rounded,
          title: 'Oups…',
          message: e.toString(),
          action: onRetry == null ? null : OutlinedButton(onPressed: onRetry, child: const Text('Réessayer')),
        ),
      );
}

class SkeletonList extends StatelessWidget {
  const SkeletonList({super.key, this.count = 3, this.height = 90});
  final int count;
  final double height;
  @override
  Widget build(BuildContext context) => Column(
        children: List.generate(
          count,
          (i) => Container(
            height: height,
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(color: context.borderColor.withValues(alpha: .6), borderRadius: BorderRadius.circular(20)),
          ).animate(onPlay: (c) => c.repeat()).shimmer(duration: 1200.ms, color: context.colors.surface.withValues(alpha: .6)),
        ),
      );
}

class Pill extends StatelessWidget {
  const Pill(this.label, {super.key, this.icon, this.color = AppColors.primary, this.filled = false});
  final String label;
  final IconData? icon;
  final Color color;
  final bool filled;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: filled ? color : color.withValues(alpha: .12),
          borderRadius: BorderRadius.circular(40),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[Icon(icon, size: 14, color: filled ? Colors.white : color), const SizedBox(width: 4)],
          Text(label, style: TextStyle(color: filled ? Colors.white : color, fontWeight: FontWeight.w700, fontSize: 12)),
        ]),
      );
}

class OccupancyBadge extends StatelessWidget {
  const OccupancyBadge(this.o, {super.key, this.compact = false});
  final Occupancy? o;
  final bool compact;

  static (String, Color, IconData) describe(Occupancy? o) => switch (o?.level) {
        'low' => ('Fluide', AppColors.eco, Icons.bolt_rounded),
        'moderate' => ('Modérée', AppColors.amber, Icons.hourglass_bottom_rounded),
        'high' => ('Forte affluence', AppColors.red, Icons.groups_rounded),
        'closed' => ('Fermé', Colors.grey, Icons.nightlight_round),
        _ => ('—', Colors.grey, Icons.help_outline_rounded),
      };

  @override
  Widget build(BuildContext context) {
    final (label, color, icon) = describe(o);
    final wait = o != null && o!.isOpen && o!.waitMinutes > 0 && !compact ? ' · ~${o!.waitMinutes} min' : '';
    return Pill('$label$wait', icon: icon, color: color);
  }
}

class Avatar extends StatelessWidget {
  const Avatar(this.initials, {super.key, this.size = 44, this.gradient = AppColors.gradient});
  final String initials;
  final double size;
  final Gradient gradient;
  @override
  Widget build(BuildContext context) => Container(
        width: size, height: size, alignment: Alignment.center,
        decoration: BoxDecoration(gradient: gradient, borderRadius: BorderRadius.circular(size * .32)),
        child: Text(initials.toUpperCase(),
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: size * .36)),
      );
}

void showSnack(BuildContext context, String message, {bool error = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Row(children: [
        Icon(error ? Icons.error_rounded : Icons.check_circle_rounded, color: Colors.white),
        const SizedBox(width: 10),
        Expanded(child: Text(message, style: const TextStyle(fontWeight: FontWeight.w600))),
      ]),
      backgroundColor: error ? AppColors.red : const Color(0xFF0F172A),
    ));
}

/// Bouton principal en dégradé avec état de chargement.
class GradientButton extends StatelessWidget {
  const GradientButton({super.key, required this.label, required this.onPressed, this.icon, this.loading = false,
      this.gradient = AppColors.gradient});
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool loading;
  final Gradient gradient;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;
    return Opacity(
      opacity: enabled ? 1 : .6,
      child: Pressable(
        onTap: enabled ? onPressed : null,
        child: Container(
          height: 56,
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: .3), blurRadius: 20, offset: const Offset(0, 8))],
          ),
          alignment: Alignment.center,
          child: loading
              ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.6, color: Colors.white))
              : Row(mainAxisSize: MainAxisSize.min, children: [
                  if (icon != null) ...[Icon(icon, color: Colors.white), const SizedBox(width: 10)],
                  Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
                ]),
        ),
      ),
    );
  }
}

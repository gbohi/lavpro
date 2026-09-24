import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lavpro_core/lavpro_core.dart';

import '../../state/providers.dart';

/// En-tête d'écran avec le centre courant (et changement de centre si plusieurs).
class CenterHeader extends ConsumerWidget {
  const CenterHeader({super.key, required this.title, this.trailing});
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final memberships = ref.watch(currentUserProvider)?.memberships ?? const [];
    final current = currentMembership(ref);
    return Row(children: [
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: memberships.length < 2 ? null : () => pickCenter(context, ref),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.storefront_rounded, size: 16, color: AppColors.primary),
              const SizedBox(width: 6),
              Flexible(
                child: Text(current?.centerName ?? '', maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700)),
              ),
              if (memberships.length > 1) const Icon(Icons.expand_more_rounded, size: 18, color: AppColors.primary),
            ]),
          ),
          Text(title, style: context.text.headlineSmall),
        ]),
      ),
      ?trailing,
    ]);
  }
}

Future<void> pickCenter(BuildContext context, WidgetRef ref) async {
  final memberships = ref.read(currentUserProvider)?.memberships ?? const [];
  final selected = ref.read(selectedCenterProvider);
  final id = await showModalBottomSheet<int>(
    context: context,
    showDragHandle: true,
    builder: (c) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('Mes centres', style: c.text.titleLarge),
        const SizedBox(height: 8),
        for (final m in memberships)
          ListTile(
            leading: Avatar(m.centerName.isEmpty ? '?' : m.centerName[0], size: 40, gradient: AppColors.nightGradient),
            title: Text(m.centerName, style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text(m.role == 'owner' ? 'Propriétaire' : 'Gestionnaire'),
            trailing: m.centerId == selected ? const Icon(Icons.check_circle_rounded, color: AppColors.primary) : null,
            onTap: () => Navigator.pop(c, m.centerId),
          ),
        const SizedBox(height: 12),
      ]),
    ),
  );
  if (id != null) ref.read(selectedCenterProvider.notifier).select(id);
}

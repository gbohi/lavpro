import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/responsive.dart';
import '../../../core/theme.dart';
import '../../../models/user.dart';
import '../../../state/providers.dart';
import '../../widgets/common.dart';

final _categoriesProvider = FutureProvider<List<String>>((ref) => ref.watch(repoProvider).vehicleCategories());

class VehiclesScreen extends ConsumerWidget {
  const VehiclesScreen({super.key});

  Future<void> _edit(BuildContext context, WidgetRef ref, [ClientVehicle? v]) async {
    final label = TextEditingController(text: v?.label ?? '');
    final plate = TextEditingController(text: v?.plate ?? '');
    final brand = TextEditingController(text: v?.brand ?? '');
    final color = TextEditingController(text: v?.color ?? '');
    String? category = v?.category;
    final categories = await ref.read(_categoriesProvider.future).catchError((_) => <String>[]);
    if (!context.mounted) return;
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (c) => StatefulBuilder(
        builder: (c, setState) => Padding(
          padding: EdgeInsets.fromLTRB(24, 0, 24, MediaQuery.viewInsetsOf(c).bottom + 24),
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text(v == null ? 'Nouveau véhicule' : 'Modifier le véhicule', style: c.text.titleLarge),
              const SizedBox(height: 16),
              TextField(controller: label, decoration: const InputDecoration(labelText: 'Nom (ex : Ma Corolla)')),
              const SizedBox(height: 12),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final cat in categories)
                  ChoiceChip(
                    label: Text(cat),
                    selected: category == cat,
                    onSelected: (_) => setState(() => category = cat),
                  ),
              ]),
              const SizedBox(height: 12),
              TextField(controller: plate, textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(labelText: 'Immatriculation')),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: TextField(controller: brand, decoration: const InputDecoration(labelText: 'Marque'))),
                const SizedBox(width: 12),
                Expanded(child: TextField(controller: color, decoration: const InputDecoration(labelText: 'Couleur'))),
              ]),
              const SizedBox(height: 20),
              GradientButton(label: 'Enregistrer', onPressed: () => Navigator.pop(c, true)),
            ]),
          ),
        ),
      ),
    );
    if (ok != true || label.text.trim().isEmpty) return;
    try {
      await ref.read(repoProvider).saveVehicle(ClientVehicle(
          id: v?.id ?? 0, label: label.text.trim(), category: category, plate: plate.text.trim().toUpperCase(),
          brand: brand.text.trim(), color: color.text.trim()));
      ref.invalidate(vehiclesProvider);
    } catch (e) {
      if (context.mounted) showSnack(context, e.toString(), error: true);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
        appBar: AppBar(title: const Text('Mes véhicules')),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _edit(context, ref),
          icon: const Icon(Icons.add_rounded),
          label: const Text('Ajouter'),
        ),
        body: ListView(padding: EdgeInsets.all(context.pagePadding), children: [
          MaxWidth(
            maxWidth: 760,
            child: AsyncView(
              value: ref.watch(vehiclesProvider),
              builder: (list) => list.isEmpty
                  ? const EmptyState(icon: Icons.directions_car_rounded, title: 'Aucun véhicule',
                      message: 'Ajoutez vos véhicules pour que le centre les retrouve plus vite.')
                  : Column(children: [
                      for (final v in list)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: AppCard(
                            onTap: () => _edit(context, ref, v),
                            child: Row(children: [
                              const IconBadge(Icons.directions_car_rounded),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text(v.label, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                                  Text([v.category, v.brand, v.color].where((e) => e != null && e.isNotEmpty).join(' · '),
                                      style: TextStyle(color: context.muted)),
                                  if (v.plate != null && v.plate!.isNotEmpty) ...[
                                    const SizedBox(height: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        border: Border.all(color: context.isDark ? Colors.white54 : AppColors.ink, width: 1.5),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(v.plate!, style: const TextStyle(fontWeight: FontWeight.w800, letterSpacing: 1.5)),
                                    ),
                                  ],
                                ]),
                              ),
                              IconButton(
                                onPressed: () async {
                                  await ref.read(repoProvider).deleteVehicle(v.id);
                                  ref.invalidate(vehiclesProvider);
                                },
                                icon: const Icon(Icons.delete_outline_rounded),
                              ),
                            ]),
                          ),
                        ),
                    ]),
            ),
          ),
        ]),
      );
}

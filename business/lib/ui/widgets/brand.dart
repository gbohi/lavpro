import 'package:flutter/material.dart';
import 'package:lavpro_core/lavpro_core.dart';

/// Identité visuelle « Lavpro Business » : logo Lavpro + badge Business doré.
class BusinessLogo extends StatelessWidget {
  const BusinessLogo({super.key, this.light = true, this.size = 40});
  final bool light;
  final double size;

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: size, height: size,
          decoration: BoxDecoration(gradient: AppColors.gradient, borderRadius: BorderRadius.circular(size * .3)),
          child: Icon(Icons.water_drop_rounded, color: Colors.white, size: size * .55),
        ),
        SizedBox(width: size * .28),
        Text('Lavpro', style: TextStyle(
            fontSize: size * .52, fontWeight: FontWeight.w800, letterSpacing: -.5,
            color: light ? Colors.white : context.colors.onSurface)),
        SizedBox(width: size * .18),
        const BusinessBadge(),
      ]);
}

class BusinessBadge extends StatelessWidget {
  const BusinessBadge({super.key});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFFFBBF24), Color(0xFFF59E0B)]),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Text('BUSINESS',
            style: TextStyle(color: Color(0xFF0B1220), fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 1.2)),
      );
}

/// Sélecteur de jour (précédent / aujourd'hui / suivant).
class DayPicker extends StatelessWidget {
  const DayPicker({super.key, required this.day, required this.onChanged});
  final DateTime day;
  final ValueChanged<DateTime> onChanged;

  @override
  Widget build(BuildContext context) {
    final today = DateUtils.isSameDay(day, DateTime.now());
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: Row(children: [
        IconButton(onPressed: () => onChanged(day.subtract(const Duration(days: 1))), icon: const Icon(Icons.chevron_left_rounded)),
        Expanded(
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () async {
              final d = await showDatePicker(
                  context: context, initialDate: day, firstDate: DateTime(2020), lastDate: DateTime(2100));
              if (d != null) onChanged(d);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(children: [
                Text(today ? "Aujourd'hui" : capitalize(fmtDayLong(day)), style: const TextStyle(fontWeight: FontWeight.w800)),
                if (today) Text(capitalize(fmtDayLong(day)), style: TextStyle(color: context.muted, fontSize: 12)),
              ]),
            ),
          ),
        ),
        IconButton(onPressed: () => onChanged(day.add(const Duration(days: 1))), icon: const Icon(Icons.chevron_right_rounded)),
      ]),
    );
  }
}

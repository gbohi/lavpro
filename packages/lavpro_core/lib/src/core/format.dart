import 'package:intl/intl.dart';

final _num = NumberFormat.decimalPattern('fr_FR');

String fmtNum(num v) => _num.format(v);
String fmtMoney(num v, String currency) => '${NumberFormat('#,##0', 'fr_FR').format(v)} $currency';
String fmtDate(DateTime d) => DateFormat('d MMM yyyy', 'fr_FR').format(d);
String fmtDateShort(DateTime d) => DateFormat('d MMM', 'fr_FR').format(d);
String fmtTime(DateTime d) => DateFormat('HH:mm', 'fr_FR').format(d);
String fmtDayLong(DateTime d) => DateFormat('EEEE d MMMM', 'fr_FR').format(d);
String fmtDateTime(DateTime d) => DateFormat("d MMM · HH:mm", 'fr_FR').format(d);

String relativeDays(DateTime d) {
  final diff = DateTime.now().difference(d);
  if (diff.inMinutes < 1) return "à l'instant";
  if (diff.inHours < 1) return 'il y a ${diff.inMinutes} min';
  if (diff.inDays < 1) return 'il y a ${diff.inHours} h';
  if (diff.inDays == 1) return 'hier';
  if (diff.inDays < 30) return 'il y a ${diff.inDays} jours';
  return fmtDate(d);
}

String capitalize(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

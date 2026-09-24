DateTime? parseDate(dynamic v) => v == null ? null : DateTime.parse(v as String).toLocal();
double toDouble(dynamic v) => v == null ? 0 : (v as num).toDouble();
int toInt(dynamic v) => v == null ? 0 : (v as num).toInt();
List<T> parseList<T>(dynamic v, T Function(Map<String, dynamic>) f) =>
    (v as List? ?? const []).map((e) => f(e as Map<String, dynamic>)).toList();

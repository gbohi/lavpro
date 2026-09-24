import 'json.dart';

class LoyaltyAccount {
  LoyaltyAccount({required this.centerId, required this.centerName, this.centerLogo, required this.balance,
      required this.totalEarned, required this.totalSpent, required this.visits, this.lastVisit, this.nextRewardName,
      this.nextRewardPoints});
  final int centerId;
  final String centerName;
  final String? centerLogo;
  final int balance;
  final int totalEarned;
  final int totalSpent;
  final int visits;
  final DateTime? lastVisit;
  final String? nextRewardName;
  final int? nextRewardPoints;

  double get progress => nextRewardPoints == null || nextRewardPoints == 0
      ? 1 : (balance / nextRewardPoints!).clamp(0, 1).toDouble();

  factory LoyaltyAccount.fromJson(Map<String, dynamic> j) => LoyaltyAccount(
        centerId: j['center_id'], centerName: j['center_name'], centerLogo: j['center_logo_url'], balance: j['balance'],
        totalEarned: j['total_earned'], totalSpent: j['total_spent'], visits: j['visits'],
        lastVisit: parseDate(j['last_visit_at']), nextRewardName: j['next_reward_name'],
        nextRewardPoints: j['next_reward_points'],
      );
}

class RewardVehicleCost {
  RewardVehicleCost({required this.vehicleTypeId, required this.pointsCost, this.vehicleTypeName});
  final int vehicleTypeId;
  final int pointsCost;
  final String? vehicleTypeName;
  factory RewardVehicleCost.fromJson(Map<String, dynamic> j) => RewardVehicleCost(
      vehicleTypeId: j['vehicle_type_id'], pointsCost: j['points_cost'], vehicleTypeName: j['vehicle_type_name']);
}

class Reward {
  Reward({required this.id, required this.centerId, required this.name, this.description, required this.category,
      this.imageUrl, required this.pointsCost, this.stock, this.ecoMinLiters, required this.affordable,
      this.lockedReason, this.serviceTypeId, this.serviceName, this.vehicleCosts = const [], int? minCost})
      : minCost = minCost ?? pointsCost;
  final int id;
  final int centerId;
  final String name;
  final String? description;
  final String category;
  final String? imageUrl;
  final int pointsCost;
  final int? stock;
  final double? ecoMinLiters;
  final bool affordable;
  final String? lockedReason;
  /// Lavage offert : service concerné (null = cadeau hors lavage).
  final int? serviceTypeId;
  final String? serviceName;
  /// Coûts par type de véhicule (vide = tous les véhicules au coût [pointsCost]).
  final List<RewardVehicleCost> vehicleCosts;
  final int minCost;

  bool get isWash => serviceTypeId != null;

  factory Reward.fromJson(Map<String, dynamic> j) => Reward(
        id: j['id'], centerId: j['center_id'], name: j['name'], description: j['description'],
        category: j['category'] ?? 'gift', imageUrl: j['image_url'], pointsCost: j['points_cost'], stock: j['stock'],
        ecoMinLiters: (j['eco_min_liters_saved'] as num?)?.toDouble(), affordable: j['affordable'] ?? false,
        lockedReason: j['locked_reason'], serviceTypeId: j['service_type_id'], serviceName: j['service_name'],
        vehicleCosts: parseList(j['vehicle_costs'], RewardVehicleCost.fromJson), minCost: j['min_cost'],
      );
}

class Redemption {
  Redemption({required this.id, required this.centerId, this.centerName, this.rewardName, required this.points,
      required this.code, required this.status, required this.createdAt, this.usedAt, this.isWash = false,
      this.serviceTypeId, this.serviceName, this.vehicleTypeId, this.vehicleTypeName});
  final int id;
  final int centerId;
  final String? centerName;
  final String? rewardName;
  final int points;
  final String code;
  final String status;
  final DateTime createdAt;
  final DateTime? usedAt;
  /// Lavage offert : à utiliser lors de la validation du lavage.
  final bool isWash;
  final int? serviceTypeId;
  final String? serviceName;
  final int? vehicleTypeId;
  final String? vehicleTypeName;

  factory Redemption.fromJson(Map<String, dynamic> j) => Redemption(
        id: j['id'], centerId: j['center_id'], centerName: j['center_name'], rewardName: j['reward_name'],
        points: j['points'], code: j['code'], status: j['status'], createdAt: parseDate(j['created_at'])!,
        usedAt: parseDate(j['used_at']), isWash: j['is_wash'] ?? false, serviceTypeId: j['service_type_id'],
        serviceName: j['service_name'], vehicleTypeId: j['vehicle_type_id'], vehicleTypeName: j['vehicle_type_name'],
      );
}

class WashRecord {
  WashRecord({required this.id, this.centerName, this.serviceName, this.vehicleTypeName, this.washerName,
      required this.price, required this.points, required this.waterSaved, required this.createdAt,
      this.paymentMethod = 'standard', this.pointsSpent = 0});
  final int id;
  final String? centerName;
  final String? serviceName;
  final String? vehicleTypeName;
  final String? washerName;
  final double price;
  final int points;
  final double waterSaved;
  final DateTime createdAt;
  /// standard | reward (lavage offert) | points (payé en points)
  final String paymentMethod;
  final int pointsSpent;

  factory WashRecord.fromJson(Map<String, dynamic> j) => WashRecord(
        id: j['id'], centerName: j['center_name'], serviceName: j['service_name'],
        vehicleTypeName: j['vehicle_type_name'], washerName: j['washer_name'], price: toDouble(j['price']),
        points: j['points_earned'], waterSaved: toDouble(j['water_saved_liters']), createdAt: parseDate(j['created_at'])!,
        paymentMethod: j['payment_method'] ?? 'standard', pointsSpent: j['points_spent'] ?? 0,
      );
}

class PointTx {
  PointTx({required this.id, required this.type, required this.points, this.note, this.centerName, required this.createdAt});
  final int id;
  final String type;
  final int points;
  final String? note;
  final String? centerName;
  final DateTime createdAt;

  static const labels = {
    'earn': 'Lavage', 'redeem': 'Récompense', 'referral': 'Parrainage', 'welcome': 'Bienvenue', 'bonus': 'Cadeau',
    'adjust': 'Ajustement', 'refund': 'Remboursement', 'wash_payment': 'Lavage payé en points',
  };
  String get label => labels[type] ?? type;

  factory PointTx.fromJson(Map<String, dynamic> j) => PointTx(
      id: j['id'], type: j['type'], points: j['points'], note: j['note'], centerName: j['center_name'],
      createdAt: parseDate(j['created_at'])!);
}

class Booking {
  Booking({required this.id, required this.centerId, this.centerName, this.serviceName, this.vehicleTypeName,
      required this.start, required this.end, required this.status, this.note});
  final int id;
  final int centerId;
  final String? centerName;
  final String? serviceName;
  final String? vehicleTypeName;
  final DateTime start;
  final DateTime end;
  final String status;
  final String? note;

  bool get isActive => status == 'confirmed' || status == 'pending';
  bool get isUpcoming => isActive && end.isAfter(DateTime.now());

  static const labels = {
    'pending': 'En attente', 'confirmed': 'Confirmée', 'completed': 'Terminée', 'cancelled': 'Annulée',
    'no_show': 'Manquée',
  };
  String get statusLabel => labels[status] ?? status;

  factory Booking.fromJson(Map<String, dynamic> j) => Booking(
        id: j['id'], centerId: j['center_id'], centerName: j['center_name'], serviceName: j['service_name'],
        vehicleTypeName: j['vehicle_type_name'], start: parseDate(j['start_at'])!, end: parseDate(j['end_at'])!,
        status: j['status'], note: j['note'],
      );
}

class AppNotification {
  AppNotification({required this.id, required this.type, required this.title, required this.body,
      required this.isRead, required this.createdAt, this.centerId});
  final int id;
  final String type;
  final String title;
  final String body;
  final bool isRead;
  final DateTime createdAt;
  final int? centerId;

  factory AppNotification.fromJson(Map<String, dynamic> j) => AppNotification(
      id: j['id'], type: j['type'], title: j['title'], body: j['body'], isRead: j['is_read'],
      createdAt: parseDate(j['created_at'])!, centerId: j['center_id']);
}

class Suggestion {
  Suggestion({required this.centerId, required this.centerName, required this.kind, required this.title,
      required this.message, this.dueInDays, this.weather});
  final int centerId;
  final String centerName;
  final String kind;
  final String title;
  final String message;
  final int? dueInDays;
  final Map<String, dynamic>? weather;

  factory Suggestion.fromJson(Map<String, dynamic> j) => Suggestion(
      centerId: j['center_id'], centerName: j['center_name'], kind: j['kind'], title: j['title'],
      message: j['message'], dueInDays: j['due_in_days'], weather: j['weather']);
}

class EcoLevel {
  EcoLevel({required this.name, required this.minLiters, this.icon});
  final String name;
  final double minLiters;
  final String? icon;
  factory EcoLevel.fromJson(Map<String, dynamic> j) =>
      EcoLevel(name: j['name'], minLiters: toDouble(j['min_liters']), icon: j['icon']);
}

class EcoStats {
  EcoStats({required this.totalLiters, required this.ecoWashes, required this.totalWashes, this.level, this.nextLevel,
      required this.equivalences, required this.monthly});
  final double totalLiters;
  final int ecoWashes;
  final int totalWashes;
  final EcoLevel? level;
  final EcoLevel? nextLevel;
  final List<Map<String, dynamic>> equivalences;
  final List<Map<String, dynamic>> monthly;

  double get progress {
    if (nextLevel == null) return 1;
    final from = level?.minLiters ?? 0;
    return ((totalLiters - from) / (nextLevel!.minLiters - from)).clamp(0, 1).toDouble();
  }

  factory EcoStats.fromJson(Map<String, dynamic> j) => EcoStats(
        totalLiters: toDouble(j['total_liters_saved']), ecoWashes: j['eco_washes'], totalWashes: j['total_washes'],
        level: j['level'] == null ? null : EcoLevel.fromJson(j['level']),
        nextLevel: j['next_level'] == null ? null : EcoLevel.fromJson(j['next_level']),
        equivalences: List<Map<String, dynamic>>.from(j['equivalences'] ?? const []),
        monthly: List<Map<String, dynamic>>.from(j['monthly'] ?? const []),
      );
}

class ReferralStats {
  ReferralStats({required this.code, required this.shareMessage, required this.invited, required this.rewarded,
      required this.points, required this.friends});
  final String code;
  final String shareMessage;
  final int invited;
  final int rewarded;
  final int points;
  final List<Map<String, dynamic>> friends;

  factory ReferralStats.fromJson(Map<String, dynamic> j) => ReferralStats(
      code: j['referral_code'], shareMessage: j['share_message'], invited: j['invited_count'],
      rewarded: j['rewarded_count'], points: j['points_earned'],
      friends: List<Map<String, dynamic>>.from(j['friends'] ?? const []));
}

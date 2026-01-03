import 'package:uuid/uuid.dart';

enum QuestType {
  buyVehicle,      // Araç satın al
  sellVehicle,     // Araç sat
  makeOffer,       // Teklif yap
  earnProfit,      // X TL kar et
  login,           // Oyuna gir
}

class DailyQuest {
  final String id;
  final String userId;
  final QuestType type;
  final String description; // Örn: "Bugün 3 araç satın al"
  final int targetCount;    // Örn: 3
  final int currentCount;   // Örn: 1
  final int rewardXP;       // Örn: 150 XP
  final double rewardMoney; // Örn: 50.000 TL
  final bool isClaimed;     // Ödül alındı mı?
  final DateTime date;      // Görevin ait olduğu gün
  final String? targetBrand; // Hedef marka (opsiyonel)

  DailyQuest({
    required this.id,
    required this.userId,
    required this.type,
    required this.description,
    required this.targetCount,
    this.currentCount = 0,
    required this.rewardXP,
    required this.rewardMoney,
    this.isClaimed = false,
    required this.date,
    this.targetBrand,
  });

  factory DailyQuest.create({
    required String userId,
    required QuestType type,
    required String description,
    required int targetCount,
    required int rewardXP,
    required double rewardMoney,
    String? targetBrand,
  }) {
    return DailyQuest(
      id: const Uuid().v4(),
      userId: userId,
      type: type,
      description: description,
      targetCount: targetCount,
      rewardXP: rewardXP,
      rewardMoney: rewardMoney,
      date: DateTime.now(),
      targetBrand: targetBrand,
    );
  }

  bool get isCompleted => currentCount >= targetCount;
  double get progress => (currentCount / targetCount).clamp(0.0, 1.0);

  factory DailyQuest.fromJson(Map<String, dynamic> json) {
    return DailyQuest(
      id: json['id'] as String,
      userId: json['userId'] as String,
      type: QuestType.values[json['type'] as int],
      description: json['description'] as String,
      targetCount: json['targetCount'] as int,
      currentCount: json['currentCount'] as int,
      rewardXP: json['rewardXP'] as int,
      rewardMoney: (json['rewardMoney'] as num).toDouble(),
      isClaimed: json['isClaimed'] as bool,
      date: DateTime.parse(json['date'] as String),
      targetBrand: json['targetBrand'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'type': type.index,
      'description': description,
      'targetCount': targetCount,
      'currentCount': currentCount,
      'rewardXP': rewardXP,
      'rewardMoney': rewardMoney,
      'isClaimed': isClaimed,
      'date': date.toIso8601String(),
      'targetBrand': targetBrand,
    };
  }

  DailyQuest copyWith({
    String? id,
    String? userId,
    QuestType? type,
    String? description,
    int? targetCount,
    int? currentCount,
    int? rewardXP,
    double? rewardMoney,
    bool? isClaimed,
    DateTime? date,
    String? targetBrand,
  }) {
    return DailyQuest(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      type: type ?? this.type,
      description: description ?? this.description,
      targetCount: targetCount ?? this.targetCount,
      currentCount: currentCount ?? this.currentCount,
      rewardXP: rewardXP ?? this.rewardXP,
      rewardMoney: rewardMoney ?? this.rewardMoney,
      isClaimed: isClaimed ?? this.isClaimed,
      date: date ?? this.date,
      targetBrand: targetBrand ?? this.targetBrand,
    );
  }
}

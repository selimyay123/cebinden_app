enum MissionType {
  tutorial,      // Tutorial'ı tamamla
  firstBuy,      // İlk aracını al
  firstSell,     // İlk aracını sat
  garageSize,    // Garaj limitini X yap (veya X araca sahip ol)
  balance,       // X TL bakiyeye ulaş
  collection,    // Bir koleksiyonu tamamla (marka ödülü al)
  gallery,       // Galeri satın al
  level,         // X seviyeye ulaş
  negotiation,   // X başarılı pazarlık yap
  fleet,         // X araca sahip ol
}

class Mission {
  final String id;
  final MissionType type;
  final String titleKey;
  final String descriptionKey;
  final int rewardXP;
  final double rewardMoney;
  final bool isCompleted;
  final bool isClaimed;
  final double targetValue; // Hedef değer (örn: 1000000 TL, 5. seviye)
  final double currentValue; // Mevcut değer (örn: 500000 TL, 3. seviye)

  Mission({
    required this.id,
    required this.type,
    required this.titleKey,
    required this.descriptionKey,
    required this.rewardXP,
    required this.rewardMoney,
    this.isCompleted = false,
    this.isClaimed = false,
    required this.targetValue,
    this.currentValue = 0.0,
  });

  factory Mission.fromJson(Map<String, dynamic> json) {
    return Mission(
      id: json['id'] as String,
      type: MissionType.values[json['type'] as int],
      titleKey: json['titleKey'] as String,
      descriptionKey: json['descriptionKey'] as String,
      rewardXP: json['rewardXP'] as int,
      rewardMoney: (json['rewardMoney'] as num).toDouble(),
      isCompleted: json['isCompleted'] as bool,
      isClaimed: json['isClaimed'] as bool,
      targetValue: (json['targetValue'] as num).toDouble(),
      currentValue: (json['currentValue'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.index,
      'titleKey': titleKey,
      'descriptionKey': descriptionKey,
      'rewardXP': rewardXP,
      'rewardMoney': rewardMoney,
      'isCompleted': isCompleted,
      'isClaimed': isClaimed,
      'targetValue': targetValue,
      'currentValue': currentValue,
    };
  }

  Mission copyWith({
    String? id,
    MissionType? type,
    String? titleKey,
    String? descriptionKey,
    int? rewardXP,
    double? rewardMoney,
    bool? isCompleted,
    bool? isClaimed,
    double? targetValue,
    double? currentValue,
  }) {
    return Mission(
      id: id ?? this.id,
      type: type ?? this.type,
      titleKey: titleKey ?? this.titleKey,
      descriptionKey: descriptionKey ?? this.descriptionKey,
      rewardXP: rewardXP ?? this.rewardXP,
      rewardMoney: rewardMoney ?? this.rewardMoney,
      isCompleted: isCompleted ?? this.isCompleted,
      isClaimed: isClaimed ?? this.isClaimed,
      targetValue: targetValue ?? this.targetValue,
      currentValue: currentValue ?? this.currentValue,
    );
  }
}

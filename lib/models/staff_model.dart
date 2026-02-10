import 'dart:math';

enum StaffRole { buyer, sales, technical, accountant }

abstract class Staff {
  final String id;
  final String userId; // Hangi kullanıcıya ait
  final String name;
  final StaffRole role;

  double salary; // Günlük maaş
  int efficiency; // 1-100 arası verim
  int morale; // 1-100 arası moral
  DateTime hiredDate;

  DateTime lastActionTime; // Son işlem zamanı
  int actionIntervalSeconds; // Kaç saniyede bir işlem yapacağı
  bool isPaused; // Çalışmayı durdurdu mu?

  // Günlük Limit Takibi
  int dailyActionCount;
  DateTime? lastDailyActionDate;

  Staff({
    required this.id,
    required this.userId,
    required this.name,
    required this.role,
    required this.salary,
    this.efficiency = 50,
    this.morale = 100,
    required this.hiredDate,
    DateTime? lastActionTime,
    this.actionIntervalSeconds = 60,
    this.isPaused = false,
    this.dailyActionCount = 0,
    this.lastDailyActionDate,
  }) : lastActionTime = lastActionTime ?? DateTime.now();

  // Her personel çalışır ama farklı iş yapar
  Map<String, dynamic> work();

  // JSON dönüşümleri alt sınıflarda override edilecek
  Map<String, dynamic> toJson();
}

class BuyerAgent extends Staff {
  List<String> targetBrands; // Uzmanlık alanı markalar
  double maxBudgetPerVehicle; // Araç başı max bütçe
  double
  skill; // Piyasa Bilgisi & Pazarlık (Eski: marketKnowledge & negotiationSkill)
  double speed; // Hız Çarpanı (Eski: speed)

  BuyerAgent({
    required super.id,
    required super.userId,
    required super.name,
    required super.salary,
    super.efficiency,
    super.morale,
    required super.hiredDate,
    this.targetBrands = const [],
    this.maxBudgetPerVehicle = 500000,
    this.skill = 0.5,
    this.speed = 1.0,
    super.lastActionTime,
    super.actionIntervalSeconds,
    super.isPaused,
    super.dailyActionCount,
    super.lastDailyActionDate,
  }) : super(role: StaffRole.buyer);

  @override
  Map<String, dynamic> work() {
    return {
      'action': 'search_market',
      'success_chance': skill, // Skill doğrudan şans
      'discount_margin': skill * 0.1, // Skill %10'a kadar indirim sağlar
      'duration_factor': 1.0 / speed,
    };
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'name': name,
      'role': role.toString(),
      'salary': salary,
      'efficiency': efficiency,
      'morale': morale,
      'hiredDate': hiredDate.toIso8601String(),
      'targetBrands': targetBrands,
      'maxBudgetPerVehicle': maxBudgetPerVehicle,
      'skill': skill,
      'speed': speed,
      'lastActionTime': lastActionTime.toIso8601String(),
      'actionIntervalSeconds': actionIntervalSeconds,
      'isPaused': isPaused,
      'dailyActionCount': dailyActionCount,
      'lastDailyActionDate': lastDailyActionDate?.toIso8601String(),
    };
  }

  factory BuyerAgent.fromJson(Map<String, dynamic> json) {
    return BuyerAgent(
      id: json['id'],
      userId: json['userId'] ?? 'unknown',
      name: json['name'],
      salary: (json['salary'] as num).toDouble(),
      efficiency: json['efficiency'],
      morale: json['morale'],
      hiredDate: DateTime.parse(json['hiredDate']),
      targetBrands: List<String>.from(json['targetBrands'] ?? []),
      maxBudgetPerVehicle: (json['maxBudgetPerVehicle'] as num).toDouble(),
      skill: (json['skill'] != null)
          ? (json['skill'] as num).toDouble()
          : (json['marketKnowledge'] as num?)?.toDouble() ?? 0.5,
      speed: (json['speed'] as num?)?.toDouble() ?? 1.0,
      lastActionTime: json['lastActionTime'] != null
          ? DateTime.parse(json['lastActionTime'])
          : null,
      actionIntervalSeconds: json['actionIntervalSeconds'] as int? ?? 60,
      isPaused: json['isPaused'] ?? false,
      dailyActionCount: json['dailyActionCount'] ?? 0,
      lastDailyActionDate: json['lastDailyActionDate'] != null
          ? DateTime.parse(json['lastDailyActionDate'])
          : null,
    );
  }
}

class SalesAgent extends Staff {
  double skill; // İkna & Pazarlık (Eski: negotiationSkill & persuasion)
  double speed; // Hız çarpanı

  SalesAgent({
    required super.id,
    required super.userId,
    required super.name,
    required super.salary,
    super.efficiency,
    super.morale,
    required super.hiredDate,
    this.skill = 0.5,
    this.speed = 1.0,
    super.lastActionTime,
    super.actionIntervalSeconds,
    super.isPaused,
    super.dailyActionCount,
    super.lastDailyActionDate,
  }) : super(role: StaffRole.sales);

  @override
  Map<String, dynamic> work() {
    final random = Random();
    double maxPotentialBonus = skill * 0.25;
    double luckFactor = 0.5 + random.nextDouble();

    return {
      'action': 'negotiate_sale',
      'success_chance': skill,
      'bonus_margin': maxPotentialBonus * luckFactor,
      'duration_factor': 1.0 / speed,
    };
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'name': name,
      'role': role.toString(),
      'salary': salary,
      'efficiency': efficiency,
      'morale': morale,
      'hiredDate': hiredDate.toIso8601String(),
      'skill': skill,
      'speed': speed,
      'lastActionTime': lastActionTime.toIso8601String(),
      'actionIntervalSeconds': actionIntervalSeconds,
      'isPaused': isPaused,
      'dailyActionCount': dailyActionCount,
      'lastDailyActionDate': lastDailyActionDate?.toIso8601String(),
    };
  }

  factory SalesAgent.fromJson(Map<String, dynamic> json) {
    return SalesAgent(
      id: json['id'],
      userId: json['userId'] ?? 'unknown',
      name: json['name'],
      salary: (json['salary'] as num).toDouble(),
      efficiency: json['efficiency'],
      morale: json['morale'],
      hiredDate: DateTime.parse(json['hiredDate']),
      skill: (json['skill'] != null)
          ? (json['skill'] as num).toDouble()
          : (json['persuasion'] as num?)?.toDouble() ?? 0.5,
      speed: (json['speed'] as num?)?.toDouble() ?? 1.0,
      lastActionTime: json['lastActionTime'] != null
          ? DateTime.parse(json['lastActionTime'])
          : null,
      actionIntervalSeconds: json['actionIntervalSeconds'] as int? ?? 60,
      isPaused: json['isPaused'] ?? false,
      dailyActionCount: json['dailyActionCount'] ?? 0,
      lastDailyActionDate: json['lastDailyActionDate'] != null
          ? DateTime.parse(json['lastDailyActionDate'])
          : null,
    );
  }
}

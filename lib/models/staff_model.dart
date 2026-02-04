enum StaffRole { buyer, sales, technical, accountant }

abstract class Staff {
  final String id;
  final String name;
  final StaffRole role;

  double salary; // Günlük maaş
  int efficiency; // 1-100 arası verim
  int morale; // 1-100 arası moral
  DateTime hiredDate;

  DateTime lastActionTime; // Son işlem zamanı
  int actionIntervalSeconds; // Kaç saniyede bir işlem yapacağı

  Staff({
    required this.id,
    required this.name,
    required this.role,
    required this.salary,
    this.efficiency = 50,
    this.morale = 100,
    required this.hiredDate,
    DateTime? lastActionTime,
    this.actionIntervalSeconds = 60,
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
    required String id,
    required String name,
    required double salary,
    int efficiency = 50,
    int morale = 100,
    required DateTime hiredDate,
    this.targetBrands = const [],
    this.maxBudgetPerVehicle = 500000,
    this.skill = 0.5,
    this.speed = 1.0,
    DateTime? lastActionTime,
    int actionIntervalSeconds = 60,
  }) : super(
         id: id,
         name: name,
         role: StaffRole.buyer,
         salary: salary,
         efficiency: efficiency,
         morale: morale,
         hiredDate: hiredDate,
         lastActionTime: lastActionTime,
         actionIntervalSeconds: actionIntervalSeconds,
       );

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
    };
  }

  factory BuyerAgent.fromJson(Map<String, dynamic> json) {
    return BuyerAgent(
      id: json['id'],
      name: json['name'],
      salary: (json['salary'] as num).toDouble(),
      efficiency: json['efficiency'],
      morale: json['morale'],
      hiredDate: DateTime.parse(json['hiredDate']),
      targetBrands: List<String>.from(json['targetBrands'] ?? []),
      maxBudgetPerVehicle: (json['maxBudgetPerVehicle'] as num).toDouble(),
      skill: (json['skill'] != null)
          ? (json['skill'] as num).toDouble()
          : (json['marketKnowledge'] as num?)?.toDouble() ??
                0.5, // Eski veri uyumu
      speed: (json['speed'] as num?)?.toDouble() ?? 1.0,
      lastActionTime: json['lastActionTime'] != null
          ? DateTime.parse(json['lastActionTime'])
          : null,
      actionIntervalSeconds: json['actionIntervalSeconds'] as int? ?? 60,
    );
  }
}

class SalesAgent extends Staff {
  double skill; // İkna & Pazarlık (Eski: negotiationSkill & persuasion)
  double speed; // Hız çarpanı

  SalesAgent({
    required String id,
    required String name,
    required double salary,
    int efficiency = 50,
    int morale = 100,
    required DateTime hiredDate,
    this.skill = 0.5,
    this.speed = 1.0,
    DateTime? lastActionTime,
    int actionIntervalSeconds = 60,
  }) : super(
         id: id,
         name: name,
         role: StaffRole.sales,
         salary: salary,
         efficiency: efficiency,
         morale: morale,
         hiredDate: hiredDate,
         lastActionTime: lastActionTime,
         actionIntervalSeconds: actionIntervalSeconds,
       );

  @override
  Map<String, dynamic> work() {
    return {
      'action': 'negotiate_sale',
      'success_chance': skill, // Skill doğrudan şans
      'bonus_margin': skill * 0.1, // Skill %10'a kadar bonus kâr sağlar
      'duration_factor': 1.0 / speed,
    };
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'id': id,
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
    };
  }

  factory SalesAgent.fromJson(Map<String, dynamic> json) {
    return SalesAgent(
      id: json['id'],
      name: json['name'],
      salary: (json['salary'] as num).toDouble(),
      efficiency: json['efficiency'],
      morale: json['morale'],
      hiredDate: DateTime.parse(json['hiredDate']),
      skill: (json['skill'] != null)
          ? (json['skill'] as num).toDouble()
          : (json['persuasion'] as num?)?.toDouble() ?? 0.5, // Eski veri uyumu
      speed: (json['speed'] as num?)?.toDouble() ?? 1.0,
      lastActionTime: json['lastActionTime'] != null
          ? DateTime.parse(json['lastActionTime'])
          : null,
      actionIntervalSeconds: json['actionIntervalSeconds'] as int? ?? 60,
    );
  }
}

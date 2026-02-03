enum StaffRole { buyer, sales, technical, accountant }

abstract class Staff {
  final String id;
  final String name;
  final StaffRole role;
  double salary; // Günlük maaş
  int efficiency; // 1-100 arası verim
  int morale; // 1-100 arası moral
  DateTime hiredDate;

  Staff({
    required this.id,
    required this.name,
    required this.role,
    required this.salary,
    this.efficiency = 50,
    this.morale = 100,
    required this.hiredDate,
  });

  // Her personel çalışır ama farklı iş yapar
  Map<String, dynamic> work();

  // JSON dönüşümleri alt sınıflarda override edilecek
  Map<String, dynamic> toJson();
}

class BuyerAgent extends Staff {
  List<String> targetBrands; // Uzmanlık alanı markalar
  double maxBudgetPerVehicle; // Araç başı max bütçe

  BuyerAgent({
    required String id,
    required String name,
    required double salary,
    int efficiency = 50,
    int morale = 100,
    required DateTime hiredDate,
    this.targetBrands = const [],
    this.maxBudgetPerVehicle = 500000,
  }) : super(
         id: id,
         name: name,
         role: StaffRole.buyer,
         salary: salary,
         efficiency: efficiency,
         morale: morale,
         hiredDate: hiredDate,
       );

  @override
  Map<String, dynamic> work() {
    // Burada satın alma mantığı simüle edilecek
    // efficiency'ye göre şans ve başarı oranı dönecek
    return {'action': 'search_market', 'success_chance': efficiency / 100.0};
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
    );
  }
}

class SalesAgent extends Staff {
  double negotiationSkill; // Pazarlık yeteneği çarpanı (0.0 - 0.5)
  double persuasion; // İkna kabiliyeti (0.0 - 1.0) -> Satış şansı
  double speed; // Hız çarpanı (0.5 - 2.0) -> İşlem süresini kısaltır

  SalesAgent({
    required String id,
    required String name,
    required double salary,
    int efficiency = 50,
    int morale = 100,
    required DateTime hiredDate,
    this.negotiationSkill = 0.05,
    this.persuasion = 0.5,
    this.speed = 1.0,
  }) : super(
         id: id,
         name: name,
         role: StaffRole.sales,
         salary: salary,
         efficiency: efficiency,
         morale: morale,
         hiredDate: hiredDate,
       );

  @override
  Map<String, dynamic> work() {
    // Satış yapma mantığı
    return {
      'action': 'negotiate_sale',
      'bonus_margin': negotiationSkill * (efficiency / 100.0),
      'success_chance': persuasion,
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
      'negotiationSkill': negotiationSkill,
      'persuasion': persuasion,
      'speed': speed,
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
      negotiationSkill: (json['negotiationSkill'] as num).toDouble(),
      persuasion: (json['persuasion'] as num?)?.toDouble() ?? 0.5,
      speed: (json['speed'] as num?)?.toDouble() ?? 1.0,
    );
  }
}

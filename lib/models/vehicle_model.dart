import 'package:uuid/uuid.dart';

class Vehicle {
  final String id;
  final String brand; // Marka (örn: BMV, Toyoto)
  final String model; // Model (örn: 320i, Camry)
  final int year; // Model yılı
  final int mileage; // Kilometre
  final double price; // Fiyat (TL)
  final String location; // Şehir
  final String color; // Renk
  final String fuelType; // Yakıt tipi (Benzin, Dizel, Elektrik, Hybrid)
  final String transmission; // Vites (Manuel, Otomatik)
  final String? imageUrl; // Araç resmi (opsiyonel)
  final String condition; // Durum (Sıfır, İkinci El, Hasarlı)
  final DateTime listedAt; // İlan tarihi
  final String? sellerId; // Satıcı ID (opsiyonel)
  final String engineSize; // Motor hacmi (örn: "1.6", "2.0 TSI")
  final String driveType; // Çekiş (Önden, Arkadan, 4x4)
  final bool hasWarranty; // Garanti var mı?
  final bool hasAccidentRecord; // Ağır hasar kaydı var mı?
  final String description; // İlan açıklaması
  final int score; // İlan skoru (1-100) - Kullanıcıya gösterilmez, arka plan hesaplama
  final String bodyType; // Kasa tipi (Sedan, Hatchback, SUV, Coupe, vb.)
  final int horsepower; // Motor gücü (HP)
  final String sellerType; // Kimden (Sahibinden, Galeriden)
  final Map<String, String> partConditions; // Parça durumları (orijinal, lokal_boyali, boyali, degisen)

  Vehicle({
    required this.id,
    required this.brand,
    required this.model,
    required this.year,
    required this.mileage,
    required this.price,
    required this.location,
    required this.color,
    required this.fuelType,
    required this.transmission,
    this.imageUrl,
    this.condition = 'İkinci El',
    required this.listedAt,
    this.sellerId,
    required this.engineSize,
    required this.driveType,
    this.hasWarranty = false,
    this.hasAccidentRecord = false,
    required this.description,
    required this.score,
    required this.bodyType,
    required this.horsepower,
    this.sellerType = 'Sahibinden',
    this.partConditions = const {},
  });

  // Yeni araç ilanı oluşturma factory
  factory Vehicle.create({
    required String brand,
    required String model,
    required int year,
    required int mileage,
    required double price,
    required String location,
    required String color,
    required String fuelType,
    required String transmission,
    String? imageUrl,
    String condition = 'İkinci El',
    String? sellerId,
    required String engineSize,
    required String driveType,
    bool hasWarranty = false,
    bool hasAccidentRecord = false,
    required String description,
    required String bodyType,
    required int horsepower,
    String sellerType = 'Sahibinden',
    Map<String, String>? partConditions,
  }) {
    // Skor hesapla (otomatik)
    final calculatedScore = _calculateScore(
      year: year,
      mileage: mileage,
      price: price,
      fuelType: fuelType,
      transmission: transmission,
      hasWarranty: hasWarranty,
      hasAccidentRecord: hasAccidentRecord,
      engineSize: engineSize,
      condition: condition,
    );

    return Vehicle(
      id: const Uuid().v4(),
      brand: brand,
      model: model,
      year: year,
      mileage: mileage,
      price: price,
      location: location,
      color: color,
      fuelType: fuelType,
      transmission: transmission,
      imageUrl: imageUrl,
      condition: condition,
      listedAt: DateTime.now(),
      sellerId: sellerId,
      engineSize: engineSize,
      driveType: driveType,
      hasWarranty: hasWarranty,
      hasAccidentRecord: hasAccidentRecord,
      description: description,
      score: calculatedScore,
      bodyType: bodyType,
      horsepower: horsepower,
      sellerType: sellerType,
      partConditions: partConditions ?? _generateRandomPartConditions(),
    );
  }

  // Rastgele parça durumları oluştur
  static Map<String, String> _generateRandomPartConditions() {
    final random = DateTime.now().millisecondsSinceEpoch % 100;
    final parts = <String, String>{};
    final conditions = ['orijinal', 'lokal_boyali', 'boyali', 'degisen'];
    
    // %70 oranında orijinal parçalar
    parts['kaput'] = random < 70 ? 'orijinal' : conditions[random % 4];
    parts['tavan'] = random < 85 ? 'orijinal' : conditions[random % 3];
    parts['bagaj'] = random < 75 ? 'orijinal' : conditions[random % 4];
    parts['sol_on_camurluk'] = random < 80 ? 'orijinal' : conditions[random % 4];
    parts['sag_on_camurluk'] = random < 80 ? 'orijinal' : conditions[random % 4];
    parts['sol_on_kapi'] = random < 85 ? 'orijinal' : conditions[random % 3];
    parts['sag_on_kapi'] = random < 85 ? 'orijinal' : conditions[random % 3];
    parts['sol_arka_kapi'] = random < 85 ? 'orijinal' : conditions[random % 3];
    parts['sag_arka_kapi'] = random < 85 ? 'orijinal' : conditions[random % 3];
    parts['sol_arka_camurluk'] = random < 80 ? 'orijinal' : conditions[random % 4];
    parts['sag_arka_camurluk'] = random < 80 ? 'orijinal' : conditions[random % 4];
    
    return parts;
  }

  // Skor hesaplama algoritması (1-100 arası)
  // Kullanıcıya gösterilmez, arka planda çalışır
  static int _calculateScore({
    required int year,
    required int mileage,
    required double price,
    required String fuelType,
    required String transmission,
    required bool hasWarranty,
    required bool hasAccidentRecord,
    required String engineSize,
    required String condition,
  }) {
    double score = 50.0; // Base score

    // 1. YIL PUANI (max ±15 puan)
    final currentYear = DateTime.now().year;
    final age = currentYear - year;
    if (age <= 1) {
      score += 15; // Neredeyse sıfır
    } else if (age <= 3) {
      score += 12;
    } else if (age <= 5) {
      score += 8;
    } else if (age <= 7) {
      score += 4;
    } else if (age <= 10) {
      score += 0; // Orta yaşlı
    } else if (age <= 15) {
      score -= 5;
    } else {
      score -= 10; // Çok eski
    }

    // 2. KİLOMETRE PUANI (max ±15 puan)
    if (mileage < 10000) {
      score += 15; // Çok az kullanılmış
    } else if (mileage < 30000) {
      score += 12;
    } else if (mileage < 60000) {
      score += 8;
    } else if (mileage < 100000) {
      score += 4;
    } else if (mileage < 150000) {
      score += 0; // Orta
    } else if (mileage < 200000) {
      score -= 5;
    } else if (mileage < 300000) {
      score -= 10;
    } else {
      score -= 15; // Çok yüksek km
    }

    // 3. FİYAT/DEĞER ORANI (max ±10 puan)
    // Yıl ve km'ye göre beklenen fiyat
    final expectedPrice = _calculateExpectedPrice(year, mileage);
    final priceRatio = price / expectedPrice;
    
    if (priceRatio < 0.7) {
      score += 10; // Çok ucuz (fırsat!)
    } else if (priceRatio < 0.85) {
      score += 7;
    } else if (priceRatio < 1.0) {
      score += 4;
    } else if (priceRatio < 1.15) {
      score += 0; // Normal fiyat
    } else if (priceRatio < 1.3) {
      score -= 5;
    } else {
      score -= 10; // Çok pahalı
    }

    // 4. YAKIT TİPİ PUANI (max ±8 puan)
    switch (fuelType) {
      case 'Elektrik':
        score += 8; // En çevreci ve ekonomik
        break;
      case 'Hybrid':
        score += 6;
        break;
      case 'Benzin':
        score += 2;
        break;
      case 'Dizel':
        score += 0; // Nötr
        break;
      default:
        score += 0;
    }

    // 5. VİTES PUANI (max ±5 puan)
    if (transmission == 'Otomatik') {
      score += 5; // Konforlu
    } else {
      score += 2; // Manuel (bazıları tercih eder)
    }

    // 6. GARANTİ PUANI (max +7 puan)
    if (hasWarranty) {
      score += 7; // Garanti güven verir
    }

    // 7. KAZA KAYDI PUANI (max -12 puan)
    if (hasAccidentRecord) {
      score -= 12; // Ağır hasar kayıtlı araç risk
    }

    // 8. MOTOR HACMİ PUANI (max ±5 puan)
    try {
      final engineValue = double.parse(engineSize.replaceAll(RegExp(r'[^0-9.]'), ''));
      if (engineValue >= 2.0 && engineValue <= 2.5) {
        score += 5; // İdeal motor hacmi
      } else if (engineValue >= 1.6 && engineValue < 2.0) {
        score += 3;
      } else if (engineValue >= 1.4 && engineValue < 1.6) {
        score += 1;
      } else if (engineValue >= 3.0) {
        score -= 3; // Çok büyük motor (yakıt tüketimi)
      } else if (engineValue < 1.2) {
        score -= 2; // Çok küçük motor (güçsüz)
      }
    } catch (e) {
      // Motor hacmi parse edilemezse 0 puan
    }

    // 9. DURUM PUANI (max ±10 puan)
    switch (condition) {
      case 'Sıfır':
        score += 10; // Yepyeni araç
        break;
      case 'İkinci El':
        score += 0; // Standart
        break;
      case 'Hasarlı':
        score -= 10; // Hasarlı araç
        break;
      default:
        score += 0;
    }

    // Skoru 1-100 arasına sınırla
    score = score.clamp(1.0, 100.0);

    return score.round();
  }

  // Beklenen fiyat hesaplama (basit model)
  static double _calculateExpectedPrice(int year, int mileage) {
    final currentYear = DateTime.now().year;
    final age = currentYear - year;
    
    // Base fiyat (ortalama bir araç için)
    double basePrice = 500000.0;
    
    // Yıl başına %10 değer kaybı
    basePrice = basePrice * (1 - (age * 0.10));
    
    // Her 10,000 km için %2 değer kaybı
    final kmFactor = (mileage / 10000) * 0.02;
    basePrice = basePrice * (1 - kmFactor);
    
    // Minimum fiyat
    return basePrice.clamp(50000.0, 2000000.0);
  }

  // Tam araç adı
  String get fullName => '$brand $model';

  // Araç yaşı
  int get age => DateTime.now().year - year;

  // JSON'dan Vehicle oluşturma
  factory Vehicle.fromJson(Map<String, dynamic> json) {
    // Eğer score yoksa (eski kayıtlar), hesapla
    final int score;
    if (json['score'] != null) {
      score = json['score'] as int;
    } else {
      // Eski kayıtlar için score hesapla
      score = _calculateScore(
        year: json['year'] as int,
        mileage: json['mileage'] as int,
        price: (json['price'] as num).toDouble(),
        fuelType: json['fuelType'] as String,
        transmission: json['transmission'] as String,
        hasWarranty: json['hasWarranty'] as bool? ?? false,
        hasAccidentRecord: json['hasAccidentRecord'] as bool? ?? false,
        engineSize: json['engineSize'] as String? ?? '1.6',
        condition: json['condition'] as String? ?? 'İkinci El',
      );
    }

    return Vehicle(
      id: json['id'] as String,
      brand: json['brand'] as String,
      model: json['model'] as String,
      year: json['year'] as int,
      mileage: json['mileage'] as int,
      price: (json['price'] as num).toDouble(),
      location: json['location'] as String,
      color: json['color'] as String,
      fuelType: json['fuelType'] as String,
      transmission: json['transmission'] as String,
      imageUrl: json['imageUrl'] as String?,
      condition: json['condition'] as String? ?? 'İkinci El',
      listedAt: DateTime.parse(json['listedAt'] as String),
      sellerId: json['sellerId'] as String?,
      engineSize: json['engineSize'] as String? ?? '1.6',
      driveType: json['driveType'] as String? ?? 'Önden',
      hasWarranty: json['hasWarranty'] as bool? ?? false,
      hasAccidentRecord: json['hasAccidentRecord'] as bool? ?? false,
      description: json['description'] as String? ?? 'Açıklama yok',
      score: score,
      bodyType: json['bodyType'] as String? ?? 'Sedan',
      horsepower: json['horsepower'] as int? ?? 150,
      sellerType: json['sellerType'] as String? ?? 'Sahibinden',
      partConditions: json['partConditions'] != null 
          ? Map<String, String>.from(json['partConditions'] as Map)
          : _generateRandomPartConditions(),
    );
  }

  // Vehicle'ı JSON'a dönüştürme
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'brand': brand,
      'model': model,
      'year': year,
      'mileage': mileage,
      'price': price,
      'location': location,
      'color': color,
      'fuelType': fuelType,
      'transmission': transmission,
      'imageUrl': imageUrl,
      'condition': condition,
      'listedAt': listedAt.toIso8601String(),
      'sellerId': sellerId,
      'engineSize': engineSize,
      'driveType': driveType,
      'hasWarranty': hasWarranty,
      'hasAccidentRecord': hasAccidentRecord,
      'description': description,
      'score': score, // İlan skoru (arka plan)
      'bodyType': bodyType,
      'horsepower': horsepower,
      'sellerType': sellerType,
      'partConditions': partConditions,
    };
  }

  @override
  String toString() {
    return 'Vehicle(id: $id, fullName: $fullName, price: $price TL, location: $location)';
  }
}


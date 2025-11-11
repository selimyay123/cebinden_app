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
  }) {
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
    );
  }

  // Tam araç adı
  String get fullName => '$brand $model';

  // Araç yaşı
  int get age => DateTime.now().year - year;

  // JSON'dan Vehicle oluşturma
  factory Vehicle.fromJson(Map<String, dynamic> json) {
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
    };
  }

  @override
  String toString() {
    return 'Vehicle(id: $id, fullName: $fullName, price: $price TL, location: $location)';
  }
}


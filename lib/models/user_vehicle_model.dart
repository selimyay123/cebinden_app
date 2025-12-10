import 'package:uuid/uuid.dart';

/// Kullanıcının sahip olduğu araç modeli
/// Her kullanıcının birden fazla aracı olabilir
class UserVehicle {
  final String id; // Kullanıcının araç kaydının ID'si (unique)
  final String userId; // Hangi kullanıcıya ait
  final String vehicleId; // Hangi araç (Vehicle model'inden)
  final String brand;
  final String model;
  final int year;
  final int mileage;
  final double purchasePrice; // Satın alma fiyatı
  final DateTime purchaseDate; // Satın alma tarihi
  final String color;
  final String fuelType;
  final String transmission;
  final String engineSize;
  final String driveType;
  final bool hasWarranty;
  final bool hasAccidentRecord;
  final String? imageUrl;
  final int score; // İlan skoru (Vehicle'dan alınır, arka plan)
  
  // Satışa çıkarma bilgileri
  final bool isListedForSale; // Araç satışa çıkarılmış mı?
  final double? listingPrice; // İlan fiyatı
  final String? listingDescription; // İlan açıklaması
  final DateTime? listedDate; // Satışa çıkarıldığı tarih
  
  // Kiralama bilgisi
  final bool isRented; // Araç kirada mı?

  // Opsiyonel: Kullanıcı aracı sattığında
  final bool isSold;
  final double? salePrice;
  final DateTime? saleDate;

  UserVehicle({
    required this.id,
    required this.userId,
    required this.vehicleId,
    required this.brand,
    required this.model,
    required this.year,
    required this.mileage,
    required this.purchasePrice,
    required this.purchaseDate,
    required this.color,
    required this.fuelType,
    required this.transmission,
    required this.engineSize,
    required this.driveType,
    required this.hasWarranty,
    required this.hasAccidentRecord,
    this.imageUrl,
    required this.score,
    this.isListedForSale = false,
    this.listingPrice,
    this.listingDescription,
    this.listedDate,
    this.isRented = false,
    this.isSold = false,
    this.salePrice,
    this.saleDate,
  });

  // Factory constructor: Yeni araç satın alma
  factory UserVehicle.purchase({
    required String userId,
    required String vehicleId,
    required String brand,
    required String model,
    required int year,
    required int mileage,
    required double purchasePrice,
    required String color,
    required String fuelType,
    required String transmission,
    required String engineSize,
    required String driveType,
    required bool hasWarranty,
    required bool hasAccidentRecord,
    required int score, // Vehicle'dan alınacak
    String? imageUrl,
  }) {
    return UserVehicle(
      id: const Uuid().v4(),
      userId: userId,
      vehicleId: vehicleId,
      brand: brand,
      model: model,
      year: year,
      mileage: mileage,
      purchasePrice: purchasePrice,
      purchaseDate: DateTime.now(),
      color: color,
      fuelType: fuelType,
      transmission: transmission,
      engineSize: engineSize,
      driveType: driveType,
      hasWarranty: hasWarranty,
      hasAccidentRecord: hasAccidentRecord,
      imageUrl: imageUrl,
      score: score,
      isRented: false,
    );
  }

  // JSON'dan UserVehicle oluştur
  factory UserVehicle.fromJson(Map<String, dynamic> json) {
    return UserVehicle(
      id: json['id'] as String,
      userId: json['userId'] as String,
      vehicleId: json['vehicleId'] as String,
      brand: json['brand'] as String,
      model: json['model'] as String,
      year: json['year'] as int,
      mileage: json['mileage'] as int,
      purchasePrice: (json['purchasePrice'] as num).toDouble(),
      purchaseDate: DateTime.parse(json['purchaseDate'] as String),
      color: json['color'] as String,
      fuelType: json['fuelType'] as String,
      transmission: json['transmission'] as String,
      engineSize: json['engineSize'] as String,
      driveType: json['driveType'] as String,
      hasWarranty: json['hasWarranty'] as bool? ?? false,
      hasAccidentRecord: json['hasAccidentRecord'] as bool? ?? false,
      imageUrl: json['imageUrl'] as String?,
      score: json['score'] as int? ?? 50, // Default score if missing
      isListedForSale: json['isListedForSale'] as bool? ?? false,
      listingPrice: json['listingPrice'] != null ? (json['listingPrice'] as num).toDouble() : null,
      listingDescription: json['listingDescription'] as String?,
      listedDate: json['listedDate'] != null ? DateTime.parse(json['listedDate'] as String) : null,
      isRented: json['isRented'] as bool? ?? false,
      isSold: json['isSold'] as bool? ?? false,
      salePrice: json['salePrice'] != null ? (json['salePrice'] as num).toDouble() : null,
      saleDate: json['saleDate'] != null ? DateTime.parse(json['saleDate'] as String) : null,
    );
  }

  // UserVehicle'ı JSON'a çevir
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'vehicleId': vehicleId,
      'brand': brand,
      'model': model,
      'year': year,
      'mileage': mileage,
      'purchasePrice': purchasePrice,
      'purchaseDate': purchaseDate.toIso8601String(),
      'color': color,
      'fuelType': fuelType,
      'transmission': transmission,
      'engineSize': engineSize,
      'driveType': driveType,
      'hasWarranty': hasWarranty,
      'hasAccidentRecord': hasAccidentRecord,
      'imageUrl': imageUrl,
      'score': score, // İlan skoru (arka plan)
      'isListedForSale': isListedForSale,
      'listingPrice': listingPrice,
      'listingDescription': listingDescription,
      'listedDate': listedDate?.toIso8601String(),
      'isRented': isRented,
      'isSold': isSold,
      'salePrice': salePrice,
      'saleDate': saleDate?.toIso8601String(),
    };
  }

  // Tam araç adı
  String get fullName => '$brand $model';

  // Araç ne kadar süredir kullanıcıda
  int get daysOwned {
    if (isSold && saleDate != null) {
      return saleDate!.difference(purchaseDate).inDays;
    }
    return DateTime.now().difference(purchaseDate).inDays;
  }

  // Kar/Zarar hesaplama (eğer satıldıysa)
  double? get profitLoss {
    if (isSold && salePrice != null) {
      return salePrice! - purchasePrice;
    }
    return null;
  }

  // Kar/Zarar yüzdesi
  double? get profitLossPercentage {
    final pl = profitLoss;
    if (pl != null) {
      return (pl / purchasePrice) * 100;
    }
    return null;
  }

  // Satışa çıkarma için kopyalama
  UserVehicle copyWithListing({
    required double listingPrice,
    required String listingDescription,
  }) {
    return UserVehicle(
      id: id,
      userId: userId,
      vehicleId: vehicleId,
      brand: brand,
      model: model,
      year: year,
      mileage: mileage,
      purchasePrice: purchasePrice,
      purchaseDate: purchaseDate,
      color: color,
      fuelType: fuelType,
      transmission: transmission,
      engineSize: engineSize,
      driveType: driveType,
      hasWarranty: hasWarranty,
      hasAccidentRecord: hasAccidentRecord,
      imageUrl: imageUrl,
      score: score,
      isListedForSale: true,
      listingPrice: listingPrice,
      listingDescription: listingDescription,
      listedDate: DateTime.now(),
      isSold: isSold,
      salePrice: salePrice,
      saleDate: saleDate,
      isRented: false, // Satışa çıkınca kiralama biter (veya kontrol edilir)
    );
  }

  // Araç satışı için kopyalama
  UserVehicle copyWithSale({
    required double salePrice,
    required DateTime saleDate,
  }) {
    return UserVehicle(
      id: id,
      userId: userId,
      vehicleId: vehicleId,
      brand: brand,
      model: model,
      year: year,
      mileage: mileage,
      purchasePrice: purchasePrice,
      purchaseDate: purchaseDate,
      color: color,
      fuelType: fuelType,
      transmission: transmission,
      engineSize: engineSize,
      driveType: driveType,
      hasWarranty: hasWarranty,
      hasAccidentRecord: hasAccidentRecord,
      imageUrl: imageUrl,
      score: score, // Score değişmeden kalır
      isListedForSale: isListedForSale, // Satış bilgisi korunur
      listingPrice: listingPrice,
      listingDescription: listingDescription,
      listedDate: listedDate,
      isSold: true,
      salePrice: salePrice,
      saleDate: saleDate,
      isRented: false, // Satılınca kiralama biter
    );
  }

  // Kiralama durumu değişikliği için kopyalama
  UserVehicle copyWithRent({
    required bool isRented,
  }) {
    return UserVehicle(
      id: id,
      userId: userId,
      vehicleId: vehicleId,
      brand: brand,
      model: model,
      year: year,
      mileage: mileage,
      purchasePrice: purchasePrice,
      purchaseDate: purchaseDate,
      color: color,
      fuelType: fuelType,
      transmission: transmission,
      engineSize: engineSize,
      driveType: driveType,
      hasWarranty: hasWarranty,
      hasAccidentRecord: hasAccidentRecord,
      imageUrl: imageUrl,
      score: score,
      isListedForSale: isListedForSale,
      listingPrice: listingPrice,
      listingDescription: listingDescription,
      listedDate: listedDate,
      isSold: isSold,
      salePrice: salePrice,
      saleDate: saleDate,
      isRented: isRented,
    );
  }
}


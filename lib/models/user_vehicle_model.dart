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
  final String bodyType; // Kasa tipi
  final int horsepower; // Motor gücü
  
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

  final double? originalListingPrice; // Satın alındığındaki ilan fiyatı (Kâr limiti hesabı için)
  
  // Manuel kiralama geliri toplama
  final double pendingRentalIncome; // Toplanmayı bekleyen kira geliri
  final bool canCollectRentalIncome; // Gelir toplanabilir mi? (Gün bittiğinde true olur)

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
    required this.bodyType,
    required this.horsepower,
    this.isListedForSale = false,
    this.listingPrice,
    this.listingDescription,
    this.listedDate,
    this.isRented = false,
    this.isSold = false,
    this.salePrice,
    this.saleDate,
    this.originalListingPrice,
    this.pendingRentalIncome = 0.0,
    this.canCollectRentalIncome = false,
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
    required String bodyType,
    required int horsepower,
    String? imageUrl,
    double? originalListingPrice,
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
      bodyType: bodyType,
      horsepower: horsepower,
      originalListingPrice: originalListingPrice,
      pendingRentalIncome: 0.0,
      canCollectRentalIncome: false,
    );
  }

  // Vehicle modelinden UserVehicle oluştur
  factory UserVehicle.fromVehicle(
    dynamic vehicle, // Vehicle tipinde ama import sorunu olmasın diye dynamic
    String userId, {
    required double purchasePrice,
  }) {
    return UserVehicle(
      id: const Uuid().v4(),
      userId: userId,
      vehicleId: vehicle.id,
      brand: vehicle.brand,
      model: vehicle.model,
      year: vehicle.year,
      mileage: vehicle.mileage,
      purchasePrice: purchasePrice,
      purchaseDate: DateTime.now(),
      color: vehicle.color,
      fuelType: vehicle.fuelType,
      transmission: vehicle.transmission,
      engineSize: vehicle.engineSize,
      driveType: vehicle.driveType,
      hasWarranty: vehicle.hasWarranty,
      hasAccidentRecord: vehicle.hasAccidentRecord,
      imageUrl: vehicle.imageUrl,
      score: vehicle.score,
      bodyType: vehicle.bodyType,
      horsepower: vehicle.horsepower,
      originalListingPrice: null,
      pendingRentalIncome: 0.0,
      canCollectRentalIncome: false,
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
      bodyType: json['bodyType'] as String? ?? 'Sedan',
      horsepower: json['horsepower'] as int? ?? 100,
      isListedForSale: json['isListedForSale'] as bool? ?? false,
      listingPrice: json['listingPrice'] != null ? (json['listingPrice'] as num).toDouble() : null,
      listingDescription: json['listingDescription'] as String?,
      listedDate: json['listedDate'] != null ? DateTime.parse(json['listedDate'] as String) : null,
      isRented: json['isRented'] as bool? ?? false,
      isSold: json['isSold'] as bool? ?? false,
      salePrice: json['salePrice'] != null ? (json['salePrice'] as num).toDouble() : null,
      saleDate: json['saleDate'] != null ? DateTime.parse(json['saleDate'] as String) : null,
      originalListingPrice: json['originalListingPrice'] != null ? (json['originalListingPrice'] as num).toDouble() : null,
      pendingRentalIncome: json['pendingRentalIncome'] != null ? (json['pendingRentalIncome'] as num).toDouble() : 0.0,
      canCollectRentalIncome: json['canCollectRentalIncome'] as bool? ?? false,
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
      'originalListingPrice': originalListingPrice,
      'pendingRentalIncome': pendingRentalIncome,
      'canCollectRentalIncome': canCollectRentalIncome,
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
      bodyType: bodyType,
      horsepower: horsepower,
      isListedForSale: true,
      listingPrice: listingPrice,
      listingDescription: listingDescription,
      listedDate: DateTime.now(),
      isSold: isSold,
      salePrice: salePrice,
      saleDate: saleDate,
      isRented: false, // Satışa çıkınca kiralama biter (veya kontrol edilir)
      originalListingPrice: originalListingPrice,
      pendingRentalIncome: pendingRentalIncome,
      canCollectRentalIncome: canCollectRentalIncome,
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
      bodyType: bodyType,
      horsepower: horsepower,
      isListedForSale: isListedForSale, // Satış bilgisi korunur
      listingPrice: listingPrice,
      listingDescription: listingDescription,
      listedDate: listedDate,
      isSold: true,
      salePrice: salePrice,
      saleDate: saleDate,
      isRented: false, // Satılınca kiralama biter
      originalListingPrice: originalListingPrice,
      pendingRentalIncome: pendingRentalIncome,
      canCollectRentalIncome: canCollectRentalIncome,
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
      bodyType: bodyType,
      horsepower: horsepower,
      isListedForSale: isListedForSale,
      listingPrice: listingPrice,
      listingDescription: listingDescription,
      listedDate: listedDate,
      isSold: isSold,
      salePrice: salePrice,
      saleDate: saleDate,
      isRented: isRented,
      originalListingPrice: originalListingPrice,
      pendingRentalIncome: pendingRentalIncome,
      canCollectRentalIncome: canCollectRentalIncome,
    );
  }

  // Genel kopyalama
  UserVehicle copyWith({
    String? id,
    String? userId,
    String? vehicleId,
    String? brand,
    String? model,
    int? year,
    int? mileage,
    double? purchasePrice,
    DateTime? purchaseDate,
    String? color,
    String? fuelType,
    String? transmission,
    String? engineSize,
    String? driveType,
    bool? hasWarranty,
    bool? hasAccidentRecord,
    String? imageUrl,
    int? score,
    String? bodyType,
    int? horsepower,
    bool? isListedForSale,
    double? listingPrice,
    String? listingDescription,
    DateTime? listedDate,
    bool? isRented,
    bool? isSold,
    double? salePrice,
    DateTime? saleDate,
    double? originalListingPrice,
    double? pendingRentalIncome,
    bool? canCollectRentalIncome,
  }) {
    return UserVehicle(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      vehicleId: vehicleId ?? this.vehicleId,
      brand: brand ?? this.brand,
      model: model ?? this.model,
      year: year ?? this.year,
      mileage: mileage ?? this.mileage,
      purchasePrice: purchasePrice ?? this.purchasePrice,
      purchaseDate: purchaseDate ?? this.purchaseDate,
      color: color ?? this.color,
      fuelType: fuelType ?? this.fuelType,
      transmission: transmission ?? this.transmission,
      engineSize: engineSize ?? this.engineSize,
      driveType: driveType ?? this.driveType,
      hasWarranty: hasWarranty ?? this.hasWarranty,
      hasAccidentRecord: hasAccidentRecord ?? this.hasAccidentRecord,
      imageUrl: imageUrl ?? this.imageUrl,
      score: score ?? this.score,
      bodyType: bodyType ?? this.bodyType,
      horsepower: horsepower ?? this.horsepower,
      isListedForSale: isListedForSale ?? this.isListedForSale,
      listingPrice: listingPrice ?? this.listingPrice,
      listingDescription: listingDescription ?? this.listingDescription,
      listedDate: listedDate ?? this.listedDate,
      isRented: isRented ?? this.isRented,
      isSold: isSold ?? this.isSold,
      salePrice: salePrice ?? this.salePrice,
      saleDate: saleDate ?? this.saleDate,
      originalListingPrice: originalListingPrice ?? this.originalListingPrice,
      pendingRentalIncome: pendingRentalIncome ?? this.pendingRentalIncome,
      canCollectRentalIncome: canCollectRentalIncome ?? this.canCollectRentalIncome,
    );
  }
}


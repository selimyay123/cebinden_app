/// Teklif durumu enum
enum OfferStatus {
  pending, // Bekliyor
  accepted, // Kabul edildi
  rejected, // Reddedildi
  expired, // Süresi doldu
  withdrawn, // Alıcı geri çekti
}

/// Teklif modeli
class Offer {
  final String offerId;
  final String vehicleId; // UserVehicle ID'si
  final String sellerId; // İlanı veren kullanıcı ID'si
  final String buyerId; // AI alıcı ID'si
  final String buyerName; // AI alıcı adı (örn: "Mehmet B.")
  final double offerPrice; // Teklif edilen fiyat
  final DateTime offerDate; // Teklif tarihi
  OfferStatus status; // Teklif durumu
  final String? message; // Alıcının mesajı
  final double listingPrice; // İlan fiyatı (karşılaştırma için)
  final double fairPrice; // Adil fiyat (karşılaştırma için)
  final DateTime expirationDate; // Teklifin son geçerlilik tarihi

  // Araç bilgileri (UI'da göstermek için)
  final String vehicleBrand;
  final String vehicleModel;
  final int vehicleYear;
  final String vehicleImageUrl;

  Offer({
    required this.offerId,
    required this.vehicleId,
    required this.sellerId,
    required this.buyerId,
    required this.buyerName,
    required this.offerPrice,
    required this.offerDate,
    required this.status,
    this.message,
    required this.listingPrice,
    required this.fairPrice,
    required this.expirationDate,
    required this.vehicleBrand,
    required this.vehicleModel,
    required this.vehicleYear,
    required this.vehicleImageUrl,
  });

  /// Teklif yüzdesi (-20% gibi)
  double get offerPercentage {
    if (listingPrice == 0) return 0.0;
    return ((offerPrice - listingPrice) / listingPrice) * 100;
  }

  /// Teklifin adil fiyata göre oranı
  double get priceToFairRatio {
    if (fairPrice == 0) return 0.0;
    return offerPrice / fairPrice;
  }

  /// Teklif süresi doldu mu?
  bool get isExpired {
    return DateTime.now().isAfter(expirationDate) && status == OfferStatus.pending;
  }

  /// Teklif hala beklemede mi?
  bool get isPending {
    return status == OfferStatus.pending && !isExpired;
  }

  /// Teklifin yaşı (saat cinsinden)
  int get ageInHours {
    return DateTime.now().difference(offerDate).inHours;
  }

  /// JSON'dan oluştur
  factory Offer.fromJson(Map<String, dynamic> json) {
    return Offer(
      offerId: json['offerId'],
      vehicleId: json['vehicleId'],
      sellerId: json['sellerId'],
      buyerId: json['buyerId'],
      buyerName: json['buyerName'],
      offerPrice: json['offerPrice'].toDouble(),
      offerDate: DateTime.parse(json['offerDate']),
      status: OfferStatus.values[json['status']],
      message: json['message'],
      listingPrice: json['listingPrice'].toDouble(),
      fairPrice: json['fairPrice'].toDouble(),
      expirationDate: DateTime.parse(json['expirationDate']),
      vehicleBrand: json['vehicleBrand'],
      vehicleModel: json['vehicleModel'],
      vehicleYear: json['vehicleYear'],
      vehicleImageUrl: json['vehicleImageUrl'],
    );
  }

  /// JSON'a dönüştür
  Map<String, dynamic> toJson() {
    return {
      'offerId': offerId,
      'vehicleId': vehicleId,
      'sellerId': sellerId,
      'buyerId': buyerId,
      'buyerName': buyerName,
      'offerPrice': offerPrice,
      'offerDate': offerDate.toIso8601String(),
      'status': status.index,
      'message': message,
      'listingPrice': listingPrice,
      'fairPrice': fairPrice,
      'expirationDate': expirationDate.toIso8601String(),
      'vehicleBrand': vehicleBrand,
      'vehicleModel': vehicleModel,
      'vehicleYear': vehicleYear,
      'vehicleImageUrl': vehicleImageUrl,
    };
  }

  /// Kopyala
  Offer copyWith({
    OfferStatus? status,
  }) {
    return Offer(
      offerId: offerId,
      vehicleId: vehicleId,
      sellerId: sellerId,
      buyerId: buyerId,
      buyerName: buyerName,
      offerPrice: offerPrice,
      offerDate: offerDate,
      status: status ?? this.status,
      message: message,
      listingPrice: listingPrice,
      fairPrice: fairPrice,
      expirationDate: expirationDate,
      vehicleBrand: vehicleBrand,
      vehicleModel: vehicleModel,
      vehicleYear: vehicleYear,
      vehicleImageUrl: vehicleImageUrl,
    );
  }
}


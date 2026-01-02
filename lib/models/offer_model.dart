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
  final String vehicleId; // UserVehicle ID'si (user offer için) veya Vehicle ID'si (listing offer için)
  final String sellerId; // İlanı veren kullanıcı ID'si veya satıcı ID'si
  final String buyerId; // AI alıcı ID'si veya kullanıcı ID'si
  final String buyerName; // AI alıcı adı veya kullanıcı adı
  final double offerPrice; // Teklif edilen fiyat
  final DateTime offerDate; // Teklif tarihi
  OfferStatus status; // Teklif durumu
  final String? message; // Alıcının/Kullanıcının mesajı
  final double listingPrice; // İlan fiyatı (karşılaştırma için)
  final double fairPrice; // Adil fiyat (karşılaştırma için)
  final DateTime expirationDate; // Teklifin son geçerlilik tarihi
  
  // Yeni alanlar
  final bool isUserOffer; // Kullanıcı teklifi mi, AI teklifi mi?
  final double? counterOfferAmount; // Karşı teklif tutarı (varsa)
  final String? sellerResponse; // Satıcının/AI'nin cevabı
  
  // 🆕 PATIENCE METER: Pazarlık tur sayısı
  final int negotiationRounds; // Kaç tur pazarlık yapıldı (0'dan başlar)

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
    this.isUserOffer = false,
    this.counterOfferAmount,
    this.sellerResponse,
    this.negotiationRounds = 0, // 🆕 Varsayılan: 0 tur
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
  bool isExpired([DateTime? now]) {
    final referenceTime = now ?? DateTime.now();
    return referenceTime.isAfter(expirationDate) && status == OfferStatus.pending;
  }

  /// Teklif hala beklemede mi?
  bool isPending([DateTime? now]) {
    return status == OfferStatus.pending && !isExpired(now);
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
      isUserOffer: json['isUserOffer'] ?? false,
      counterOfferAmount: json['counterOfferAmount']?.toDouble(),
      sellerResponse: json['sellerResponse'],
      negotiationRounds: json['negotiationRounds'] ?? 0, // 🆕
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
      'isUserOffer': isUserOffer,
      'counterOfferAmount': counterOfferAmount,
      'sellerResponse': sellerResponse,
      'negotiationRounds': negotiationRounds, // 🆕
      'vehicleBrand': vehicleBrand,
      'vehicleModel': vehicleModel,
      'vehicleYear': vehicleYear,
      'vehicleImageUrl': vehicleImageUrl,
    };
  }

  /// Kopyala
  /// Kopyala
  Offer copyWith({
    String? offerId,
    String? vehicleId,
    String? sellerId,
    String? buyerId,
    String? buyerName,
    double? offerPrice,
    DateTime? offerDate,
    OfferStatus? status,
    String? message,
    double? listingPrice,
    double? fairPrice,
    DateTime? expirationDate,
    bool? isUserOffer,
    double? counterOfferAmount,
    String? sellerResponse,
    int? negotiationRounds,
    String? vehicleBrand,
    String? vehicleModel,
    int? vehicleYear,
    String? vehicleImageUrl,
  }) {
    return Offer(
      offerId: offerId ?? this.offerId,
      vehicleId: vehicleId ?? this.vehicleId,
      sellerId: sellerId ?? this.sellerId,
      buyerId: buyerId ?? this.buyerId,
      buyerName: buyerName ?? this.buyerName,
      offerPrice: offerPrice ?? this.offerPrice,
      offerDate: offerDate ?? this.offerDate,
      status: status ?? this.status,
      message: message ?? this.message,
      listingPrice: listingPrice ?? this.listingPrice,
      fairPrice: fairPrice ?? this.fairPrice,
      expirationDate: expirationDate ?? this.expirationDate,
      isUserOffer: isUserOffer ?? this.isUserOffer,
      counterOfferAmount: counterOfferAmount ?? this.counterOfferAmount,
      sellerResponse: sellerResponse ?? this.sellerResponse,
      negotiationRounds: negotiationRounds ?? this.negotiationRounds,
      vehicleBrand: vehicleBrand ?? this.vehicleBrand,
      vehicleModel: vehicleModel ?? this.vehicleModel,
      vehicleYear: vehicleYear ?? this.vehicleYear,
      vehicleImageUrl: vehicleImageUrl ?? this.vehicleImageUrl,
    );
  }
}


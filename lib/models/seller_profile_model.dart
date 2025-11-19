import 'dart:math';

/// AI Satıcı tipleri
enum SellerType {
  strict, // Sert - Sadece yüksek teklifleri kabul eder
  moderate, // Ilımlı - Makul teklifleri değerlendirir
  flexible, // Esnek - Çoğu teklifi kabul eder
  desperate, // Aceleci - Neredeyse her teklifi kabul eder
}

/// AI Satıcı Profili
class SellerProfile {
  final SellerType sellerType;
  final double minAcceptableRatio; // İlan fiyatının minimum %kaçını kabul eder
  final double counterOfferThreshold; // Karşı teklif için eşik (%olarak)
  final double counterOfferIncrease; // Karşı teklif artış oranı

  SellerProfile({
    required this.sellerType,
    required this.minAcceptableRatio,
    required this.counterOfferThreshold,
    required this.counterOfferIncrease,
  });

  /// Random satıcı profili oluştur
  factory SellerProfile.generateRandom() {
    final random = Random();
    
    // Tip seç (ağırlıklı random)
    SellerType type;
    double typeRoll = random.nextDouble();
    if (typeRoll < 0.20) {
      type = SellerType.strict; // %20
    } else if (typeRoll < 0.60) {
      type = SellerType.moderate; // %40
    } else if (typeRoll < 0.90) {
      type = SellerType.flexible; // %30
    } else {
      type = SellerType.desperate; // %10
    }

    double minRatio, counterThreshold, counterIncrease;

    switch (type) {
      case SellerType.strict:
        // Sert: En az %95-100 kabul eder
        minRatio = 0.95 + random.nextDouble() * 0.05;
        counterThreshold = 0.85; // %85 altı için karşı teklif
        counterIncrease = 0.10 + random.nextDouble() * 0.05; // %10-15 artır
        break;
      case SellerType.moderate:
        // Ilımlı: En az %85-95 kabul eder
        minRatio = 0.85 + random.nextDouble() * 0.10;
        counterThreshold = 0.75; // %75 altı için karşı teklif
        counterIncrease = 0.07 + random.nextDouble() * 0.05; // %7-12 artır
        break;
      case SellerType.flexible:
        // Esnek: En az %75-85 kabul eder
        minRatio = 0.75 + random.nextDouble() * 0.10;
        counterThreshold = 0.65; // %65 altı için karşı teklif
        counterIncrease = 0.05 + random.nextDouble() * 0.05; // %5-10 artır
        break;
      case SellerType.desperate:
        // Aceleci: En az %65-75 kabul eder
        minRatio = 0.65 + random.nextDouble() * 0.10;
        counterThreshold = 0.50; // %50 altı için karşı teklif
        counterIncrease = 0.03 + random.nextDouble() * 0.05; // %3-8 artır
        break;
    }

    return SellerProfile(
      sellerType: type,
      minAcceptableRatio: minRatio,
      counterOfferThreshold: counterThreshold,
      counterOfferIncrease: counterIncrease,
    );
  }

  /// Teklifi değerlendir
  Map<String, dynamic> evaluateOffer({
    required double offerPrice,
    required double listingPrice,
  }) {
    final ratio = offerPrice / listingPrice;

    // Çok düşük teklif -> Reddet
    if (ratio < counterOfferThreshold) {
      return {
        'decision': 'reject',
        'response': _getRejectMessage(),
      };
    }
    // Karşı teklif aralığı
    else if (ratio < minAcceptableRatio) {
      final counterOffer = listingPrice * (1 - (1 - ratio) * (1 - counterOfferIncrease));
      return {
        'decision': 'counter',
        'counterAmount': counterOffer,
        'response': _getCounterOfferMessage(counterOffer),
      };
    }
    // Kabul edilebilir teklif -> Kabul et
    else {
      return {
        'decision': 'accept',
        'response': _getAcceptMessage(),
      };
    }
  }

  String _getRejectMessage() {
    final messages = [
      'Maalesef bu fiyat çok düşük. Başka teklifler bekliyorum.',
      'Bu teklifi kabul edemem. Daha gerçekçi bir fiyat bekliyorum.',
      'Araç bu fiyata uygun değil. Teşekkürler.',
      'Fiyat beklentilerimin çok altında. Reddediyorum.',
      'Bu teklif benim için uygun değil.',
    ];
    return messages[Random().nextInt(messages.length)];
  }

  String _getCounterOfferMessage(double amount) {
    final messages = [
      'Bu fiyata satamam ama ${_formatCurrency(amount)} TL\'ye anlaşabiliriz.',
      'Biraz düşük kaldı. ${_formatCurrency(amount)} TL olursa tamam.',
      'Karşı teklifim: ${_formatCurrency(amount)} TL. Kabul eder misiniz?',
      'Arada bir yerde buluşalım: ${_formatCurrency(amount)} TL.',
      'Size özel ${_formatCurrency(amount)} TL son fiyatım.',
    ];
    return messages[Random().nextInt(messages.length)];
  }

  String _getAcceptMessage() {
    final messages = [
      'Teklifiniz uygun, kabul ediyorum!',
      'Anlaştık! Teklifi kabul ediyorum.',
      'Uygun bir fiyat, kabul.',
      'Tamam, bu fiyata anlaşalım.',
      'Teklifinizi kabul ediyorum. Teşekkürler!',
    ];
    return messages[Random().nextInt(messages.length)];
  }

  String _formatCurrency(double value) {
    return value.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    );
  }
}


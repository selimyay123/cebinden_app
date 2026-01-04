import 'dart:math';

/// AI alıcı tipleri
enum BuyerType {
  bargainer, // Pazarlıkçı - Düşük teklif verir
  realistic, // Gerçekçi - Adil fiyat civarı
  urgent, // Acil - İlan fiyatına yakın
  generous, // Cömert - İlan fiyatı veya üstü
}

/// AI Alıcı Modeli
class AIBuyer {
  final String buyerId;
  final String buyerName;
  final BuyerType buyerType;
  final double budget; // Bütçe
  final List<String> preferredBrands; // Tercih edilen markalar
  final double maxPaymentRatio; // Adil fiyatın kaç katını ödeyebilir (0.8 - 1.2)
  final String message; // Teklif mesajı

  AIBuyer({
    required this.buyerId,
    required this.buyerName,
    required this.buyerType,
    required this.budget,
    required this.preferredBrands,
    required this.maxPaymentRatio,
    required this.message,
  });

  /// Random AI alıcı oluştur
  factory AIBuyer.generateRandom({int? seed}) {
    final random = seed != null ? Random(seed) : Random();
    
    // Tip seç (ağırlıklı random)
    BuyerType type;
    double typeRoll = random.nextDouble();
    if (typeRoll < 0.45) {
      type = BuyerType.bargainer; // %45 (Eskiden %50)
    } else if (typeRoll < 0.75) {
      type = BuyerType.realistic; // %30 (Değişmedi)
    } else if (typeRoll < 0.93) {
      type = BuyerType.urgent; // %18 (Eskiden %15)
    } else {
      type = BuyerType.generous; // %7 (Eskiden %5)
    }

    // İsim oluştur
    String name = _generateRandomName(random);
    
    // Bütçe belirle (500K - 5M arası)
    double budget = 500000 + random.nextDouble() * 4500000;
    
    // Tercih edilen markalar (1-3 arası)
    List<String> preferredBrands = _generatePreferredBrands(random);
    
    // Max ödeme oranı (tipe göre)
    double maxPaymentRatio;
    String message;
    
    switch (type) {
      case BuyerType.bargainer:
        maxPaymentRatio = 0.75 + random.nextDouble() * 0.15; // 0.75-0.90
        message = _getBargainerMessage(random);
        break;
      case BuyerType.realistic:
        maxPaymentRatio = 0.95 + random.nextDouble() * 0.10; // 0.95-1.05
        message = _getRealisticMessage(random);
        break;
      case BuyerType.urgent:
        maxPaymentRatio = 0.95 + random.nextDouble() * 0.10; // 0.95-1.05
        message = _getUrgentMessage(random);
        break;
      case BuyerType.generous:
        maxPaymentRatio = 1.00 + random.nextDouble() * 0.15; // 1.00-1.15
        message = _getGenerousMessage(random);
        break;
    }
    
    return AIBuyer(
      buyerId: 'ai_${DateTime.now().millisecondsSinceEpoch}_${random.nextInt(1000)}',
      buyerName: name,
      buyerType: type,
      budget: budget,
      preferredBrands: preferredBrands,
      maxPaymentRatio: maxPaymentRatio,
      message: message,
    );
  }

  /// Teklif miktarı hesapla
  double calculateOffer({
    required double listingPrice,
    required double fairPrice,
  }) {
    final random = Random();
    double offerPrice;
    
    switch (buyerType) {
      case BuyerType.bargainer:
        // İlan fiyatının %75-90'ını teklif eder
        offerPrice = listingPrice * (0.75 + random.nextDouble() * 0.15);
        break;
      case BuyerType.realistic:
        // Adil fiyatın %95-105'ini teklif eder
        offerPrice = fairPrice * (0.95 + random.nextDouble() * 0.10);
        break;
      case BuyerType.urgent:
        // İlan fiyatının %92-97'sini teklif eder (Eskiden %95-100 idi)
        offerPrice = listingPrice * (0.92 + random.nextDouble() * 0.05);
        break;
      case BuyerType.generous:
        // İlan fiyatının %96-99'unu teklif eder (Eskiden %98-100 idi)
        offerPrice = listingPrice * (0.96 + random.nextDouble() * 0.03);
        break;
    }
    
    // Bütçeyi aşmamalı
    if (offerPrice > budget) {
      offerPrice = budget * 0.95; // Bütçenin %95'i
    }

    // 🆕 KESİN KURAL: Teklif asla ilan fiyatını geçemez, hatta biraz altında olmalı
    // Kullanıcı isteği: 400k için max 395k gelsin (~%98-99)
    if (offerPrice >= listingPrice) {
      offerPrice = listingPrice * 0.99; // En fazla %99'u
    }
    
    // 1000'e yuvarla
    return (offerPrice / 1000).round() * 1000.0;
  }

  /// Karşı teklifin kabul edilme olasılığını hesapla (0.0 - 1.0)
  double calculateAcceptanceChance({
    required double counterOfferAmount,
    required double originalOfferPrice,
    required double listingPrice,
    double sweetTalkBonus = 0.0,
  }) {
    // 1. Kullanıcı, AI'nın teklifinden DAHA DÜŞÜK veya EŞİT bir şey istediyse -> DİREKT KABUL
    if (counterOfferAmount <= originalOfferPrice) return 1.0;

    final priceRatio = counterOfferAmount / listingPrice;
    final initialOfferRatio = originalOfferPrice / listingPrice;
    
    // Alıcının tipine göre agresiflik seviyesi
    double aggressiveness;
    switch (buyerType) {
      case BuyerType.bargainer:
        aggressiveness = 0.8;
        break;
      case BuyerType.realistic:
        aggressiveness = 0.5;
        break;
      case BuyerType.urgent:
        aggressiveness = 0.2;
        break;
      case BuyerType.generous:
        aggressiveness = 0.1;
        break;
    }

    // 2. Fiyat Oranına Göre Değerlendirme (OfferService._evaluateCounterOfferByBuyer ile uyumlu)
    
    // Eğer satıcı ilana çok yakın bir fiyat istiyorsa (%90 üzeri) ve alıcı düşükten başladıysa
    if (priceRatio >= 0.90 && initialOfferRatio < 0.90) {
      return (0.1 + sweetTalkBonus).clamp(0.0, 1.0);
    }

    if (priceRatio >= 0.95) {
      return (0.3 + sweetTalkBonus).clamp(0.0, 1.0);
    } else if (priceRatio >= 0.85) {
      return (0.6 + (aggressiveness * 0.2) + sweetTalkBonus).clamp(0.0, 1.0);
    } else if (priceRatio >= 0.70) {
      return (0.8 + sweetTalkBonus).clamp(0.0, 1.0);
    } else {
      return 1.0;
    }
  }

  /// Bu alıcı bu ilana ilgilenebilir mi?
  bool isInterestedIn({
    required String vehicleBrand,
    required double listingPrice,
    required double fairPrice,
  }) {
    // Bütçe kontrolü (daha gevşek)
    if (listingPrice > budget * 1.3) return false; // Bütçenin %130'undan fazla olamaz
    
    // Marka tercihi kontrolü (ağırlıklı)
    bool brandMatch = preferredBrands.contains(vehicleBrand);
    
    // Fiyat/değer oranı kontrolü
    double priceRatio = listingPrice / fairPrice;
    bool goodDeal = priceRatio <= maxPaymentRatio;
    
    // Karar ver (daha gevşek kriterler)
    if (brandMatch && goodDeal) {
      return true; // %100 ilgilenir
    } else if (brandMatch) {
      return Random().nextDouble() < 0.75; // Marka uygun ama pahalı, %75 şans
    } else if (goodDeal) {
      return Random().nextDouble() < 0.80; // Fiyat uygun, %80 şans
    } else if (priceRatio < 1.2) {
      return Random().nextDouble() < 0.50; // Makul fiyat, %50 şans
    } else {
      return Random().nextDouble() < 0.20; // Her durumda %20 şans (genel ilgi)
    }
  }
  
  /// Bağlamsal mesaj üret (Aracın durumuna göre)
  /// Eğer null dönerse standart mesaj kullanılmalı
  String? generateContextualMessage({
    required int mileage,
    required bool hasAccidentRecord,
    required double listingPrice,
    required double fairPrice,
  }) {
    final random = Random();
    
    // %60 ihtimalle bağlamsal mesaj üret (yoksa standart mesaj kalsın)
    if (random.nextDouble() > 0.6) return null;
    
    List<String> possibleMessages = [];
    
    // 1. Hasar Durumu Kontrolü
    if (hasAccidentRecord) {
      // Hasarlı araç
      possibleMessages.add(_getContextualMessage('accident', random));
    } else {
      // Temiz araç (%50 şansla öv)
      if (random.nextBool()) {
        possibleMessages.add(_getContextualMessage('clean', random));
      }
    }
    
    // 2. Kilometre Kontrolü
    if (mileage > 150000) {
      // Yüksek km
      possibleMessages.add(_getContextualMessage('highMileage', random));
    } else if (mileage < 50000) {
      // Düşük km
      possibleMessages.add(_getContextualMessage('lowMileage', random));
    }
    
    // 3. Fiyat Kontrolü
    double priceRatio = listingPrice / fairPrice;
    if (priceRatio > 1.15) {
      // Pahalı (%15'ten fazla)
      possibleMessages.add(_getContextualMessage('expensive', random));
    } else if (priceRatio < 0.90) {
      // Ucuz (%10'dan fazla indirimli)
      possibleMessages.add(_getContextualMessage('cheap', random));
    }
    
    if (possibleMessages.isEmpty) return null;
    
    // Olası mesajlardan birini seç
    return possibleMessages[random.nextInt(possibleMessages.length)];
  }

  static String _getContextualMessage(String category, Random random) {
    // 1-4 arası random sayı
    int index = 1 + random.nextInt(4);
    return 'aiBuyer.messages.contextual.$category.$index';
  }

  // === HELPER METHODS ===

  static String _generateRandomName(Random random) {
    final firstNames = [
      'Ahmet', 'Mehmet', 'Zeynep', 'Ayşe', 'Can', 'Elif', 
      'Burak', 'Selin', 'Emre', 'Deniz', 'Cem', 'Merve',
      'Kaan', 'Esra', 'Murat', 'Burcu', 'Onur', 'Gizem',
      'Serkan', 'Ebru', 'Tolga', 'Pınar', 'Barış', 'Seda',
    ];
    
    final lastInitials = [
      'A.', 'B.', 'C.', 'D.', 'E.', 'F.', 'G.', 'H.', 
      'İ.', 'J.', 'K.', 'L.', 'M.', 'N.', 'Ö.', 'P.',
      'R.', 'S.', 'T.', 'U.', 'Ü.', 'V.', 'Y.', 'Z.',
    ];
    
    return '${firstNames[random.nextInt(firstNames.length)]} ${lastInitials[random.nextInt(lastInitials.length)]}';
  }

  static List<String> _generatePreferredBrands(Random random) {
    // Fictional brand names used in the app
    final allBrands = [
      'Bavora', 'Mercurion', 'Audira', 'Volkstar', 'Fortran',
      'Renauva', 'Fialto', 'Koyoro', 'Hanto', /* 'Hundar', */ 'Oplon',
    ];
    
    // 2-4 arası marka seç (daha geniş tercihler)
    int brandCount = 2 + random.nextInt(3);
    List<String> selected = [];
    
    for (int i = 0; i < brandCount && i < allBrands.length; i++) {
      String brand = allBrands[random.nextInt(allBrands.length)];
      if (!selected.contains(brand)) {
        selected.add(brand);
      }
    }
    
    return selected;
  }

  static String _getBargainerMessage(Random random) {
    final messages = [
      'aiBuyer.messages.bargainer.1',
      'aiBuyer.messages.bargainer.2',
      'aiBuyer.messages.bargainer.3',
      'aiBuyer.messages.bargainer.4',
      'aiBuyer.messages.bargainer.5',
    ];
    return messages[random.nextInt(messages.length)];
  }

  static String _getRealisticMessage(Random random) {
    final messages = [
      'aiBuyer.messages.realistic.1',
      'aiBuyer.messages.realistic.2',
      'aiBuyer.messages.realistic.3',
      'aiBuyer.messages.realistic.4',
      'aiBuyer.messages.realistic.5',
    ];
    return messages[random.nextInt(messages.length)];
  }

  static String _getUrgentMessage(Random random) {
    final messages = [
      'aiBuyer.messages.urgent.1',
      'aiBuyer.messages.urgent.2',
      'aiBuyer.messages.urgent.3',
      'aiBuyer.messages.urgent.4',
      'aiBuyer.messages.urgent.5',
    ];
    return messages[random.nextInt(messages.length)];
  }

  static String _getGenerousMessage(Random random) {
    final messages = [
      'aiBuyer.messages.generous.1',
      'aiBuyer.messages.generous.2',
      'aiBuyer.messages.generous.3',
      'aiBuyer.messages.generous.4',
      'aiBuyer.messages.generous.5',
    ];
    return messages[random.nextInt(messages.length)];
  }
}


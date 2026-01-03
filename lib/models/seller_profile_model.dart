import 'dart:math';
import '../services/localization_service.dart';
import '../services/skill_service.dart';
import '../models/user_model.dart';

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
  
  // 🆕 ZONE SYSTEM - 3 Bölge tanımı
  final double insultZoneThreshold; // Hakaret bölgesi eşiği (örn: %70)
  final double negotiationZoneThreshold; // Müzakere bölgesi eşiği (örn: %90)
  
  // 🆕 FUZZY LOGIC - Karar noktalarında sapma
  final double fuzzyLogicVariance; // Karar noktalarındaki sapma oranı (örn: %2-3)
  
  // 🆕 PATIENCE METER - Sabır/Tansiyon sistemi
  final int maxPatience; // Maksimum pazarlık turu (2-5 arası)
  
  // 🆕 RESERVE PRICE - Görünmeyen minimum fiyat
  final double reservePriceRatio; // İlan fiyatının %kaçına inmek ister (örn: 0.85 = %85'ine kadar iner)

  SellerProfile({
    required this.sellerType,
    required this.minAcceptableRatio,
    required this.counterOfferThreshold,
    required this.counterOfferIncrease,
    required this.insultZoneThreshold,
    required this.negotiationZoneThreshold,
    required this.fuzzyLogicVariance,
    required this.maxPatience,
    required this.reservePriceRatio, // 🆕
  });

  /// Random satıcı profili oluştur
  factory SellerProfile.generateRandom({int? seed}) {
    final random = seed != null ? Random(seed) : Random();
    
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
    double insultZone, negotiationZone, fuzzyVariance;
    int patience;
    double reserveRatio;

    switch (type) {
      case SellerType.strict:
        // Sert (Tok Satıcı/Binici): En az %98-100 kabul eder (YÜKSEK!)
        minRatio = 0.98 + random.nextDouble() * 0.02;
        counterThreshold = 0.88; // %88 altı için direkt red
        counterIncrease = 0.15 + random.nextDouble() * 0.08; // %15-23 artır (AGRESIF)
        // 🆕 Zone System
        insultZone = 0.82; // %82 altı hakaret (YÜKSEK!)
        negotiationZone = 0.97; // %97 altı müzakere (ÇOK YÜKSEK!)
        fuzzyVariance = 0.015; // %1.5 sapma (daha az random, daha katı)
        // 🆕 Patience
        patience = 2 + random.nextInt(2); // 2-3 tur (çabuk sıkılır)
        // 🆕 Reserve Price
        reserveRatio = 0.95 + random.nextDouble() * 0.04; // %95-99 (neredeyse inmez!)
        break;
      case SellerType.moderate:
        // Ilımlı (Galerici): En az %94-98 kabul eder (YÜKSEK!)
        minRatio = 0.94 + random.nextDouble() * 0.04;
        counterThreshold = 0.82; // %82 altı için direkt red
        counterIncrease = 0.12 + random.nextDouble() * 0.06; // %12-18 artır
        // 🆕 Zone System
        insultZone = 0.75; // %75 altı hakaret
        negotiationZone = 0.93; // %93 altı müzakere (YÜKSEK!)
        fuzzyVariance = 0.02; // %2 sapma
        // 🆕 Patience
        patience = 3 + random.nextInt(2); // 3-4 tur (dengeli sabır)
        // 🆕 Reserve Price
        reserveRatio = 0.90 + random.nextDouble() * 0.06; // %90-96 (daha katı)
        break;
      case SellerType.flexible:
        // Esnek: En az %88-94 kabul eder (ORTA-YÜKSEK!)
        minRatio = 0.88 + random.nextDouble() * 0.06;
        counterThreshold = 0.75; // %75 altı için direkt red
        counterIncrease = 0.08 + random.nextDouble() * 0.05; // %8-13 artır
        // 🆕 Zone System
        insultZone = 0.68; // %68 altı hakaret
        negotiationZone = 0.87; // %87 altı müzakere
        fuzzyVariance = 0.025; // %2.5 sapma
        // 🆕 Patience
        patience = 4 + random.nextInt(2); // 4-5 tur (sabırlı)
        // 🆕 Reserve Price
        reserveRatio = 0.85 + random.nextDouble() * 0.07; // %85-92 (esnek ama yine yüksek)
        break;
      case SellerType.desperate:
        // Aceleci (Acil Satıcı): En az %82-88 kabul eder (ORTA)
        minRatio = 0.82 + random.nextDouble() * 0.06;
        counterThreshold = 0.68; // %68 altı için direkt red
        counterIncrease = 0.06 + random.nextDouble() * 0.05; // %6-11 artır
        // 🆕 Zone System
        insultZone = 0.60; // %60 altı hakaret
        negotiationZone = 0.82; // %82 altı müzakere
        fuzzyVariance = 0.03; // %3 sapma
        // 🆕 Patience
        patience = 5 + random.nextInt(2); // 5-6 tur (çok sabırlı)
        // 🆕 Reserve Price
        reserveRatio = 0.78 + random.nextDouble() * 0.08; // %78-86 (esnek ama yine de yüksek)
        break;
    }

    return SellerProfile(
      sellerType: type,
      minAcceptableRatio: minRatio,
      counterOfferThreshold: counterThreshold,
      counterOfferIncrease: counterIncrease,
      insultZoneThreshold: insultZone,
      negotiationZoneThreshold: negotiationZone,
      fuzzyLogicVariance: fuzzyVariance,
      maxPatience: patience,
      reservePriceRatio: reserveRatio, // 🆕
    );
  }

  /// Teklifin kabul edilme olasılığını hesapla (0.0 - 1.0)
  double calculateAcceptanceChance({
    required double offerPrice,
    required double listingPrice,
    dynamic buyerUser,
  }) {
    // 🆕 SKILL CHECK: Ölücü yeteneği var mı?
    double negotiationPowerBonus = 0.0;
    if (buyerUser != null && buyerUser is User) {
      final skillService = SkillService();
      final level = skillService.getSkillLevel(buyerUser, SkillService.skillLowballer);
      negotiationPowerBonus = SkillService.lowballerBonuses[level] ?? 0.0;
    }
    
    // 🆕 RESERVE PRICE: Satıcının kafasındaki gerçek minimum fiyat
    final reservePrice = listingPrice * reservePriceRatio;
    
    // 🆕 PRICE BAND ADJUSTMENT
    final priceBandMultiplier = _calculatePriceBandMultiplier(listingPrice);
    final priceBandBonus = _calculatePriceBandBonus(listingPrice);
    
    // Oran hesapla (fuzzy logic olmadan, saf oran)
    final ratio = offerPrice / reservePrice;
    
    // Eşikler
    final adjustedInsultZone = insultZoneThreshold * priceBandMultiplier;
    final adjustedNegotiationZone = negotiationZoneThreshold + (1.0 - priceBandMultiplier) * 0.05;
    final adjustedMinAcceptable = (minAcceptableRatio + priceBandBonus) - negotiationPowerBonus;
    
    // Olasılık Hesabı
    if (ratio < adjustedInsultZone) {
      return 0.0; // Hakaret bölgesi -> %0 şans
    } else if (ratio < adjustedNegotiationZone) {
      // Müzakere bölgesi -> Düşük şans (karşı teklif gelir)
      // Oran arttıkça şans artar (0.0 -> 0.3)
      final range = adjustedNegotiationZone - adjustedInsultZone;
      final progress = (ratio - adjustedInsultZone) / range;
      return 0.05 + (progress * 0.25); // %5 - %30 arası
    } else if (ratio < adjustedMinAcceptable) {
      // Kabul bölgesine yakın ama altında -> Orta şans (0.3 -> 0.7)
      final range = adjustedMinAcceptable - adjustedNegotiationZone;
      final progress = (ratio - adjustedNegotiationZone) / range;
      return 0.30 + (progress * 0.40); // %30 - %70 arası
    } else {
      // Kabul bölgesi -> Yüksek şans (0.7 -> 1.0)
      // Oran arttıkça şans artar
      // Eğer adjustedMinAcceptable'ın %5 üzerindeyse kesin kabul (%100)
      final upperLimit = adjustedMinAcceptable * 1.05;
      if (ratio >= upperLimit) return 1.0;
      
      final range = upperLimit - adjustedMinAcceptable;
      final progress = (ratio - adjustedMinAcceptable) / range;
      return 0.70 + (progress * 0.30); // %70 - %100 arası
    }
  }

  /// Teklifi değerlendir (🆕 ALL SYSTEMS: ZONE + FUZZY + PRICE BANDS + PATIENCE + RESERVE + SKILL)
  Map<String, dynamic> evaluateOffer({
    required double offerPrice,
    required double listingPrice,
    int currentRounds = 0, // Mevcut pazarlık turu
    dynamic buyerUser, // 🆕 Alıcı kullanıcı (skill kontrolü için)
  }) {
    final random = Random();
    
    // 🆕 SKILL CHECK: Ölücü yeteneği var mı?
    double negotiationPowerBonus = 0.0;
    if (buyerUser != null && buyerUser is User) {
      final skillService = SkillService();
      final level = skillService.getSkillLevel(buyerUser, SkillService.skillLowballer);
      negotiationPowerBonus = SkillService.lowballerBonuses[level] ?? 0.0;
    }
    
    
    // 🆕 RESERVE PRICE: Satıcının kafasındaki gerçek minimum fiyat
    // Kullanıcı ilan fiyatını görür ama bot reserve price'a göre karar verir!
    final reservePrice = listingPrice * reservePriceRatio;
    
    // 🆕 PRICE BAND ADJUSTMENT: Araç fiyatına göre eşikleri ayarla
    // Yüksek fiyatlı araçlarda daha katı ol
    final priceBandMultiplier = _calculatePriceBandMultiplier(listingPrice);
    final priceBandBonus = _calculatePriceBandBonus(listingPrice); // 🆕 Yüksek fiyat = yüksek eşik
    
    // 🆕 FUZZY LOGIC: Küçük bir rastgele sapma ekle (%2-3)
    // Bu, aynı teklifin her seferinde farklı sonuç verebilmesini sağlar
    final fuzzyFactor = 1.0 + (random.nextDouble() * 2 - 1) * fuzzyLogicVariance;
    
    // 🆕 KRİTİK: Artık teklifin RESERVE PRICE'a olan oranını kullanıyoruz!
    // Böylece aynı fiyatlı araçlar farklı reserve'lere sahipse farklı davranırlar
    final adjustedRatio = (offerPrice / reservePrice) * fuzzyFactor;
    
    // Fiyat bandına göre ayarlanmış eşikler
    final adjustedInsultZone = insultZoneThreshold * priceBandMultiplier;
    final adjustedNegotiationZone = negotiationZoneThreshold + (1.0 - priceBandMultiplier) * 0.05;
    
    // 🆕 KRİTİK: Kabul eşiğini fiyat bandına göre YÜKSELT!
    // Pahalı araçlarda daha yüksek oran gerekli
    // 🆕 SKILL BONUS: Pazarlık Gücü varsa eşiği düşür (alıcı lehine)
    final adjustedMinAcceptable = (minAcceptableRatio + priceBandBonus) - negotiationPowerBonus;
    
    // 🆕 PATIENCE CHECK: Sabır tükendi mi?
    final isPatienceExhausted = currentRounds >= maxPatience;
    
    if (isPatienceExhausted) {
      // Sabır tükendi! Artık karşı teklif yok, nihai karar zamanı
      // Eğer teklif minimum kabul edilebilir oranın üstündeyse kabul et, değilse reddet
      // 🆕 Fiyat bandına göre ayarlanmış eşiği kullan
      if (adjustedRatio >= adjustedMinAcceptable * 0.90) {
        // Son bir şans: %90'dan fazlası ise kabul et
        return {
          'decision': 'accept',
          'response': _getPatienceExhaustedAcceptMessage(),
          'zone': 'patience_exhausted_accept',
        };
      } else {
        // Artık yeter, reddediyorum
        return {
          'decision': 'reject',
          'response': _getPatienceExhaustedRejectMessage(),
          'zone': 'patience_exhausted_reject',
        };
      }
    }
    
    // 🆕 ZONE SYSTEM: 3 Bölge Kontrolü (Fiyat Bandına Göre Ayarlanmış)
    
    // 🔴 BÖLGE 1: HAKARET BÖLGESÖ (Insult Zone)
    // Çok düşük teklif - Satıcı hakaret olarak algılar
    if (adjustedRatio < adjustedInsultZone) {
      return {
        'decision': 'reject',
        'response': _getInsultZoneMessage(), // Sert mesajlar
        'zone': 'insult', // Debug için
      };
    }
    
    // 🟡 BÖLGE 2: MÜZAKERE BÖLGESÖ (Negotiation Zone)
    // Düşük ama pazarlık yapılabilir teklif
    else if (adjustedRatio < adjustedNegotiationZone) {
      // 🆕 MANTIKLI KARŞI TEKLİF: Orta yolu bul + satıcı lehine hafif kayma
      // RESERVE PRICE kullanarak hesapla (gerçek hedef fiyat)
      final counterOffer = _calculateSmartCounterOffer(
        offerPrice: offerPrice,
        listingPrice: listingPrice,
        reservePrice: reservePrice, // 🆕 Gerçek hedef
        sellerBias: counterOfferIncrease,
        random: random,
      );
      
      return {
        'decision': 'counter',
        'counterAmount': counterOffer,
        'response': _getCounterOfferMessage(counterOffer),
        'zone': 'negotiation', // Debug için
      };
    }
    
    // 🟢 BÖLGE 3: KABUL BÖLGESÖ (Acceptance Zone)
    // Yüksek teklif - Kabul edilebilir veya son nazlanma
    else {
      // 🆕 Fiyat bandına göre ayarlanmış kabul eşiğini kontrol et
      if (adjustedRatio >= adjustedMinAcceptable) {
        // Fuzzy logic: Bazen yüksek teklifi bile nazlanarak kabul et
        if (adjustedRatio >= 0.95 && adjustedRatio < 0.98 && random.nextDouble() < 0.15) {
          // %15 ihtimalle "biraz daha artsanız?" diye nazlan
          final finalOffer = offerPrice * 1.02; // %2 daha fazla iste
          return {
            'decision': 'counter',
            'counterAmount': finalOffer,
            'response': _getFinalBargainMessage(finalOffer),
            'zone': 'final_bargain',
          };
        }
        
        return {
          'decision': 'accept',
          'response': _getAcceptMessage(),
          'zone': 'accept',
        };
      } else {
        // 🆕 Kabul bölgesinde ama eşik altında - karşı teklif ver
        final counterOffer = _calculateSmartCounterOffer(
          offerPrice: offerPrice,
          listingPrice: listingPrice,
          reservePrice: reservePrice,
          sellerBias: counterOfferIncrease,
          random: random,
        );
        
        return {
          'decision': 'counter',
          'counterAmount': counterOffer,
          'response': _getCounterOfferMessage(counterOffer),
          'zone': 'acceptance_counter',
        };
      }
    }
  }

  // 🆕 HAKARET BÖLGESÖ MESAJLARI (Sert ve net)
  String _getInsultZoneMessage() {
    final messages = [
      'negotiation.insult.1'.tr(),
      'negotiation.insult.2'.tr(),
      'negotiation.insult.3'.tr(),
      'negotiation.insult.4'.tr(),
      'negotiation.insult.5'.tr(),
      'negotiation.insult.6'.tr(),
      'negotiation.insult.7'.tr(),
    ];
    return messages[Random().nextInt(messages.length)];
  }
  
  // Eski normal red mesajları (artık kullanılmıyor ama bırakıyorum)
  String _getRejectMessage() {
    final messages = [
      'negotiation.reject.1'.tr(),
      'negotiation.reject.2'.tr(),
      'negotiation.reject.3'.tr(),
      'negotiation.reject.4'.tr(),
      'negotiation.reject.5'.tr(),
    ];
    return messages[Random().nextInt(messages.length)];
  }

  String _getCounterOfferMessage(double amount) {
    final messages = [
      'negotiation.counter.1'.trParams({'amount': _formatCurrency(amount)}),
      'negotiation.counter.2'.trParams({'amount': _formatCurrency(amount)}),
      'negotiation.counter.3'.trParams({'amount': _formatCurrency(amount)}),
      'negotiation.counter.4'.trParams({'amount': _formatCurrency(amount)}),
      'negotiation.counter.5'.trParams({'amount': _formatCurrency(amount)}),
    ];
    return messages[Random().nextInt(messages.length)];
  }

  String _getAcceptMessage() {
    final messages = [
      'negotiation.accept.1'.tr(),
      'negotiation.accept.2'.tr(),
      'negotiation.accept.3'.tr(),
      'negotiation.accept.4'.tr(),
      'negotiation.accept.5'.tr(),
    ];
    return messages[Random().nextInt(messages.length)];
  }
  
  // 🆕 SON NAZLANMA MESAJLARI (İyi teklif ama biraz daha istiyor)
  String _getFinalBargainMessage(double finalAmount) {
    final messages = [
      'negotiation.finalBargain.1'.trParams({'amount': _formatCurrency(finalAmount)}),
      'negotiation.finalBargain.2'.trParams({'amount': _formatCurrency(finalAmount)}),
      'negotiation.finalBargain.3'.trParams({'amount': _formatCurrency(finalAmount)}),
      'negotiation.finalBargain.4'.trParams({'amount': _formatCurrency(finalAmount)}),
      'negotiation.finalBargain.5'.trParams({'amount': _formatCurrency(finalAmount)}),
    ];
    return messages[Random().nextInt(messages.length)];
  }
  
  // 🆕 SABIR TÜKENDİ - KABUL MESAJLARI
  String _getPatienceExhaustedAcceptMessage() {
    final messages = [
      'negotiation.patienceExhaustedAccept.1'.tr(),
      'negotiation.patienceExhaustedAccept.2'.tr(),
      'negotiation.patienceExhaustedAccept.3'.tr(),
      'negotiation.patienceExhaustedAccept.4'.tr(),
      'negotiation.patienceExhaustedAccept.5'.tr(),
    ];
    return messages[Random().nextInt(messages.length)];
  }
  
  // 🆕 SABIR TÜKENDİ - RED MESAJLARI
  String _getPatienceExhaustedRejectMessage() {
    final messages = [
      'negotiation.patienceExhaustedReject.1'.tr(),
      'negotiation.patienceExhaustedReject.2'.tr(),
      'negotiation.patienceExhaustedReject.3'.tr(),
      'negotiation.patienceExhaustedReject.4'.tr(),
      'negotiation.patienceExhaustedReject.5'.tr(),
      'negotiation.patienceExhaustedReject.6'.tr(),
    ];
    return messages[Random().nextInt(messages.length)];
  }

  String _formatCurrency(double value) {
    return value.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    );
  }
  
  // 🆕 PRICE BAND MULTIPLIER: Araç fiyatına göre eşik çarpanı
  // Yüksek fiyatlı araçlarda daha katı eşikler (zone thresholds için)
  double _calculatePriceBandMultiplier(double listingPrice) {
    if (listingPrice < 500000) {
      return 1.0; // 0-500K: Normal eşikler (esnek)
    } else if (listingPrice < 1000000) {
      return 0.95; // 500K-1M: %5 daha sıkı
    } else if (listingPrice < 3000000) {
      return 0.90; // 1M-3M: %10 daha sıkı
    } else {
      return 0.85; // 3M+: %15 daha sıkı
    }
  }
  
  // 🆕 PRICE BAND BONUS: Araç fiyatı arttıkça kabul eşiğini YÜKSELTir
  // Pahalı araçlarda daha yüksek teklif oranı gerekli
  double _calculatePriceBandBonus(double listingPrice) {
    if (listingPrice < 500000) {
      return 0.0; // 0-500K: Normal kabul eşiği
    } else if (listingPrice < 1000000) {
      return 0.01; // 500K-1M: +%1 daha yüksek eşik
    } else if (listingPrice < 2000000) {
      return 0.02; // 1M-2M: +%2 daha yüksek
    } else if (listingPrice < 3000000) {
      return 0.03; // 2M-3M: +%3 daha yüksek
    } else if (listingPrice < 5000000) {
      return 0.04; // 3M-5M: +%4 daha yüksek
    } else {
      return 0.05; // 5M+: +%5 daha yüksek (ÇOK KATİ!)
    }
  }
  
  // 🆕 SMART COUNTER OFFER: Mantıklı karşı teklif hesapla
  // 🔥 KRİTİK: Karşı teklifler İLAN FİYATINA YAKIN olmalı, orta nokta değil!
  // Gerçek hayatta galericiler çok az iner
  double _calculateSmartCounterOffer({
    required double offerPrice,
    required double listingPrice,
    required double reservePrice, // Satıcının gerçek hedefi
    required double sellerBias, // 0.06-0.23 arası (satıcının ısrarı)
    required Random random,
  }) {
    // 1. 🔥 YENİ MANTIK: İlan fiyatından başla, satıcı bias'ına göre az iner
    // Eski: Orta noktayı bul → ÇOK YUMUŞAK ❌
    // Yeni: İlan fiyatından küçük bir indirim yap → GERÇEKÇÖ ✅
    
    // 2. Kullanıcı teklifini dikkate al (çok düşükse biraz daha iner)
    // Ama yine de ilan fiyatına yakın kalır
    final userOfferRatio = offerPrice / listingPrice;
    
    double adjustedCounter;
    if (userOfferRatio < 0.85) {
      // Çok düşük teklif, biraz daha aşağı in ama yine de yüksek kal
      adjustedCounter = listingPrice * (0.93 + random.nextDouble() * 0.04); // %93-97
    } else if (userOfferRatio < 0.92) {
      // Orta teklif, ilan fiyatına yakın dur
      adjustedCounter = listingPrice * (0.95 + random.nextDouble() * 0.03); // %95-98
    } else {
      // İyi teklif, çok az in
      adjustedCounter = listingPrice * (0.97 + random.nextDouble() * 0.02); // %97-99
    }
    
    // 4. Reserve price'ın altına inme (mantık kontrolü)
    double lowerBound1 = reservePrice * 1.02;
    final upperBound = listingPrice * 0.99;
    
    // Lower bound upper bound'dan büyük olamaz
    if (lowerBound1 > upperBound) {
      lowerBound1 = upperBound;
    }
    
    adjustedCounter = adjustedCounter.clamp(lowerBound1, upperBound);
    
    // 5. Kullanıcı teklifinden mutlaka yüksek ol
    double lowerBound2 = offerPrice * 1.05;
    
    // Lower bound upper bound'dan büyük olamaz
    if (lowerBound2 > upperBound) {
      lowerBound2 = upperBound;
    }
    
    adjustedCounter = adjustedCounter.clamp(lowerBound2, upperBound);
    
    // 6. 1000'e yuvarla (daha gerçekçi görünsün)
    return (adjustedCounter / 1000).round() * 1000.0;
  }
}


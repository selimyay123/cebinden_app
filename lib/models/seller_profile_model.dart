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
    double insultZone, negotiationZone, fuzzyVariance;
    int patience;
    double reserveRatio;

    switch (type) {
      case SellerType.strict:
        // Sert (Tok Satıcı/Binici): En az %95-100 kabul eder
        minRatio = 0.95 + random.nextDouble() * 0.05;
        counterThreshold = 0.85; // %85 altı için karşı teklif
        counterIncrease = 0.10 + random.nextDouble() * 0.05; // %10-15 artır
        // 🆕 Zone System
        insultZone = 0.75; // %75 altı hakaret
        negotiationZone = 0.92; // %92 altı müzakere
        fuzzyVariance = 0.02; // %2 sapma
        // 🆕 Patience
        patience = 2 + random.nextInt(2); // 2-3 tur (çabuk sıkılır)
        // 🆕 Reserve Price
        reserveRatio = 0.90 + random.nextDouble() * 0.05; // %90-95 (çok az iner)
        break;
      case SellerType.moderate:
        // Ilımlı (Galerici): En az %85-95 kabul eder
        minRatio = 0.85 + random.nextDouble() * 0.10;
        counterThreshold = 0.75; // %75 altı için karşı teklif
        counterIncrease = 0.07 + random.nextDouble() * 0.05; // %7-12 artır
        // 🆕 Zone System
        insultZone = 0.70; // %70 altı hakaret
        negotiationZone = 0.88; // %88 altı müzakere
        fuzzyVariance = 0.025; // %2.5 sapma
        // 🆕 Patience
        patience = 3 + random.nextInt(2); // 3-4 tur (dengeli sabır)
        // 🆕 Reserve Price
        reserveRatio = 0.85 + random.nextDouble() * 0.08; // %85-93 (dengeli)
        break;
      case SellerType.flexible:
        // Esnek: En az %75-85 kabul eder
        minRatio = 0.75 + random.nextDouble() * 0.10;
        counterThreshold = 0.65; // %65 altı için karşı teklif
        counterIncrease = 0.05 + random.nextDouble() * 0.05; // %5-10 artır
        // 🆕 Zone System
        insultZone = 0.65; // %65 altı hakaret
        negotiationZone = 0.82; // %82 altı müzakere
        fuzzyVariance = 0.03; // %3 sapma
        // 🆕 Patience
        patience = 4 + random.nextInt(2); // 4-5 tur (sabırlı)
        // 🆕 Reserve Price
        reserveRatio = 0.80 + random.nextDouble() * 0.08; // %80-88 (esnek)
        break;
      case SellerType.desperate:
        // Aceleci (Acil Satıcı): En az %65-75 kabul eder
        minRatio = 0.65 + random.nextDouble() * 0.10;
        counterThreshold = 0.50; // %50 altı için karşı teklif
        counterIncrease = 0.03 + random.nextDouble() * 0.05; // %3-8 artır
        // 🆕 Zone System
        insultZone = 0.55; // %55 altı hakaret
        negotiationZone = 0.75; // %75 altı müzakere
        fuzzyVariance = 0.035; // %3.5 sapma (daha tahmin edilemez)
        // 🆕 Patience
        patience = 5 + random.nextInt(2); // 5-6 tur (çok sabırlı)
        // 🆕 Reserve Price
        reserveRatio = 0.70 + random.nextDouble() * 0.12; // %70-82 (çok esnek, acil)
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

  /// Teklifi değerlendir (🆕 ALL SYSTEMS: ZONE + FUZZY + PRICE BANDS + PATIENCE + RESERVE)
  Map<String, dynamic> evaluateOffer({
    required double offerPrice,
    required double listingPrice,
    int currentRounds = 0, // Mevcut pazarlık turu
  }) {
    final random = Random();
    
    // 🆕 RESERVE PRICE: Satıcının kafasındaki gerçek minimum fiyat
    // Kullanıcı ilan fiyatını görür ama bot reserve price'a göre karar verir!
    final reservePrice = listingPrice * reservePriceRatio;
    
    // 🆕 PRICE BAND ADJUSTMENT: Araç fiyatına göre eşikleri ayarla
    // Yüksek fiyatlı araçlarda daha katı ol
    final priceBandMultiplier = _calculatePriceBandMultiplier(listingPrice);
    
    // 🆕 FUZZY LOGIC: Küçük bir rastgele sapma ekle (%2-3)
    // Bu, aynı teklifin her seferinde farklı sonuç verebilmesini sağlar
    final fuzzyFactor = 1.0 + (random.nextDouble() * 2 - 1) * fuzzyLogicVariance;
    
    // 🆕 KRİTİK: Artık teklifin RESERVE PRICE'a olan oranını kullanıyoruz!
    // Böylece aynı fiyatlı araçlar farklı reserve'lere sahipse farklı davranırlar
    final adjustedRatio = (offerPrice / reservePrice) * fuzzyFactor;
    
    // Fiyat bandına göre ayarlanmış eşikler
    final adjustedInsultZone = insultZoneThreshold * priceBandMultiplier;
    final adjustedNegotiationZone = negotiationZoneThreshold + (1.0 - priceBandMultiplier) * 0.05;
    
    // 🆕 PATIENCE CHECK: Sabır tükendi mi?
    final isPatienceExhausted = currentRounds >= maxPatience;
    
    if (isPatienceExhausted) {
      // Sabır tükendi! Artık karşı teklif yok, nihai karar zamanı
      // Eğer teklif minimum kabul edilebilir oranın üstündeyse kabul et, değilse reddet
      if (adjustedRatio >= minAcceptableRatio * 0.90) {
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
      // Fuzzy logic: Bazen yüksek teklifi bile nazlanarak kabul et
      if (adjustedRatio >= 0.95 && random.nextDouble() < 0.15) {
        // %15 ihtimalle "biraz daha artsanız?" diye nazlan
        final finalOffer = offerPrice * 1.02; // %2 daha fazla iste
        return {
          'decision': 'counter',
          'counterAmount': finalOffer,
          'response': _getFinalBargainMessage(finalOffer),
          'zone': 'final_bargain', // Debug için
        };
      }
      
      return {
        'decision': 'accept',
        'response': _getAcceptMessage(),
        'zone': 'accept', // Debug için
      };
    }
  }

  // 🆕 HAKARET BÖLGESÖ MESAJLARI (Sert ve net)
  String _getInsultZoneMessage() {
    final messages = [
      'Dalga mı geçiyorsunuz? Bu araç bu fiyata olmaz!',
      'Kusura bakmayın ama bu fiyat kabul edilemez. Ciddi değilsiniz galiba.',
      'Bu teklif beklentilerimin çok ama çok altında. Hayır.',
      'Piyasayı hiç mi araştırmadınız? Bu fiyat komik kaçıyor.',
      'Üzgünüm ama bu teklifle anlaşamayız. Çok düşük.',
      'Bu fiyata satmam imkansız. Lütfen gerçekçi olun.',
      'Araç değerinin çok altında bir teklif. Maalesef kabul edemem.',
    ];
    return messages[Random().nextInt(messages.length)];
  }
  
  // Eski normal red mesajları (artık kullanılmıyor ama bırakıyorum)
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
  
  // 🆕 SON NAZLANMA MESAJLARI (İyi teklif ama biraz daha istiyor)
  String _getFinalBargainMessage(double finalAmount) {
    final messages = [
      'Teklifiniz iyi ama ${_formatCurrency(finalAmount)} TL olursa hemen anlaşalım.',
      'Bir tık daha artsanız ne dersiniz? ${_formatCurrency(finalAmount)} TL ideal olur.',
      'Neredeyse anlaştık! ${_formatCurrency(finalAmount)} TL\'ye tamam derim.',
      '${_formatCurrency(finalAmount)} TL son teklifim, bu fiyata hemen kapatalım.',
      'Gerçekten satmak istiyorum ama ${_formatCurrency(finalAmount)} TL daha adil olur.',
    ];
    return messages[Random().nextInt(messages.length)];
  }
  
  // 🆕 SABIR TÜKENDİ - KABUL MESAJLARI
  String _getPatienceExhaustedAcceptMessage() {
    final messages = [
      'Tamam, yeterince konuştuk. Bu fiyata anlaşalım artık.',
      'Peki, bu son teklifimi kabul ediyorum. Anlaşalım.',
      'Uzadı bu iş. Bu fiyata tamam, anlaşalım.',
      'Artık daha fazla pazarlık yapmak istemiyorum. Kabul ediyorum.',
      'İyi, bu fiyata razıyım. Hadi bitirelim şu işi.',
    ];
    return messages[Random().nextInt(messages.length)];
  }
  
  // 🆕 SABIR TÜKENDİ - RED MESAJLARI
  String _getPatienceExhaustedRejectMessage() {
    final messages = [
      'Yeterince konuştuk, bu fiyata anlaşamıyoruz. Üzgünüm.',
      'Çok uzattık, bu fiyat benim için uygun değil. Teşekkürler.',
      'Daha fazla pazarlık yapmak istemiyorum. Bu fiyata olmaz.',
      'Artık vazgeçiyorum. Bu fiyata satamam.',
      'Son teklifim buydu. Bu fiyata anlaşamayız, başka alıcılar bekleyeceğim.',
      'Sabrım tükendi açıkçası. Bu fiyata razı olamam. İyi günler.',
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
  // Yüksek fiyatlı araçlarda daha katı eşikler
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
  
  // 🆕 SMART COUNTER OFFER: Mantıklı karşı teklif hesapla
  // Orta yolu bul ama satıcı lehine hafif kayma
  // 🆕 RESERVE PRICE ile çalışır (gerçek hedef fiyat)
  double _calculateSmartCounterOffer({
    required double offerPrice,
    required double listingPrice,
    required double reservePrice, // 🆕 Satıcının gerçek hedefi
    required double sellerBias, // 0.03-0.15 arası (satıcının ısrarı)
    required Random random,
  }) {
    // 1. Orta noktayı bul (teklif ile reserve arasında)
    // Artık listed price'ı orta nokta için kullanmıyoruz!
    final targetMidPoint = (offerPrice + reservePrice) / 2;
    
    // 2. Ancak listed price'dan çok uzaklaşmamalı (gerçekçilik için)
    final maxCounter = listingPrice * 0.98; // İlan fiyatının %98'i max
    final minCounter = reservePrice * 0.95; // Reserve'in %95'i min
    
    // 3. Orta nokta bu aralıkta olmalı
    final midPoint = targetMidPoint.clamp(minCounter, maxCounter);
    
    // 4. Satıcı lehine kayma (bias'a göre)
    // sellerBias yüksekse (strict) daha fazla ısrar eder
    final biasAmount = (reservePrice - offerPrice) * sellerBias * 0.5;
    
    // 5. Karşı teklif = Orta nokta + Bias + Küçük random
    final baseCounterOffer = midPoint + biasAmount;
    
    // 6. Küçük bir randomness ekle (%1-2 arası)
    final randomAdjustment = baseCounterOffer * (random.nextDouble() * 0.02 - 0.01);
    
    final counterOffer = baseCounterOffer + randomAdjustment;
    
    // 7. Mantık kontrolü: Karşı teklif mantıklı aralıkta olmalı
    final clampedCounter = counterOffer.clamp(offerPrice * 1.03, listingPrice * 0.98);
    
    // 8. 1000'e yuvarla (daha gerçekçi görünsün)
    return (clampedCounter / 1000).round() * 1000.0;
  }
}


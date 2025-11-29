import 'dart:math';
import 'package:flutter/foundation.dart';
import '../models/offer_model.dart';
import '../models/ai_buyer_model.dart';
import '../models/user_vehicle_model.dart';
import '../models/user_model.dart';
import '../models/vehicle_model.dart';
import '../models/seller_profile_model.dart';
import 'database_helper.dart';
import 'notification_service.dart';
import 'game_time_service.dart';
import 'xp_service.dart';

/// Teklif servisi - AI alıcılar ve teklif yönetimi
class OfferService {
  static final OfferService _instance = OfferService._internal();
  factory OfferService() => _instance;
  OfferService._internal();

  final DatabaseHelper _db = DatabaseHelper();
  final GameTimeService _gameTime = GameTimeService();
  final XPService _xpService = XPService();

  /// Servisi başlat ve günlük teklif sistemini aktifleştir
  Future<void> initialize() async {
    debugPrint('💼 OfferService initializing...');
    
    // Gün değişim listener'ı ekle
    _gameTime.addDayChangeListener(_onDayChange);
    
    debugPrint('✅ OfferService initialized - Daily offer generation active');
  }

  /// Gün değişiminde otomatik çağrılır
  void _onDayChange(int oldDay, int newDay) {
    debugPrint('💰 Daily offer generation triggered (Day $oldDay → $newDay)');
    _generateDailyOffersAsync();
  }

  /// Günlük teklifleri oluştur (async olarak)
  Future<void> _generateDailyOffersAsync() async {
    try {
      final offersCreated = await generateDailyOffers();
      debugPrint('✅ Daily offers generated: $offersCreated new offers');
    } catch (e) {
      debugPrint('❌ Error generating daily offers: $e');
    }
  }

  /// Servisi temizle
  void dispose() {
    _gameTime.removeDayChangeListener(_onDayChange);
  }

  /// Belirli bir ilan için AI teklifleri oluştur
  Future<int> generateOffersForListing(UserVehicle listing) async {
    try {
      // Adil fiyatı hesapla
      double fairPrice = _calculateFairPrice(listing);
      
      // Bugün kaç alıcı gelecek? (0-5 arası)
      int buyerCount = _calculateDailyBuyerCount(listing);
      
      int offersCreated = 0;
      
      for (int i = 0; i < buyerCount; i++) {
        // Random AI alıcı oluştur
        AIBuyer buyer = AIBuyer.generateRandom();
        
        // Bu alıcı ilgileniyor mu?
        bool interested = buyer.isInterestedIn(
          vehicleBrand: listing.brand,
          listingPrice: listing.listingPrice!,
          fairPrice: fairPrice,
        );
        
        if (interested) {
          // Teklif miktarı hesapla
          double offerPrice = buyer.calculateOffer(
            listingPrice: listing.listingPrice!,
            fairPrice: fairPrice,
          );
          
          // Teklif oluştur
          Offer offer = Offer(
            offerId: 'offer_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(10000)}',
            vehicleId: listing.id, // ✅ UserVehicle'ın ID'sini kullan (listing.vehicleId değil!)
            sellerId: listing.userId,
            buyerId: buyer.buyerId,
            buyerName: buyer.buyerName,
            offerPrice: offerPrice,
            offerDate: DateTime.now(),
            status: OfferStatus.pending,
            message: buyer.message,
            listingPrice: listing.listingPrice!,
            fairPrice: fairPrice,
            expirationDate: DateTime.now().add(const Duration(days: 7)),
            vehicleBrand: listing.brand,
            vehicleModel: listing.model,
            vehicleYear: listing.year,
            vehicleImageUrl: listing.imageUrl ?? '',
          );
          
          // Veritabanına kaydet
          bool success = await _db.addOffer(offer);
          if (success) {
            offersCreated++;
            
            // 🔔 Bildirim gönder
            await NotificationService().sendNewOfferNotification(
              userId: listing.userId,
              offer: offer,
            );
          }
        }
      }
      
      
      return offersCreated;
    } catch (e) {
      
      return 0;
    }
  }

  /// Tüm aktif ilanlar için teklif oluştur (günlük task)
  Future<int> generateDailyOffers() async {
    try {
      
      
      // Süresi dolan teklifleri güncelle
      await _db.expireOldOffers();
      
      // Tüm aktif ilanları getir
      List<UserVehicle> activeListings = await _getAllActiveListings();
      
      int totalOffersCreated = 0;
      
      for (var listing in activeListings) {
        int offersCreated = await generateOffersForListing(listing);
        totalOffersCreated += offersCreated;
        
        // Biraz bekle (spam değil gibi görünsün)
        await Future.delayed(Duration(milliseconds: Random().nextInt(500)));
      }
      
      
      return totalOffersCreated;
    } catch (e) {
      
      return 0;
    }
  }

  /// Teklifi kabul et ve satışı gerçekleştir
  Future<bool> acceptOffer(Offer offer) async {
    try {
      
      
      // 1. Teklifi kabul edildi olarak işaretle
      bool offerUpdated = await _db.updateOfferStatus(offer.offerId, OfferStatus.accepted);
      if (!offerUpdated) {
        
        return false;
      }
      
      // 2. Aracı getir
      UserVehicle? vehicle = await _db.getUserVehicleById(offer.vehicleId);
      if (vehicle == null) {
        
        return false;
      }
      
      // 3. Satıcıyı getir
      Map<String, dynamic>? sellerMap = await _db.getUserById(offer.sellerId);
      if (sellerMap == null) {
        
        return false;
      }
      User seller = User.fromJson(sellerMap);
      
      // 4. Satıcının bakiyesini artır
      seller = seller.copyWith(balance: seller.balance + offer.offerPrice);
      bool balanceUpdated = await _db.updateUser(seller.id, {'balance': seller.balance});
      if (!balanceUpdated) {
        
        // Rollback teklif durumu
        await _db.updateOfferStatus(offer.offerId, OfferStatus.pending);
        return false;
      }
      
      // 5. Aracı satıldı olarak işaretle
      bool vehicleUpdated = await _db.updateUserVehicle(offer.vehicleId, {
        'isSold': true,
        'isListedForSale': false,
        'salePrice': offer.offerPrice,
        'saleDate': DateTime.now().toIso8601String(),
      });
      
      if (!vehicleUpdated) {
        
        // Rollback
        await _db.updateUser(seller.id, {'balance': seller.balance - offer.offerPrice});
        await _db.updateOfferStatus(offer.offerId, OfferStatus.pending);
        return false;
      }
      
      // 6. Diğer teklifleri reddet
      await _db.rejectOtherOffers(offer.vehicleId, offer.offerId);
      
      // 7. 🔔 Satıcıya araç satıldı bildirimi gönder
      await NotificationService().sendVehicleSoldNotification(
        userId: offer.sellerId,
        vehicleName: '${offer.vehicleBrand} ${offer.vehicleModel}',
        salePrice: offer.offerPrice,
      );
      
      // 💎 XP Kazandır (Araç Satışı + Kâr Bonusu)
      final profit = offer.offerPrice - vehicle.purchasePrice;
      await _xpService.onVehicleSale(offer.sellerId, profit);
      
      return true;
    } catch (e) {
      
      return false;
    }
  }

  /// Teklifi reddet
  Future<bool> rejectOffer(Offer offer) async {
    try {
      // Reddedilen teklifleri artık veritabanından sil (güncelleme yerine)
      bool success = await _db.deleteOffer(offer.offerId);
      
      return success;
    } catch (e) {
      debugPrint('❌ Error rejecting offer: $e');
      return false;
    }
  }

  /// Kullanıcı teklif gönderir ve AI satıcı değerlendirir
  Future<Map<String, dynamic>> submitUserOffer({
    required String userId,
    required String userName,
    required Vehicle vehicle,
    required double offerPrice,
    String? message,
  }) async {
    try {
      // AI satıcı profili oluştur
      final sellerProfile = SellerProfile.generateRandom();
      
      // Teklifi değerlendir (ilk tur, currentRounds = 0)
      final evaluation = sellerProfile.evaluateOffer(
        offerPrice: offerPrice,
        listingPrice: vehicle.price,
        currentRounds: 0, // 🆕 İlk teklif
      );
      
      final decision = evaluation['decision'] as String;
      
      // Teklif objesi oluştur
      OfferStatus status;
      double? counterAmount;
      String? sellerResponse;
      
      if (decision == 'accept') {
        status = OfferStatus.accepted;
        sellerResponse = evaluation['response'] as String;
      } else if (decision == 'reject') {
        status = OfferStatus.rejected;
        sellerResponse = evaluation['response'] as String;
      } else {
        // counter
        status = OfferStatus.pending;
        counterAmount = evaluation['counterAmount'] as double?;
        sellerResponse = evaluation['response'] as String;
      }
      
      final offer = Offer(
        offerId: 'user_offer_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(10000)}',
        vehicleId: vehicle.id,
        sellerId: vehicle.sellerId ?? 'ai_seller',
        buyerId: userId,
        buyerName: userName,
        offerPrice: offerPrice,
        offerDate: DateTime.now(),
        status: status,
        message: message,
        listingPrice: vehicle.price,
        fairPrice: vehicle.price * 0.95, // Basit adil fiyat hesabı
        expirationDate: DateTime.now().add(const Duration(days: 7)),
        isUserOffer: true,
        counterOfferAmount: counterAmount,
        sellerResponse: sellerResponse,
        vehicleBrand: vehicle.brand,
        vehicleModel: vehicle.model,
        vehicleYear: vehicle.year,
        vehicleImageUrl: vehicle.imageUrl ?? '',
      );
      
      // Veritabanına kaydet
      bool success = await _db.addOffer(offer);
      
      if (!success) {
        return {'success': false, 'error': 'Veritabanı hatası'};
      }
      
      // Eğer kabul edildiyse satın alma işlemini tamamla
      if (status == OfferStatus.accepted) {
        await _processUserOfferAcceptance(offer, userId);
      }
      
      return {
        'success': true,
        'decision': decision,
        'status': status,
        'response': sellerResponse,
        'counterOffer': counterAmount,
        'offer': offer,
      };
    } catch (e) {
      
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Kullanıcı karşı teklife cevap verir
  Future<Map<String, dynamic>> submitCounterOfferResponse({
    required Offer offer,
    required double newOfferAmount,
  }) async {
    try {
      // 🆕 PATIENCE METER: Tur sayısını artır
      final newRounds = offer.negotiationRounds + 1;
      
      // Satıcının önceki karşı teklifi
      final previousCounterOffer = offer.counterOfferAmount;
      
      // Yeni bir AI satıcı profili oluştur
      final sellerProfile = SellerProfile.generateRandom();
      
      // 🆕 Orijinal ilan fiyatına göre değerlendir (sabır kontrolü ile)
      final evaluation = sellerProfile.evaluateOffer(
        offerPrice: newOfferAmount,
        listingPrice: offer.listingPrice,
        currentRounds: newRounds, // 🆕 Tur sayısını geç
      );
      
      final decision = evaluation['decision'] as String;
      
      // Teklif objesini güncelle
      OfferStatus newStatus;
      double? newCounterAmount;
      String? newSellerResponse;
      
      if (decision == 'accept') {
        newStatus = OfferStatus.accepted;
        newSellerResponse = evaluation['response'] as String;
        
        // Satın alma işlemini tamamla
        await _processUserOfferAcceptance(offer, offer.buyerId);
      } else if (decision == 'reject') {
        newStatus = OfferStatus.rejected;
        newSellerResponse = evaluation['response'] as String;
      } else {
        // counter - yeni karşı teklif
        newStatus = OfferStatus.pending;
        newCounterAmount = evaluation['counterAmount'] as double?;
        
        // ✅ BUGFIX: Satıcının karşı teklifi öncekinden yüksek olamaz
        if (previousCounterOffer != null && newCounterAmount != null) {
          if (newCounterAmount >= previousCounterOffer) {
            // Eğer yeni karşı teklif daha yüksekse, iki seçenek var:
            // 1. Önceki tekliften biraz daha düşük bir teklif ver
            // 2. Reddet
            
            final random = Random();
            final lowerAmount = previousCounterOffer - (previousCounterOffer * (0.02 + random.nextDouble() * 0.03)); // %2-5 daha düşük
            
            // Eğer kullanıcının teklifi satıcının düşebileceği minimum seviyeye yakınsa, kabul et veya reddet
            if (newOfferAmount >= lowerAmount * 0.95) {
              // Kabul et
              newStatus = OfferStatus.accepted;
              newSellerResponse = _generateAcceptanceResponse();
              newCounterAmount = null;
              
              // Satın alma işlemini tamamla
              await _processUserOfferAcceptance(offer, offer.buyerId);
            } else if (lowerAmount > newOfferAmount * 1.1) {
              // Fark hala çok büyük, reddet
              newStatus = OfferStatus.rejected;
              newSellerResponse = _generateRejectionResponse();
              newCounterAmount = null;
            } else {
              // Daha düşük bir karşı teklif ver
              newCounterAmount = lowerAmount;
              newSellerResponse = _generateCounterOfferResponse(lowerAmount);
            }
          }
        }
        
        if (newStatus == OfferStatus.pending && newCounterAmount != null) {
          newSellerResponse = evaluation['response'] as String;
        }
      }
      
      // Offer'ı güncelle
      final updatedOffer = {
        'status': newStatus.index,
        'offerPrice': newOfferAmount, // Kullanıcının son teklifi
        'counterOfferAmount': newCounterAmount,
        'sellerResponse': newSellerResponse,
        'negotiationRounds': newRounds, // 🆕 Tur sayısını güncelle
      };
      
      await _db.updateOffer(offer.offerId, updatedOffer);
      
      return {
        'success': true,
        'decision': decision,
        'status': newStatus,
        'response': newSellerResponse,
        'counterOffer': newCounterAmount,
      };
    } catch (e) {
      
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Satıcı gelen teklife karşı teklif gönderir (AI alıcı değerlendirir)
  Future<Map<String, dynamic>> sendCounterOfferToIncomingOffer({
    required Offer originalOffer,
    required double counterOfferAmount,
    String? sellerMessage,
  }) async {
    try {
      // AI alıcıyı getir/yeniden oluştur
      final aiBuyer = AIBuyer.generateRandom();
      
      // AI alıcının karşı teklifi değerlendirmesi
      final decision = _evaluateCounterOfferByBuyer(
        aiBuyer: aiBuyer,
        originalOfferPrice: originalOffer.offerPrice,
        counterOfferAmount: counterOfferAmount,
        listingPrice: originalOffer.listingPrice,
      );
      
      // Karar tipine göre işle
      OfferStatus newStatus;
      double? newCounterOffer;
      String response;
      
      if (decision['decision'] == 'accept') {
        // AI alıcı karşı teklifi kabul etti - satışı tamamla
        newStatus = OfferStatus.accepted;
        response = decision['response'] as String;
        
        // Satış işlemini gerçekleştir
        await _processIncomingOfferAcceptance(originalOffer, counterOfferAmount);
      } else if (decision['decision'] == 'reject') {
        // AI alıcı reddetti
        newStatus = OfferStatus.rejected;
        response = decision['response'] as String;
      } else {
        // AI alıcı yeni karşı teklif verdi
        newStatus = OfferStatus.pending;
        newCounterOffer = decision['counterAmount'] as double?;
        response = decision['response'] as String;
      }
      
      // Teklifi güncelle
      final updatedOffer = {
        'status': newStatus.index,
        'counterOfferAmount': newCounterOffer ?? counterOfferAmount,
        'sellerResponse': sellerMessage ?? response,
      };
      
      await _db.updateOffer(originalOffer.offerId, updatedOffer);
      
      return {
        'success': true,
        'decision': decision['decision'],
        'status': newStatus,
        'response': response,
        'counterOffer': newCounterOffer,
      };
    } catch (e) {
      
      return {'success': false, 'error': e.toString()};
    }
  }

  /// AI alıcının karşı teklifi değerlendirmesi
  Map<String, dynamic> _evaluateCounterOfferByBuyer({
    required AIBuyer aiBuyer,
    required double originalOfferPrice,
    required double counterOfferAmount,
    required double listingPrice,
  }) {
    final random = Random();
    
    // Karşı teklifin orijinal teklife göre artış yüzdesi
    final increasePercent = ((counterOfferAmount - originalOfferPrice) / originalOfferPrice) * 100;
    
    // Karşı teklifin ilan fiyatına göre oranı
    final priceRatio = counterOfferAmount / listingPrice;
    
    // Alıcının tipine göre agresiflik seviyesi
    final aggressiveness = _getAggressivenessFromBuyerType(aiBuyer.buyerType);
    
    // Karar verme mantığı
    if (priceRatio >= 0.95) {
      // Karşı teklif çok yüksek (%95+ ilan fiyatı) - çoğunlukla reddet
      if (random.nextDouble() < 0.7) {
        return {
          'decision': 'reject',
          'response': _generateRejectionResponse(),
        };
      } else {
        // Kabul et
        return {
          'decision': 'accept',
          'response': _generateAcceptanceResponse(),
        };
      }
    } else if (priceRatio >= 0.85) {
      // İyi bir karşı teklif (%85-95 arası) - çoğunlukla kabul et
      if (random.nextDouble() < 0.6 + (aggressiveness * 0.2)) {
        return {
          'decision': 'accept',
          'response': _generateAcceptanceResponse(),
        };
      } else {
        // Tekrar karşı teklif ver
        final newCounter = (counterOfferAmount + listingPrice) / 2;
        return {
          'decision': 'counter',
          'counterAmount': newCounter,
          'response': _generateCounterOfferResponse(newCounter),
        };
      }
    } else if (priceRatio >= 0.70) {
      // Orta seviye karşı teklif (%70-85 arası) - pazarlık devam eder
      if (random.nextDouble() < 0.4) {
        return {
          'decision': 'accept',
          'response': _generateAcceptanceResponse(),
        };
      } else if (random.nextDouble() < 0.7) {
        // Tekrar karşı teklif ver
        final newCounter = counterOfferAmount + ((listingPrice - counterOfferAmount) * (0.3 + random.nextDouble() * 0.3));
        return {
          'decision': 'counter',
          'counterAmount': newCounter,
          'response': _generateCounterOfferResponse(newCounter),
        };
      } else {
        return {
          'decision': 'reject',
          'response': _generateRejectionResponse(),
        };
      }
    } else {
      // Düşük karşı teklif (%70'in altı) - çoğunlukla reddet
      if (random.nextDouble() < 0.8) {
        return {
          'decision': 'reject',
          'response': _generateRejectionResponse(),
        };
      } else {
        // Son bir deneme karşı teklifi
        final newCounter = counterOfferAmount * 1.15;
        return {
          'decision': 'counter',
          'counterAmount': newCounter,
          'response': _generateCounterOfferResponse(newCounter),
        };
      }
    }
  }

  /// Gelen teklifin kabulünü işle (satıcı bakiyesini artır, aracı sat)
  Future<bool> _processIncomingOfferAcceptance(Offer offer, double finalPrice) async {
    try {
      // Aracı getir (kâr hesabı için)
      final vehicle = await _db.getUserVehicleById(offer.vehicleId);
      if (vehicle == null) return false;
      
      // Satıcıyı getir
      final sellerMap = await _db.getUserById(offer.sellerId);
      if (sellerMap == null) return false;
      
      final seller = User.fromJson(sellerMap);
      
      // Satıcının bakiyesini artır
      await _db.updateUser(seller.id, {'balance': seller.balance + finalPrice});
      
      // Aracı satıldı olarak işaretle
      await _db.updateUserVehicle(offer.vehicleId, {
        'isSold': true,
        'isListedForSale': false,
        'salePrice': finalPrice,
        'saleDate': DateTime.now().toIso8601String(),
      });
      
      // Diğer teklifleri reddet
      await _db.rejectOtherOffers(offer.vehicleId, offer.offerId);
      
      // 🔔 Satıcıya araç satıldı bildirimi gönder
      await NotificationService().sendVehicleSoldNotification(
        userId: offer.sellerId,
        vehicleName: '${offer.vehicleBrand} ${offer.vehicleModel}',
        salePrice: finalPrice,
      );
      
      // 💎 XP Kazandır (Araç Satışı + Kâr Bonusu + Başarılı Pazarlık)
      final profit = finalPrice - vehicle.purchasePrice;
      await _xpService.onVehicleSale(offer.sellerId, profit);
      await _xpService.onCounterOfferSuccess(offer.sellerId);
      
      return true;
    } catch (e) {
      
      return false;
    }
  }

  /// Kabul yanıtı üret
  String _generateAcceptanceResponse() {
    final responses = [
      'Harika! Anlaştık. Bu fiyata razıyım.',
      'Tamam, kabul ediyorum. Anlaşalım.',
      'Olur, bu fiyata tamam.',
      'İyi bir anlaşma. Kabul ediyorum.',
      'Peki, bu fiyata razıyım.',
      'Anlaştık! Kabul.',
    ];
    return responses[Random().nextInt(responses.length)];
  }

  /// Red yanıtı üret
  String _generateRejectionResponse() {
    final responses = [
      'Maalesef bu fiyata razı olamam. Teşekkürler.',
      'Düşündüm ama bu fiyat benim için uygun değil.',
      'Üzgünüm, bu teklife hayır diyorum.',
      'Bu fiyata anlaşamayız sanırım. Teşekkürler.',
      'Maalesef kabul edemem. Başka bir fiyat düşünebilir misiniz?',
      'Bu fiyat beklediğimden düşük. Teşekkürler ama olmaz.',
    ];
    return responses[Random().nextInt(responses.length)];
  }

  /// Karşı teklif yanıtı üret
  String _generateCounterOfferResponse(double counterAmount) {
    final responses = [
      'Hmm, biraz düşündüm. ${_formatCurrency(counterAmount)} TL yapsak?',
      'Bu fiyata zor. ${_formatCurrency(counterAmount)} TL olursa anlaşabiliriz.',
      '${_formatCurrency(counterAmount)} TL\'ye ne dersiniz? Orta bir yol bulalım.',
      'Peki, ${_formatCurrency(counterAmount)} TL son teklifim.',
      'Bir adım atalım. ${_formatCurrency(counterAmount)} TL olsa?',
    ];
    return responses[Random().nextInt(responses.length)];
  }

  /// Para formatı
  String _formatCurrency(double value) {
    return value.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    );
  }

  /// Kullanıcı teklifinin kabulünü işle (araç satın alma)
  Future<bool> _processUserOfferAcceptance(Offer offer, String userId) async {
    try {
      // Kullanıcıyı getir
      final userMap = await _db.getUserById(userId);
      if (userMap == null) return false;
      
      final user = User.fromJson(userMap);
      
      // Bakiye kontrolü
      if (user.balance < offer.offerPrice) {
        // Yetersiz bakiye - teklifi beklemede tut
        await _db.updateOfferStatus(offer.offerId, OfferStatus.pending);
        return false;
      }
      
      // Bakiyeyi düş
      await _db.updateUser(userId, {'balance': user.balance - offer.offerPrice});
      
      // Aracı kullanıcıya ekle
      final userVehicle = UserVehicle.purchase(
        userId: userId,
        vehicleId: offer.vehicleId,
        brand: offer.vehicleBrand,
        model: offer.vehicleModel,
        year: offer.vehicleYear,
        mileage: 50000, // Varsayılan
        purchasePrice: offer.offerPrice,
        color: 'Bilinmiyor',
        fuelType: 'Benzin',
        transmission: 'Manuel',
        engineSize: '1.6',
        driveType: 'Önden',
        hasWarranty: false,
        hasAccidentRecord: false,
        score: 75,
        imageUrl: offer.vehicleImageUrl,
      );
      
      await _db.addUserVehicle(userVehicle);
      
      return true;
    } catch (e) {
      
      return false;
    }
  }

  // ============================================================================
  // HELPER METHODS
  // ============================================================================

  /// Alıcı tipinden agresiflik seviyesi çıkar
  double _getAggressivenessFromBuyerType(BuyerType type) {
    switch (type) {
      case BuyerType.bargainer:
        return 0.8; // Yüksek agresiflik - pazarlığa devam etmeye eğilimli
      case BuyerType.realistic:
        return 0.5; // Orta agresiflik - dengeli yaklaşım
      case BuyerType.urgent:
        return 0.2; // Düşük agresiflik - hızlı kabul etme eğilimi
      case BuyerType.generous:
        return 0.1; // Çok düşük agresiflik - kolayca kabul eder
    }
  }

  /// Adil fiyatı hesapla (skordan)
  double _calculateFairPrice(UserVehicle vehicle) {
    // Skor 100 üzerinden, adil fiyat = satın alma fiyatı * (skor/100)
    double scoreMultiplier = vehicle.score / 100.0;
    
    // Minimum %50, maksimum %100
    scoreMultiplier = scoreMultiplier.clamp(0.5, 1.0);
    
    return vehicle.purchasePrice * scoreMultiplier;
  }

  /// Günlük alıcı sayısını hesapla
  int _calculateDailyBuyerCount(UserVehicle listing) {
    final random = Random();
    
    // Base: 3-8 arası alıcı (daha fazla teklif için artırıldı)
    int baseCount = 3 + random.nextInt(6);
    
    // İndirim varsa artır
    double fairPrice = _calculateFairPrice(listing);
    double priceRatio = listing.listingPrice! / fairPrice;
    
    if (priceRatio < 0.80) {
      // %20+ indirim → +3-5 alıcı
      baseCount += 3 + random.nextInt(3);
    } else if (priceRatio < 0.90) {
      // %10-20 indirim → +2-3 alıcı
      baseCount += 2 + random.nextInt(2);
    } else if (priceRatio < 1.0) {
      // Adil fiyat → +1-2 alıcı
      baseCount += 1 + random.nextInt(2);
    }
    
    // İlan yaşı hesapla (listedDate varsa)
    if (listing.listedDate != null) {
      final daysSinceListed = DateTime.now().difference(listing.listedDate!).inDays;
      
      if (daysSinceListed > 30) {
        baseCount = (baseCount * 0.7).round(); // %30 azalt (daha az cezalandırıcı)
      } else if (daysSinceListed > 14) {
        baseCount = (baseCount * 0.85).round(); // %15 azalt
      }
    }
    
    return baseCount.clamp(2, 15); // Min 2, Max 15 alıcı/gün
  }

  /// Tüm aktif ilanları getir (tüm kullanıcılardan)
  Future<List<UserVehicle>> _getAllActiveListings() async {
    try {
      final allVehicles = await _db.getAllUserVehicles();
      return allVehicles.where((v) => v.isListedForSale && !v.isSold).toList();
    } catch (e) {
      
      return [];
    }
  }
}


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
import 'daily_quest_service.dart';
import '../models/daily_quest_model.dart';
import '../services/skill_service.dart'; // Yetenek Servisi
import 'market_refresh_service.dart'; // Araç detayları için

/// Teklif servisi - AI alıcılar ve teklif yönetimi
class OfferService {
  static final OfferService _instance = OfferService._internal();
  factory OfferService() => _instance;
  OfferService._internal();

  final DatabaseHelper _db = DatabaseHelper();
  final GameTimeService _gameTime = GameTimeService();
  final XPService _xpService = XPService();
  final DailyQuestService _questService = DailyQuestService();

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
      
      // Satıcıyı getir ve yetenek çarpanını uygula
      final sellerMap = await _db.getUserById(listing.userId);
      if (sellerMap != null) {
        final seller = User.fromJson(sellerMap);
        final multiplier = SkillService.getSellingMultiplier(seller);
        // Adil fiyatı artır (AI alıcılar daha yüksek teklif vermeye meyilli olur)
        fairPrice *= multiplier;
      }
      
      // Bugün kaç alıcı gelecek? (0-5 arası)
      // NOT: _calculateDailyBuyerCount artık async ve kullanıcı ID'si alıyor
      int buyerCount = await _calculateDailyBuyerCount(listing);
      
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
      
      // 🎯 Günlük Görev Güncellemesi: Araç Satışı ve Kâr
      await _questService.updateProgress(offer.sellerId, QuestType.sellVehicle, 1);
      if (profit > 0) {
        await _questService.updateProgress(offer.sellerId, QuestType.earnProfit, profit.toInt());
      }
      
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

  /// Kullanıcı AI satıcının karşı teklifini kabul eder
  Future<Map<String, dynamic>> acceptCounterOffer(Offer offer) async {
    try {
      if (offer.counterOfferAmount == null) {
        return {'success': false, 'error': 'Karşı teklif bulunamadı'};
      }

      // Teklifi güncelle: Fiyatı karşı teklif fiyatı yap, durumu accepted yap
      final updatedOffer = offer.copyWith(
        offerPrice: offer.counterOfferAmount!,
        status: OfferStatus.accepted,
      );

      // DB'de güncelle
      await _db.updateOffer(offer.offerId, {
        'offerPrice': updatedOffer.offerPrice,
        'status': OfferStatus.accepted.index,
      });

      // Satın alma işlemini gerçekleştir
      final success = await _processUserOfferAcceptance(updatedOffer, offer.buyerId);

      if (success) {
        return {'success': true};
      } else {
        // Başarısız olursa (örn: bakiye yetersiz), durumu geri al
        await _db.updateOffer(offer.offerId, {
          'offerPrice': offer.offerPrice, // Eski fiyata dön
          'status': OfferStatus.pending.index,
        });
        return {'success': false, 'error': 'Satın alma işlemi başarısız (Bakiye yetersiz olabilir)'};
      }
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
      
      // 🎯 Günlük Görev Güncellemesi: Araç Satışı ve Kâr
      await _questService.updateProgress(offer.sellerId, QuestType.sellVehicle, 1);
      if (profit > 0) {
        await _questService.updateProgress(offer.sellerId, QuestType.earnProfit, profit.toInt());
      }
      
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
      
      // Aracı bulmaya çalış (MarketRefreshService'den)
      final marketService = MarketRefreshService();
      final activeListings = marketService.getActiveListings();
      Vehicle? sourceVehicle;
      
      try {
        sourceVehicle = activeListings.firstWhere((v) => v.id == offer.vehicleId);
      } catch (e) {
        // Araç bulunamadı (süresi dolmuş olabilir)
        sourceVehicle = null;
      }
      
      // Fallback değerler (Eğer araç bulunamazsa)
      final random = Random();
      final colors = ['Beyaz', 'Siyah', 'Gri', 'Kırmızı', 'Mavi', 'Gümüş', 'Kahverengi', 'Yeşil'];
      final fuelTypes = ['Benzin', 'Dizel', 'Hybrid'];
      final transmissions = ['Manuel', 'Otomatik'];
      final engineSizes = ['1.0', '1.2', '1.4', '1.6', '2.0'];
      
      final userVehicle = UserVehicle.purchase(
        userId: userId,
        vehicleId: offer.vehicleId,
        brand: offer.vehicleBrand,
        model: offer.vehicleModel,
        year: offer.vehicleYear,
        mileage: sourceVehicle?.mileage ?? (10000 + random.nextInt(190000)),
        purchasePrice: offer.offerPrice,
        color: sourceVehicle?.color ?? colors[random.nextInt(colors.length)],
        fuelType: sourceVehicle?.fuelType ?? fuelTypes[random.nextInt(fuelTypes.length)],
        transmission: sourceVehicle?.transmission ?? transmissions[random.nextInt(transmissions.length)],
        engineSize: sourceVehicle?.engineSize ?? engineSizes[random.nextInt(engineSizes.length)],
        driveType: sourceVehicle?.driveType ?? 'Önden',
        hasWarranty: sourceVehicle?.hasWarranty ?? false,
        hasAccidentRecord: sourceVehicle?.hasAccidentRecord ?? false,
        score: sourceVehicle?.score ?? 75,
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

  /// Adil fiyatı hesapla (FMV - Fair Market Value)
  double _calculateFairPrice(UserVehicle vehicle) {
    // 1. Baz Değer: Satın alma fiyatı üzerinden bir varyasyon (Piyasa dalgalanması)
    // Gerçek hayatta her zaman aldığımız fiyata satamayız, bazen ucuza almışızdır bazen pahalıya.
    // Bunu simüle etmek için sabit bir hash (ID) kullanarak tutarlı bir "gerçek değer" üretiyoruz.
    final random = Random(vehicle.id.hashCode); 
    final fluctuation = 0.9 + random.nextDouble() * 0.2; // %90 - %110 arası
    
    double baseFMV = vehicle.purchasePrice * fluctuation;
    
    // NOT: Skor etkisi (scoreMultiplier) kaldırıldı çünkü purchasePrice zaten aracın kondisyonunu yansıtıyor.
    // Tekrar skor cezası uygulamak, düşük kondisyonlu araçların asla kârla satılamamasına neden oluyor.
    
    return baseFMV;
  }

  /// Günlük alıcı sayısını hesapla
  Future<int> _calculateDailyBuyerCount(UserVehicle listing) async {
    final random = Random();
    
    // Base: 4-10 arası alıcı (biraz artırıldı)
    int baseCount = 4 + random.nextInt(7);
    
    // Yetenek Kontrolü: Piyasa Kurdu (Market Guru)
    // İlanlar %50 daha fazla görüntülenir -> %50 daha fazla alıcı
    final sellerMap = await _db.getUserById(listing.userId);
    if (sellerMap != null) {
      final seller = User.fromJson(sellerMap);
      if (seller.unlockedSkills.contains('market_guru')) {
        baseCount = (baseCount * 1.5).round();
      }
    }
    
    // İndirim/Bindirim Oranı
    double fairPrice = _calculateFairPrice(listing);
    double priceRatio = listing.listingPrice! / fairPrice;
    
    // --- ALICI TOLERANS EĞRİSİ (BUYER TOLERANCE CURVE) ---
    
    // Maksimum Tolerans Sınırı (Varsayılan: 1.40 -> %40 kâr)
    // Kullanıcı %15 kâr ile satmak istiyor, piyasa dalgalanması (%90) ile birleşince
    // oran 1.15 / 0.9 = 1.27 olabiliyor. 1.30 sınırda kalıyor.
    // Bu yüzden toleransı 1.40'a çekiyoruz.
    double maxTolerance = 1.40;
    
    // Yetenek Etkisi: Ballı Dil (Charisma)
    // Toleransı artırır (Daha pahalıya satabilirsin)
    // Not: Bu kontrolü yukarıda yapmıştık ama burada tolerans için tekrar sellerMap lazım
    // Performans için yukarıdaki sellerMap'i kullanabiliriz ama scope farklı.
    // Şimdilik tekrar çekiyoruz (Hive hızlıdır).
    final sellerMapCheck = await _db.getUserById(listing.userId);
    if (sellerMapCheck != null) {
      final seller = User.fromJson(sellerMapCheck);
      // Ballı Dil yeteneği varsa tolerans artar
      // (Burada basitçe yetenek kontrolü yapıyoruz, detaylı ID kontrolü skill_service'de olmalı ama
      // şimdilik hardcode 'charisma' kontrolü yapıyoruz)
      if (seller.unlockedSkills.any((s) => s.startsWith('charisma'))) {
        maxTolerance = 1.50; // %50 kâra kadar tolerans
      }
    }
    
    if (priceRatio > maxTolerance) {
      // Fiyat çok yüksek! Kimse ilgilenmez.
      debugPrint('🚫 Price too high! Ratio: $priceRatio > Tolerance: $maxTolerance');
      return 0;
    } else if (priceRatio > 1.15) {
      // Biraz pahalı (%15-%30 arası) -> Alıcı sayısı ciddi düşer
      baseCount = (baseCount * 0.3).round(); // %70 azalma
    } else if (priceRatio > 1.05) {
      // Makul kâr (%5-%15) -> Hafif azalma
      baseCount = (baseCount * 0.8).round(); // %20 azalma
    } else if (priceRatio < 0.95) {
      // Kelepir (<%95) -> Alıcı patlaması
      baseCount = (baseCount * 1.5).round();
    }
    
    // En az 0 alıcı
    if (baseCount < 0) baseCount = 0;
    
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


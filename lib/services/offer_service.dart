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
import 'activity_service.dart';
import 'market_refresh_service.dart'; // Araç detayları için
import 'skill_service.dart';
import '../services/localization_service.dart'; // For .tr() extension

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

    
    // Gün değişim listener'ı ekle
    _gameTime.addDayChangeListener(_onDayChange);
    

  }

  /// Gün değişiminde otomatik çağrılır
  void _onDayChange(int oldDay, int newDay) {

    _generateDailyOffersAsync();
  }

  /// Günlük teklifleri oluştur (async olarak)
  Future<void> _generateDailyOffersAsync() async {
    try {
      final offersCreated = await generateDailyOffers();

    } catch (e) {

    }
  }

  /// Servisi temizle
  void dispose() {
    _gameTime.removeDayChangeListener(_onDayChange);
  }

  /// Belirli bir ilan için AI teklifleri oluştur
  Future<int> generateOffersForListing(UserVehicle listing) async {
    try {
      // 🆕 LIMIT KONTROLÜ: Bir araç için maksimum 10 bekleyen teklif olabilir
      final existingOffers = await _db.getOffersByVehicleId(listing.id);
      final now = DateTime.now();
      final pendingCount = existingOffers.where((o) => o.isPending(now)).length;
      
      if (pendingCount >= 10) {

        return 0;
      }

      // Adil fiyatı hesapla
      double fairPrice = _calculateFairPrice(listing);
      
      // Satıcıyı getir ve yetenek çarpanını uygula
      final sellerMap = await _db.getUserById(listing.userId);
      if (sellerMap != null) {
        final seller = User.fromJson(sellerMap);
        var multiplier = 1.0;
        
        // 🆕 GALERİ AVANTAJI: Yüksek Kar Marjı
        // Galeri sahiplerinin araçları %10 daha değerli algılanır
        if (seller.ownsGallery) {
          multiplier = 1.10;
        }
        
        // Adil fiyatı artır (AI alıcılar daha yüksek teklif vermeye meyilli olur)
        fairPrice *= multiplier;
      }
      
      // Bugün kaç alıcı gelecek? (0-5 arası)
      // NOT: _calculateDailyBuyerCount artık async ve kullanıcı ID'si alıyor
      int buyerCount = await _calculateDailyBuyerCount(listing);
      
      // 🆕 STRICT LIMIT: Kalan boş slot sayısına göre buyerCount'u sınırla
      final remainingSlots = 10 - pendingCount;
      if (buyerCount > remainingSlots) {
        buyerCount = remainingSlots;
      }
      
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

            message: buyer.generateContextualMessage(
              mileage: listing.mileage,
              hasAccidentRecord: listing.hasAccidentRecord,
              listingPrice: listing.listingPrice!,
              fairPrice: fairPrice,
            ) ?? buyer.message,
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
            
          }
        }
      }
      
      // 🆕 FORCED OFFER: Eğer hiç teklif oluşmadıysa (fiyat çok yüksek olsa bile)
      // En az bir teklif gelmeli (Zararına da olsa)
      if (offersCreated == 0 && buyerCount > 0) {
        // Zorunlu bir alıcı oluştur
        AIBuyer forcedBuyer = AIBuyer.generateRandom();
        
        // Fiyat kontrolü: İlan fiyatı çok mu yüksek?
        double priceRatio = listing.listingPrice! / fairPrice;
        double offerPrice;
        
        if (priceRatio > 1.3) {
          // Fiyat çok yüksek (Fair Price'ın %30'undan fazla)
          // Alıcı "Fair Price" üzerinden teklif verir (Düşük teklif / Ölücü)
          // Fair Price'ın %80-%100'ü arası
          offerPrice = fairPrice * (0.80 + Random().nextDouble() * 0.20);
        } else {
          // Normal hesaplama
          offerPrice = forcedBuyer.calculateOffer(
            listingPrice: listing.listingPrice!,
            fairPrice: fairPrice,
          );
        }
        
        // Teklif oluştur
        Offer offer = Offer(
          offerId: 'offer_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(10000)}',
          vehicleId: listing.id,
          sellerId: listing.userId,
          buyerId: forcedBuyer.buyerId,
          buyerName: forcedBuyer.buyerName,
          offerPrice: offerPrice,
          offerDate: DateTime.now(),
          status: OfferStatus.pending,
          message: forcedBuyer.generateContextualMessage(
            mileage: listing.mileage,
            hasAccidentRecord: listing.hasAccidentRecord,
            listingPrice: listing.listingPrice!,
            fairPrice: fairPrice,
          ) ?? forcedBuyer.message,
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
        }
      }

      if (offersCreated > 0) {
        await NotificationService().sendBulkOfferNotification(
          userId: listing.userId,
          vehicleId: listing.id,
          vehicleBrand: listing.brand,
          vehicleModel: listing.model,
          offerCount: offersCreated,
        );
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
  Future<XPGainResult?> acceptOffer(Offer offer) async {
    try {
      
      
      // 1. Teklifi kabul edildi olarak işaretle
      bool offerUpdated = await _db.updateOfferStatus(offer.offerId, OfferStatus.accepted);
      if (!offerUpdated) {
        
        return null;
      }
      
      // 2. Satın alma işlemini gerçekleştir (Bakiye güncelleme, araç durumu, diğer teklifleri reddetme)
      // Bu metod içinde bakiye artırılıyor ve araç satıldı olarak işaretleniyor.
      // Ayrıca XP, Quest ve Aktivite güncellemeleri de burada yapılıyor.
      final xpResult = await _processIncomingOfferAcceptance(offer, offer.counterOfferAmount ?? offer.offerPrice);
      
      if (xpResult == null) {
        // Başarısız olursa durumu geri al
        await _db.updateOfferStatus(offer.offerId, OfferStatus.pending);
        return null;
      }

      // 🔔 Alıcıya bildirim gönder
      // Bildirim için doğru fiyatı içeren bir kopya oluştur
      final finalPrice = offer.counterOfferAmount ?? offer.offerPrice;
      final acceptedOffer = offer.copyWith(offerPrice: finalPrice);
      
      await NotificationService().sendOfferAcceptedNotification(
        buyerId: offer.buyerId,
        offer: acceptedOffer,
      );
      
      return xpResult;
    } catch (e) {
      
      return null;
    }
  }

  /// Teklifi reddet
  Future<bool> rejectOffer(Offer offer) async {
    try {
      // Reddedilen teklifleri artık veritabanından sil (güncelleme yerine)
      bool success = await _db.deleteOffer(offer.offerId);
      
      return success;
    } catch (e) {

      return false;
    }
  }



  /// Satıcının karşı teklifini reddet
  Future<bool> rejectCounterOffer(Offer offer) async {
    try {
      // Reddedilen teklifi silmek yerine durumunu güncelle
      // Böylece kullanıcının bu ilanı reddettiğini bilebiliriz
      return await _db.updateOfferStatus(offer.offerId, OfferStatus.rejected);
    } catch (e) {
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
      // 🆕 GARAGE LIMIT CHECK
      final userVehicles = await _db.getUserActiveVehicles(userId);
      final userMapCheck = await _db.getUserById(userId);
      if (userMapCheck != null) {
        final user = User.fromJson(userMapCheck);
        if (userVehicles.length >= user.garageLimit) {
          return {'success': false, 'error': 'Garaj limitiniz dolu (${user.garageLimit} araç). Yeni araç alamazsınız.'};
        }
      }

      // 🆕 REJECTION CHECK: Kullanıcı daha önce bu araç için bir karşı teklifi reddetti mi?
      final existingOffers = await _db.getOffersByVehicleId(vehicle.id);
      final hasRejectedOffer = existingOffers.any((o) => 
        o.buyerId == userId && 
        o.status == OfferStatus.rejected
      );

      if (hasRejectedOffer) {
        return {
          'success': false, 
          'error': 'offer.previouslyRejected'.tr(), // "Bu araç için yapılan karşı teklifi reddettiniz. Tekrar teklif veremezsiniz."
        };
      }

      // AI satıcı profili oluştur (Deterministic seed based on vehicle ID)
      final sellerProfile = SellerProfile.generateRandom(seed: vehicle.id.hashCode);
      
      // Alıcı kullanıcıyı getir (skill kontrolü için)
      final userMap = await _db.getUserById(userId);
      User? buyerUser;
      if (userMap != null) {
        buyerUser = User.fromJson(userMap);
      }

      // Teklifi değerlendir (ilk tur, currentRounds = 0)
      final evaluation = sellerProfile.evaluateOffer(
        offerPrice: offerPrice,
        listingPrice: vehicle.price,
        currentRounds: 0, // 🆕 İlk teklif
        buyerUser: buyerUser,
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
    } catch (e, stackTrace) {
      debugPrint('Error in submitUserOffer: $e');
      debugPrint('Stack trace: $stackTrace');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Teklif kabul edilme olasılığını hesapla
  Future<double> getAcceptanceProbability({
    required Vehicle vehicle,
    required double offerPrice,
    required String userId,
  }) async {
    // AI satıcı profili oluştur (aynı seed ile)
    final sellerProfile = SellerProfile.generateRandom(seed: vehicle.id.hashCode);
    
    // Kullanıcıyı getir (skill kontrolü için)
    final userMap = await _db.getUserById(userId);
    User? buyerUser;
    if (userMap != null) {
      buyerUser = User.fromJson(userMap);
    }
    
    return sellerProfile.calculateAcceptanceChance(
      offerPrice: offerPrice,
      listingPrice: vehicle.price,
      buyerUser: buyerUser,
    );
  }

  /// Kullanıcı karşı teklife cevap verir
  Future<Map<String, dynamic>> submitCounterOfferResponse({
    required Offer offer,
    required double newOfferAmount,
  }) async {
    try {
      // 🆕 GARAGE LIMIT CHECK
      final userVehicles = await _db.getUserActiveVehicles(offer.buyerId);
      final userMapCheck = await _db.getUserById(offer.buyerId);
      if (userMapCheck != null) {
        final user = User.fromJson(userMapCheck);
        if (userVehicles.length >= user.garageLimit) {
          return {'success': false, 'error': 'Garaj limitiniz dolu (${user.garageLimit} araç). Yeni araç alamazsınız.'};
        }
      }

      // 🆕 PATIENCE METER: Tur sayısını artır
      final newRounds = offer.negotiationRounds + 1;
      
      // Satıcının önceki karşı teklifi
      final previousCounterOffer = offer.counterOfferAmount;
      
      // Yeni bir AI satıcı profili oluştur
      final sellerProfile = SellerProfile.generateRandom();
      
      // Alıcı kullanıcıyı getir (skill kontrolü için)
      final userMap = await _db.getUserById(offer.buyerId);
      User? buyerUser;
      if (userMap != null) {
        buyerUser = User.fromJson(userMap);
      }

      // 🆕 Orijinal ilan fiyatına göre değerlendir (sabır kontrolü ile)
      final evaluation = sellerProfile.evaluateOffer(
        offerPrice: newOfferAmount,
        listingPrice: offer.listingPrice,
        currentRounds: newRounds, // 🆕 Tur sayısını geç
        buyerUser: buyerUser,
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
        newSellerResponse = evaluation['response'] as String;
        
        // ✅ BUGFIX: Satıcının karşı teklifi öncekinden yüksek olamaz
        if (previousCounterOffer != null && newCounterAmount != null) {
          if (newCounterAmount! >= previousCounterOffer) {
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
              newStatus = OfferStatus.pending; // Status pending kalmalı
              newCounterAmount = lowerAmount;
              newSellerResponse = _generateCounterOfferResponse(lowerAmount);
            }
          }
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
        'decision': decision, // Orijinal kararı döndür (UI için) - veya yeni kararı? UI result dialogu için yeni karar daha iyi olabilir ama orijinal yapı bozulmasın.
        // UI tarafı result['decision'] kullanıyor. Eğer biz burada decision'ı değiştirdiysek (bugfix bloğunda), UI yanlış gösterebilir.
        // Ancak UI ayrıca result['status'] ve result['response'] da kullanıyor olabilir mi?
        // my_offers_screen.dart: _showCounterOfferResultDialog
        // final decision = result['decision'] as String;
        // final response = result['response'] as String;
        // final newCounterOffer = result['counterOffer'] as double?;
        
        // Eğer bugfix bloğunda kabul ettiysek, decision 'accept' olmalı.
        // O yüzden decision değişkenini de güncellemeliyiz.
        
        'decision': newStatus == OfferStatus.accepted ? 'accept' : (newStatus == OfferStatus.rejected ? 'reject' : 'counter'),
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
      // 🆕 GARAGE LIMIT CHECK
      final userVehicles = await _db.getUserActiveVehicles(offer.buyerId);
      final userMapCheck = await _db.getUserById(offer.buyerId);
      if (userMapCheck != null) {
        final user = User.fromJson(userMapCheck);
        if (userVehicles.length >= user.garageLimit) {
          return {'success': false, 'error': 'Garaj limitiniz dolu (${user.garageLimit} araç). Yeni araç alamazsınız.'};
        }
      }

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
      // AI alıcıyı getir/yeniden oluştur (Deterministic seed based on offer ID)
      final aiBuyer = AIBuyer.generateRandom(seed: originalOffer.offerId.hashCode);
      
      // Tatlı Dil yeteneği bonusunu hesapla
      // Tatlı Dil yeteneği bonusunu hesapla
      double sweetTalkBonus = 0.0;
      User? seller;
      
      final sellerMap = await _db.getUserById(originalOffer.sellerId);
      if (sellerMap != null) {
        seller = User.fromJson(sellerMap);
        final skillService = SkillService();
        final level = skillService.getSkillLevel(seller, SkillService.skillSweetTalk);
        sweetTalkBonus = SkillService.sweetTalkBonuses[level] ?? 0.0;
        
        // 🆕 GALERİ AVANTAJI: Yüksek Kar Marjı
        // Galeri sahiplerinin karşı tekliflerinin kabul edilme şansı %15 artar
        if (seller.ownsGallery) {
          sweetTalkBonus += 0.15;
        }
      }
      
      // AI alıcının karşı teklifi değerlendirmesi
      final decision = await _evaluateCounterOfferByBuyer(
        aiBuyer: aiBuyer,
        originalOfferPrice: originalOffer.offerPrice,
        counterOfferAmount: counterOfferAmount,
        listingPrice: originalOffer.listingPrice,
        successBonus: sweetTalkBonus,
        seller: seller,
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
      } else {
        // AI alıcı reddetti (veya başka bir şey döndü, reddet sayıyoruz)
        newStatus = OfferStatus.rejected;
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
  Future<Map<String, dynamic>> _evaluateCounterOfferByBuyer({
    required AIBuyer aiBuyer,
    required double originalOfferPrice, // AI'nın önceki teklifi
    required double counterOfferAmount, // Kullanıcının istediği fiyat (User's Ask)
    required double listingPrice,
    double successBonus = 0.0,
    User? seller,
  }) async {
    final random = Random();
    
    // Karşı teklifin ilan fiyatına göre oranı
    final priceRatio = counterOfferAmount / listingPrice;
    
    // Alıcının tipine göre agresiflik seviyesi
    final aggressiveness = _getAggressivenessFromBuyerType(aiBuyer.buyerType, seller: seller);
    
    // Karar verme mantığı
    
    // 1. Kullanıcı, AI'nın teklifinden DAHA DÜŞÜK veya EŞİT bir şey istediyse -> DİREKT KABUL
    if (counterOfferAmount <= originalOfferPrice) {
      return {
        'decision': 'accept',
        'response': _generateAcceptanceResponse(),
      };
    }

    // 2. Fiyat Oranına Göre Değerlendirme
    
    // 🆕 YENİ MANTIK: Alıcının ilk teklifi ile satıcının istediği arasındaki uçurum kontrolü
    final initialOfferRatio = originalOfferPrice / listingPrice;
    
    // Eğer satıcı ilana çok yakın bir fiyat istiyorsa (%90 üzeri)
    if (priceRatio >= 0.90) {
      // Ve alıcı düşükten başladıysa (%90 altı)
      if (initialOfferRatio < 0.90) {
        // Kabul etme şansı ÇOK DÜŞÜK olmalı (Mezarcı ölücü tayfa)
        if (random.nextDouble() < 0.1 + successBonus) { // %10 şans
           return {
            'decision': 'accept',
            'response': _generateAcceptanceResponse(),
          };
        } else {
          // Reddet
           return {
            'decision': 'reject',
            'response': _generateRejectionResponse(),
          };
        }
      }
    }

    if (priceRatio >= 0.95) {
      // Kullanıcı hala çok yüksek istiyor (%95+)
      // Kabul etme şansı düşük
      if (random.nextDouble() < 0.3 + successBonus) {
         return {
          'decision': 'accept',
          'response': _generateAcceptanceResponse(),
        };
      } else {
        // Reddet
         return {
          'decision': 'reject',
          'response': _generateRejectionResponse(),
        };
      }
    } else if (priceRatio >= 0.85) {
      // Makul seviye (%85-95)
      // Kabul şansı orta-yüksek
      if (random.nextDouble() < 0.6 + (aggressiveness * 0.2) + successBonus) {
        return {
          'decision': 'accept',
          'response': _generateAcceptanceResponse(),
        };
      } else {
        // Reddet (Artık karşı teklif yok)
        return {
          'decision': 'reject',
          'response': _generateRejectionResponse(),
        };
      }
    } else if (priceRatio >= 0.70) {
      // İyi fiyat (%70-85)
      // Kabul şansı yüksek
      if (random.nextDouble() < 0.8 + successBonus) { // %80 şansla kabul
        return {
          'decision': 'accept',
          'response': _generateAcceptanceResponse(),
        };
      } else {
        // Nadiren reddet
         return {
          'decision': 'reject',
          'response': _generateRejectionResponse(),
        };
      }
    } else {
      // Çok düşük fiyat (%70 altı) - AI havada kapmalı
      return {
        'decision': 'accept',
        'response': _generateAcceptanceResponse(),
      };
    }
  }

  /// Gelen teklifin kabulünü işle (satıcı bakiyesini artır, aracı sat)
  Future<XPGainResult?> _processIncomingOfferAcceptance(Offer offer, double finalPrice) async {
    try {
      // Aracı getir (kâr hesabı için)
      final vehicle = await _db.getUserVehicleById(offer.vehicleId);
      if (vehicle == null) return null;
      
      // Satıcıyı getir
      final sellerMap = await _db.getUserById(offer.sellerId);
      if (sellerMap == null) return null;
      
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
        vehicleName: '${vehicle.brand} ${vehicle.model}',
        salePrice: finalPrice,
      );
      
      // 💎 XP Kazandır (Araç Satışı + Kâr Bonusu + Başarılı Pazarlık)
      final profit = finalPrice - vehicle.purchasePrice;
      final xpResult = await _xpService.onVehicleSale(offer.sellerId, profit);
      await _xpService.onCounterOfferSuccess(offer.sellerId);
      
      // 🎯 Günlük Görev Güncellemesi: Araç Satışı ve Kâr
      await _questService.updateProgress(offer.sellerId, QuestType.sellVehicle, 1);
      if (profit > 0) {
        await _questService.updateProgress(offer.sellerId, QuestType.earnProfit, profit.toInt());
      }

      // Aktivite kaydı
      await ActivityService().logVehicleSale(offer.sellerId, vehicle, finalPrice);
      
      return xpResult;
    } catch (e) {
      
      return null;
    }
  }

  /// Kabul yanıtı üret
  String _generateAcceptanceResponse() {
    final responses = [
      'offerService.responses.acceptance.1',
      'offerService.responses.acceptance.2',
      'offerService.responses.acceptance.3',
      'offerService.responses.acceptance.4',
      'offerService.responses.acceptance.5',
      'offerService.responses.acceptance.6',
    ];
    return responses[Random().nextInt(responses.length)];
  }

  /// Red yanıtı üret
  String _generateRejectionResponse() {
    final responses = [
      'offerService.responses.rejection.1',
      'offerService.responses.rejection.2',
      'offerService.responses.rejection.3',
      'offerService.responses.rejection.4',
      'offerService.responses.rejection.5',
    ];
    return responses[Random().nextInt(responses.length)];
  }

  /// Karşı teklif yanıtı üret
  String _generateCounterOfferResponse(double counterAmount) {
    final responses = [
      'offerService.responses.counter.1',
      'offerService.responses.counter.2',
      'offerService.responses.counter.3',
      'offerService.responses.counter.4',
      'offerService.responses.counter.5',
    ];
    // Not: Parametre (counterAmount) burada kullanılmıyor çünkü çeviri tarafında .trParams ile eklenecek
    // Ancak bu metod sadece key döndürüyor. Bu key'i kullanan yerin .trParams yapması lazım.
    // BU NEDENLE: Bu metodun dönüş değerini kullanan yerleri güncellemeliyim.
    // Şimdilik sadece key döndürelim, kullanan yerleri düzelteceğiz.
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
        bodyType: sourceVehicle?.bodyType ?? 'Sedan',
        horsepower: sourceVehicle?.horsepower ?? 100,
        imageUrl: offer.vehicleImageUrl,
        originalListingPrice: offer.listingPrice, // 🆕 Orijinal ilan fiyatını kaydet
      );
      
      await _db.addUserVehicle(userVehicle);

      // Aktivite kaydı
      await ActivityService().logVehiclePurchase(userId, userVehicle);
      
      return true;
    } catch (e) {
      
      return false;
    }
  }

  // ============================================================================
  // HELPER METHODS
  // ============================================================================

  /// Alıcı tipinden agresiflik seviyesi çıkar
  /// Alıcı tipinden agresiflik seviyesi çıkar
  double _getAggressivenessFromBuyerType(BuyerType type, {User? seller}) {
    double aggressiveness;
    switch (type) {
      case BuyerType.bargainer:
        aggressiveness = 0.8; // Yüksek agresiflik - pazarlığa devam etmeye eğilimli
        break;
      case BuyerType.realistic:
        aggressiveness = 0.5; // Orta agresiflik - dengeli yaklaşım
        break;
      case BuyerType.urgent:
        aggressiveness = 0.2; // Düşük agresiflik - hızlı kabul etme eğilimi
        break;
      case BuyerType.generous:
        aggressiveness = 0.1; // Çok düşük agresiflik - kolayca kabul eder
        break;
    }
    
    // 🆕 GALERİ AVANTAJI: Prestij & İtibar
    // Galeri sahiplerine karşı alıcılar daha az agresif olur (Daha kolay ikna olurlar)
    if (seller != null && seller.ownsGallery) {
      aggressiveness = (aggressiveness - 0.2).clamp(0.0, 1.0);
    }
    
    return aggressiveness;
  }

  /// Adil fiyatı hesapla (FMV - Fair Market Value)
  double _calculateFairPrice(UserVehicle vehicle) {
    // 1. Baz Değer: Satın alma fiyatı üzerinden bir varyasyon (Piyasa dalgalanması)
    // Gerçek hayatta her zaman aldığımız fiyata satamayız, bazen ucuza almışızdır bazen pahalıya.
    // Bunu simüle etmek için sabit bir hash (ID) kullanarak tutarlı bir "gerçek değer" üretiyoruz.
    final random = Random(vehicle.id.hashCode); 
    final fluctuation = 0.9 + random.nextDouble() * 0.2; // %90 - %110 arası
    
    double baseFMV = vehicle.purchasePrice * fluctuation;
    
    // SKOR ETKİSİ: Yüksek skorlu (F/P) araçlar daha değerlidir
    // Score 50 (nötr) -> 1.0x
    // Score 100 (mükemmel) -> 1.25x
    // Score 0 (kötü) -> 0.75x
    double scoreMultiplier = 1.0 + ((vehicle.score - 50) / 200.0);
    
    // Çarpanı sınırla (0.8x - 1.3x arası)
    scoreMultiplier = scoreMultiplier.clamp(0.8, 1.3);
    
    return baseFMV * scoreMultiplier;
  }

  /// Günlük alıcı sayısını hesapla
  Future<int> _calculateDailyBuyerCount(UserVehicle listing) async {
    final random = Random();
    
    // Base: 4-10 arası alıcı (biraz artırıldı)
    int baseCount = 4 + random.nextInt(7);
    
    // SKOR ETKİSİ: Yüksek skorlu araçlar daha çok ilgi çeker
    if (listing.score > 60) {
      // Her 10 puan için +1 alıcı (max +4)
      int bonusBuyers = ((listing.score - 60) / 10).floor();
      baseCount += bonusBuyers;

    }
    
    // Yetenek Kontrolü: Hızlı Satıcı (Quick Flipper)
    // İlanlara daha hızlı teklif gelir -> Daha fazla günlük alıcı
    final sellerMap = await _db.getUserById(listing.userId);
    if (sellerMap != null) {
      final seller = User.fromJson(sellerMap);
      
      // Hız çarpanını al (örn: 0.85 -> %15 daha hızlı)
      final speedMultiplier = 1.0;
      
      if (speedMultiplier < 1.0) {
        // Hız arttıkça (çarpan düştükçe) alıcı sayısı artmalı
        // Örn: 0.85 çarpanı -> 1 / 0.85 = 1.17 kat alıcı
        baseCount = (baseCount / speedMultiplier).round();
      }
      
      // 🆕 GALERİ AVANTAJI: Prestij & İtibar
      // Galeri sahipleri daha fazla müşteri çeker (%50 artış)
      if (seller.ownsGallery) {
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
    double maxTolerance = 2.00;
    
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

    }
    
    if (priceRatio > maxTolerance) {
      // Fiyat çok yüksek! Normalde kimse ilgilenmez.
      // AMA: Oyunun tıkanmaması için en az 1 "ölücü" alıcı gelmeli.
      return 1;
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


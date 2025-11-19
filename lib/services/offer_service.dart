import 'dart:math';
import '../models/offer_model.dart';
import '../models/ai_buyer_model.dart';
import '../models/user_vehicle_model.dart';
import '../models/user_model.dart';
import '../models/vehicle_model.dart';
import '../models/seller_profile_model.dart';
import 'database_helper.dart';
import 'notification_service.dart';

/// Teklif servisi - AI alıcılar ve teklif yönetimi
class OfferService {
  final DatabaseHelper _db = DatabaseHelper();

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
      
      
      
      
      
      return true;
    } catch (e) {
      
      return false;
    }
  }

  /// Teklifi reddet
  Future<bool> rejectOffer(Offer offer) async {
    try {
      
      
      bool success = await _db.updateOfferStatus(offer.offerId, OfferStatus.rejected);
      
      if (success) {
        
      }
      
      return success;
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
      // AI satıcı profili oluştur
      final sellerProfile = SellerProfile.generateRandom();
      
      // Teklifi değerlendir
      final evaluation = sellerProfile.evaluateOffer(
        offerPrice: offerPrice,
        listingPrice: vehicle.price,
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
      // Yeni bir AI satıcı profili oluştur
      final sellerProfile = SellerProfile.generateRandom();
      
      // Orijinal ilan fiyatına göre değerlendir
      final evaluation = sellerProfile.evaluateOffer(
        offerPrice: newOfferAmount,
        listingPrice: offer.listingPrice,
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
      }
      
      // Offer'ı güncelle
      final updatedOffer = {
        'status': newStatus.index,
        'offerPrice': newOfferAmount, // Kullanıcının son teklifi
        'counterOfferAmount': newCounterAmount,
        'sellerResponse': newSellerResponse,
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


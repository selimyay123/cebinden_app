import 'dart:math';
import '../models/offer_model.dart';
import '../models/ai_buyer_model.dart';
import '../models/user_vehicle_model.dart';
import '../models/user_model.dart';
import '../models/vehicle_model.dart';
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
      
      print('✅ $offersCreated offers created for ${listing.brand} ${listing.model}');
      return offersCreated;
    } catch (e) {
      print('❌ Error generating offers: $e');
      return 0;
    }
  }

  /// Tüm aktif ilanlar için teklif oluştur (günlük task)
  Future<int> generateDailyOffers() async {
    try {
      print('🤖 Starting daily offer generation...');
      
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
      
      print('✅ Daily offer generation complete. Total offers: $totalOffersCreated');
      return totalOffersCreated;
    } catch (e) {
      print('❌ Error in daily offer generation: $e');
      return 0;
    }
  }

  /// Teklifi kabul et ve satışı gerçekleştir
  Future<bool> acceptOffer(Offer offer) async {
    try {
      print('💰 Accepting offer: ${offer.offerId}');
      
      // 1. Teklifi kabul edildi olarak işaretle
      bool offerUpdated = await _db.updateOfferStatus(offer.offerId, OfferStatus.accepted);
      if (!offerUpdated) {
        print('❌ Failed to update offer status');
        return false;
      }
      
      // 2. Aracı getir
      UserVehicle? vehicle = await _db.getUserVehicleById(offer.vehicleId);
      if (vehicle == null) {
        print('❌ Vehicle not found: ${offer.vehicleId}');
        return false;
      }
      
      // 3. Satıcıyı getir
      Map<String, dynamic>? sellerMap = await _db.getUserById(offer.sellerId);
      if (sellerMap == null) {
        print('❌ Seller not found: ${offer.sellerId}');
        return false;
      }
      User seller = User.fromJson(sellerMap);
      
      // 4. Satıcının bakiyesini artır
      seller = seller.copyWith(balance: seller.balance + offer.offerPrice);
      bool balanceUpdated = await _db.updateUser(seller.id, {'balance': seller.balance});
      if (!balanceUpdated) {
        print('❌ Failed to update seller balance');
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
        print('❌ Failed to update vehicle');
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
      
      print('✅ Offer accepted successfully!');
      print('   Seller balance: +${offer.offerPrice} TL');
      print('   Vehicle sold: ${offer.vehicleBrand} ${offer.vehicleModel}');
      
      return true;
    } catch (e) {
      print('❌ Error accepting offer: $e');
      return false;
    }
  }

  /// Teklifi reddet
  Future<bool> rejectOffer(Offer offer) async {
    try {
      print('❌ Rejecting offer: ${offer.offerId}');
      
      bool success = await _db.updateOfferStatus(offer.offerId, OfferStatus.rejected);
      
      if (success) {
        print('✅ Offer rejected successfully');
      }
      
      return success;
    } catch (e) {
      print('❌ Error rejecting offer: $e');
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
      print('❌ Error getting active listings: $e');
      return [];
    }
  }
}


import 'dart:math';
import 'package:flutter/foundation.dart';
import '../models/notification_model.dart';
import '../models/offer_model.dart';
import 'database_helper.dart';
import 'localization_service.dart';
import 'settings_helper.dart';

/// Bildirim yönetim servisi
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final DatabaseHelper _db = DatabaseHelper();
  final LocalizationService _localization = LocalizationService();

  /// Yeni teklif bildirimi gönder
  Future<void> sendNewOfferNotification({
    required String userId,
    required Offer offer,
  }) async {
    try {
      // Bildirim ayarını kontrol et
      final settings = await SettingsHelper.getInstance();
      final isEnabled = await settings.getNotificationOffers();
      
      if (!isEnabled) {
        
        return;
      }

      // Bildirim oluştur
      final notification = AppNotification(
        id: 'notif_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(10000)}',
        userId: userId,
        type: NotificationType.newOffer,
        title: 'notifications.newOffer.title'.tr(),
        message: 'notifications.newOffer.message'.trParams({
          'buyer': offer.buyerName,
          'vehicle': '${offer.vehicleBrand} ${offer.vehicleModel}',
          'price': offer.offerPrice.toStringAsFixed(0),
        }),
        createdAt: DateTime.now(),
        data: {
          'offerId': offer.offerId,
          'vehicleId': offer.vehicleId,
          'buyerName': offer.buyerName,
          'offerPrice': offer.offerPrice,
        },
      );

      // Veritabanına kaydet
      await _db.addNotification(notification);
      
    } catch (e) {
      
    }
  }

  /// Teklif kabul edildi bildirimi
  Future<void> sendOfferAcceptedNotification({
    required String buyerId,
    required Offer offer,
  }) async {
    try {
      final settings = await SettingsHelper.getInstance();
      final isEnabled = await settings.getNotificationOffers();
      
      if (!isEnabled) return;

      final notification = AppNotification(
        id: 'notif_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(10000)}',
        userId: buyerId,
        type: NotificationType.offerAccepted,
        title: 'notifications.offerAccepted.title'.tr(),
        message: 'notifications.offerAccepted.message'.trParams({
          'vehicle': '${offer.vehicleBrand} ${offer.vehicleModel}',
          'price': offer.offerPrice.toStringAsFixed(0),
        }),
        createdAt: DateTime.now(),
        data: {
          'offerId': offer.offerId,
          'vehicleId': offer.vehicleId,
        },
      );

      await _db.addNotification(notification);
      
    } catch (e) {
      
    }
  }

  /// Araç satıldı bildirimi
  Future<void> sendVehicleSoldNotification({
    required String userId,
    required String vehicleName,
    required double salePrice,
  }) async {
    try {
      final settings = await SettingsHelper.getInstance();
      final isEnabled = await settings.getNotificationSystem();
      
      if (!isEnabled) return;

      final notification = AppNotification(
        id: 'notif_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(10000)}',
        userId: userId,
        type: NotificationType.vehicleSold,
        title: 'notifications.vehicleSold.title'.tr(),
        message: 'notifications.vehicleSold.message'.trParams({
          'vehicle': vehicleName,
          'price': salePrice.toStringAsFixed(0),
        }),
        createdAt: DateTime.now(),
      );

      await _db.addNotification(notification);
      
    } catch (e) {
      
    }
  }

  /// Kullanıcının tüm bildirimlerini getir
  Future<List<AppNotification>> getUserNotifications(String userId) async {
    return await _db.getUserNotifications(userId);
  }

  /// Okunmamış bildirim sayısı
  Future<int> getUnreadCount(String userId) async {
    return await _db.getUnreadNotificationCount(userId);
  }

  /// Bildirimi okundu işaretle
  Future<void> markAsRead(String notificationId) async {
    await _db.markNotificationAsRead(notificationId);
  }

  /// Tüm bildirimleri okundu işaretle
  Future<void> markAllAsRead(String userId) async {
    await _db.markAllNotificationsAsRead(userId);
  }

  /// Bildirimi sil
  Future<void> deleteNotification(String notificationId) async {
    await _db.deleteNotification(notificationId);
  }

  /// Tüm bildirimleri sil
  Future<void> deleteAllNotifications(String userId) async {
    await _db.deleteAllNotifications(userId);
  }

  /// 24 saatlik bildirim sıfırlama kontrolü
  /// Eğer son sıfırlamadan 24 saat geçtiyse bildirimleri sıfırla
  Future<void> checkAndResetDailyNotifications(String userId) async {
    try {
      // Son sıfırlama zamanını al
      final lastReset = await SettingsHelper.getLastNotificationReset();
      final now = DateTime.now();
      
      // İlk kullanım veya 24 saat geçmiş mi kontrol et
      if (lastReset == null || now.difference(lastReset).inHours >= 24) {
        // Bildirimleri sıfırla
        await deleteAllNotifications(userId);
        
        // Son sıfırlama zamanını güncelle
        await SettingsHelper.setLastNotificationReset(now);
        
        debugPrint('✅ Bildirimler 24 saatlik süreden sonra sıfırlandı.');
      } else {
        final hoursRemaining = 24 - now.difference(lastReset).inHours;
        debugPrint('ℹ️ Bildirimler sıfırlanmadı. Kalan süre: $hoursRemaining saat');
      }
    } catch (e) {
      debugPrint('❌ Bildirim sıfırlama kontrolü başarısız: $e');
    }
  }
}


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
          'price': offer.offerPrice.toString(),
        }),
        createdAt: DateTime.now(),
        data: {
          'offerId': offer.offerId,
          'vehicleId': offer.vehicleId,
          'offerPrice': offer.offerPrice,
        },
        // 🆕 Dynamic Localization
        titleKey: 'notifications.newOffer.title',
        messageKey: 'notifications.newOffer.message',
        params: {
          'buyer': offer.buyerName,
          'vehicle': '${offer.vehicleBrand} ${offer.vehicleModel}',
          'price': offer.offerPrice.toString(),
        },
      );

      // Veritabanına kaydet
      await _db.addNotification(notification);
      
    } catch (e) {
      
    }
  }
  
  /// Toplu teklif bildirimi gönder
  Future<void> sendBulkOfferNotification({
    required String userId,
    required String vehicleId,
    required String vehicleBrand,
    required String vehicleModel,
    required int offerCount,
  }) async {
    try {
      // Bildirim ayarını kontrol et
      final settings = await SettingsHelper.getInstance();
      final isEnabled = await settings.getNotificationOffers();
      
      if (!isEnabled) return;

      // Bildirim oluştur
      final notification = AppNotification(
        id: 'notif_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(10000)}',
        userId: userId,
        type: NotificationType.newOffer, // İkon için newOffer kullanıyoruz
        title: 'notifications.bulkOffer.title'.tr(),
        message: 'notifications.bulkOffer.message'.trParams({
          'brand': vehicleBrand,
          'model': vehicleModel,
          'count': offerCount.toString(),
        }),
        createdAt: DateTime.now(),
        data: {
          'vehicleId': vehicleId,
          'brand': vehicleBrand,
          'model': vehicleModel,
          'offerCount': offerCount,
          'isBulk': true,
        },
        // 🆕 Dynamic Localization
        titleKey: 'notifications.bulkOffer.title',
        messageKey: 'notifications.bulkOffer.message',
        params: {
          'brand': vehicleBrand,
          'model': vehicleModel,
          'count': offerCount.toString(),
        },
      );

      // Veritabanına kaydet
      await _db.addNotification(notification);
      
    } catch (e) {
      debugPrint('Error sending bulk notification: $e');
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
          'price': offer.offerPrice.toString(),
        }),
        createdAt: DateTime.now(),
        data: {
          'offerId': offer.offerId,
          'vehicleId': offer.vehicleId,
        },
        // 🆕 Dynamic Localization
        titleKey: 'notifications.offerAccepted.title',
        messageKey: 'notifications.offerAccepted.message',
        params: {
          'vehicle': '${offer.vehicleBrand} ${offer.vehicleModel}',
          'price': offer.offerPrice.toString(),
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
          'price': salePrice.toString(),
        }),
        createdAt: DateTime.now(),
        data: {
          // Assuming vehicleId might be needed, but not provided in params.
          // If vehicleId is available, it should be added here.
          // For now, keeping it consistent with the provided snippet's data structure.
          // 'vehicleId': vehicleId, // If vehicleId is passed to the function
          'price': salePrice,
        },
        // 🆕 Dynamic Localization
        titleKey: 'notifications.vehicleSold.title',
        messageKey: 'notifications.vehicleSold.message',
        params: {
          'vehicle': vehicleName,
          'price': salePrice.toString(),
        },
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
        

      } else {
        final hoursRemaining = 24 - now.difference(lastReset).inHours;

      }
    } catch (e) {

    }
  }
}


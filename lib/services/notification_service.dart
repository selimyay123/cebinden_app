import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
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
  // ignore: unused_field
  final LocalizationService _localization = LocalizationService();

  // Plugin tanımları
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

  /// Servis başlatma ve kurulum
  Future<void> initialize() async {
    if (_isInitialized) return;

    // Timezone'u başlat
    tz.initializeTimeZones();

    // 1. İzin İste
    await _requestPermissions();

    // 2. Yerel Bildirim Ayarları
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/launcher_icon');

    const DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        );

    const InitializationSettings initializationSettings =
        InitializationSettings(
          android: initializationSettingsAndroid,
          iOS: initializationSettingsDarwin,
        );

    await _localNotifications.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        debugPrint('Notification clicked: ${response.payload}');
        // Buraya bildirime tıklanma mantığı eklenebilir
      },
    );

    // 3. Android Kanalı Oluştur (Önemli)
    final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
        _localNotifications
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();

    if (androidImplementation != null) {
      await androidImplementation.createNotificationChannel(
        const AndroidNotificationChannel(
          'high_importance_channel', // id
          'High Importance Notifications', // name
          description: 'This channel is used for important notifications.',
          importance: Importance.high,
        ),
      );
    }

    // 4. Ön Planda Gelen Firebase Mesajlarını Yerel Olarak Göster
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      RemoteNotification? notification = message.notification;
      AndroidNotification? android = message.notification?.android;

      if (notification != null && android != null) {
        _localNotifications.show(
          id: notification.hashCode,
          title: notification.title,
          body: notification.body,
          notificationDetails: NotificationDetails(
            android: AndroidNotificationDetails(
              'high_importance_channel',
              'High Importance Notifications',
              icon: '@mipmap/launcher_icon',
            ),
          ),
        );
      }
    });

    // 5. FCM Token'ı al
    try {
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        String? apnsToken = await _firebaseMessaging.getAPNSToken();
        if (apnsToken == null) {
          debugPrint("⚠️ APNS Token henüz hazır değil, bekleniyor...");
          await Future.delayed(const Duration(seconds: 3));
          apnsToken = await _firebaseMessaging.getAPNSToken();
        }
        debugPrint("🍏 APNS Token: $apnsToken");
      }

      String? token = await _firebaseMessaging.getToken();

      if (token != null) {
        debugPrint("🔥 FCM Token: $token");
      } else {
        debugPrint("⚠️ FCM Token alınamadı (null geldi)");
      }
    } catch (e) {
      debugPrint("Error getting FCM token: $e");
      if (e.toString().contains('apns-token-not-set')) {
        debugPrint(
          "💡 İPUCU: iOS Simülatörde Push Notification 'tam' çalışmayabilir. Gerçek cihazda veya Apple Developer hesabıyla imzalanmış bir buildde deneyin.",
        );
      }
    }

    // 6. Günlük Bildirimi Planla (Her seferinde tekrar günceller)
    await scheduleDailyNotification();

    _isInitialized = true;
  }

  /// Günlük Hatırlatıcı Planla (Her gün 10:00 AM)
  Future<void> scheduleDailyNotification() async {
    try {
      final now = tz.TZDateTime.now(tz.local);
      var scheduledDate = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day,
        10, // 10:00 AM
        0,
      );

      // Eğer bugünün saati geçtiyse yarına planla
      if (scheduledDate.isBefore(now)) {
        scheduledDate = scheduledDate.add(const Duration(days: 1));
      }

      await _localNotifications.zonedSchedule(
        id: 888,
        title: 'Dükkanı Açma Vakti! 🔑',
        body:
            'Patron, günlük görevler yenilendi. Müşteriler seni bekliyor, gel ve kasanı doldur! 💸',
        scheduledDate: scheduledDate,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'daily_reminders',
            'Daily Reminders',
            channelDescription: 'Daily reminders for game tasks',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        matchDateTimeComponents: DateTimeComponents.time,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );

      debugPrint("📅 Günlük bildirim planlandı: $scheduledDate");
    } catch (e) {
      debugPrint("Error scheduling daily notification: $e");
    }
  }

  Future<void> _requestPermissions() async {
    // iOS için
    NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    debugPrint('User granted permission: ${settings.authorizationStatus}');

    // Android 13+ için local notification izni gerekebilir (plugin hallediyor genellikle ama manuel de istenebilir)
  }

  /// Basit yerel bildirim göster (Anlık)
  Future<void> showLocalNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'game_updates',
          'Game Updates',
          importance: Importance.max,
          priority: Priority.high,
        );

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(),
    );

    await _localNotifications.show(
      id: Random().nextInt(100000),
      title: title,
      body: body,
      notificationDetails: details,
      payload: payload,
    );
  }

  /// Yeni teklif bildirimi gönder
  Future<void> sendNewOfferNotification({
    required String userId,
    required Offer offer,
  }) async {
    try {
      final settings = await SettingsHelper.getInstance();
      final isEnabled = await settings.getNotificationOffers();

      if (!isEnabled) return;

      // 1. Veritabanına Kaydet (Mevcut Mantık)
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
        titleKey: 'notifications.newOffer.title',
        messageKey: 'notifications.newOffer.message',
        params: {
          'buyer': offer.buyerName,
          'vehicle': '${offer.vehicleBrand} ${offer.vehicleModel}',
          'price': offer.offerPrice.toString(),
        },
      );

      await _db.addNotification(notification);

      // Gerçek Bildirim Göster (Kaldırıldı - İstek üzerine)
      /*
      await showLocalNotification(
        title: notification.title,
        body: notification.message,
        payload: notification.id,
      );
      */
    } catch (e) {
      debugPrint('Error sending new offer notification: $e');
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
      final settings = await SettingsHelper.getInstance();
      final isEnabled = await settings.getNotificationOffers();

      if (!isEnabled) return;

      // ... (Mevcut mantık: Önce bu araç için okunmamış bir "newOffer" bildirimi var mı?)
      // Not: Bu karmaşık mantığı koruyoruz ama üzerine local notification ekliyoruz.

      final existingNotifications = await getUserNotifications(userId);
      final existingNotification = existingNotifications.firstWhere(
        (n) =>
            !n.isRead &&
            n.type == NotificationType.newOffer &&
            n.data != null &&
            n.data!['vehicleId'] == vehicleId,
        orElse: () => AppNotification(
          id: '',
          userId: '',
          type: NotificationType.system,
          title: '',
          message: '',
          createdAt: DateTime.now(),
        ),
      );

      String title;
      String message;

      if (existingNotification.id.isNotEmpty) {
        // Mevcut bildirimi güncelle
        final currentCount = existingNotification.data?['offerCount'] ?? 0;
        final newTotalCount =
            (currentCount is int
                ? currentCount
                : int.tryParse(currentCount.toString()) ?? 0) +
            offerCount;

        title = 'notifications.bulkOffer.title'
            .tr(); // Genelde başlık aynı kalır veya güncellenir
        message = 'notifications.bulkOffer.message'.trParams({
          'brand': vehicleBrand,
          'model': vehicleModel,
          'count': newTotalCount.toString(),
        });

        await _db.updateNotification(existingNotification.id, {
          'message': message,
          'createdAt': DateTime.now().toIso8601String(),
          'data': {...existingNotification.data!, 'offerCount': newTotalCount},
          'params': {
            'brand': vehicleBrand,
            'model': vehicleModel,
            'count': newTotalCount.toString(),
          },
        });
      } else {
        // Yeni bildirim oluştur
        title = 'notifications.bulkOffer.title'.tr();
        message = 'notifications.bulkOffer.message'.trParams({
          'brand': vehicleBrand,
          'model': vehicleModel,
          'count': offerCount.toString(),
        });

        final notification = AppNotification(
          id: 'notif_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(10000)}',
          userId: userId,
          type: NotificationType.newOffer,
          title: title,
          message: message,
          createdAt: DateTime.now(),
          data: {
            'vehicleId': vehicleId,
            'brand': vehicleBrand,
            'model': vehicleModel,
            'offerCount': offerCount,
            'isBulk': true,
          },
          titleKey: 'notifications.bulkOffer.title',
          messageKey: 'notifications.bulkOffer.message',
          params: {
            'brand': vehicleBrand,
            'model': vehicleModel,
            'count': offerCount.toString(),
          },
        );

        await _db.addNotification(notification);
      }

      // Local Notification Göster (Kaldırıldı - İstek üzerine)
      // await showLocalNotification(title: title, body: message);
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
        data: {'offerId': offer.offerId, 'vehicleId': offer.vehicleId},
        titleKey: 'notifications.offerAccepted.title',
        messageKey: 'notifications.offerAccepted.message',
        params: {
          'vehicle': '${offer.vehicleBrand} ${offer.vehicleModel}',
          'price': offer.offerPrice.toString(),
        },
      );

      await _db.addNotification(notification);

      // Local Notification (Kaldırıldı - İstek üzerine)
      /*
      await showLocalNotification(
        title: notification.title,
        body: notification.message,
      );
      */
    } catch (e) {
      debugPrint('Error sending offer accepted notification: $e');
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
        data: {'price': salePrice},
        titleKey: 'notifications.vehicleSold.title',
        messageKey: 'notifications.vehicleSold.message',
        params: {'vehicle': vehicleName, 'price': salePrice.toString()},
      );

      await _db.addNotification(notification);

      // Local Notification (Kaldırıldı - İstek üzerine)
      /*
      await showLocalNotification(
        title: notification.title,
        body: notification.message,
      );
      */
    } catch (e) {
      debugPrint('Error sending vehicle sold notification: $e');
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

  /// Belirli bir araca ait bildirimleri sil
  Future<void> deleteNotificationsForVehicle(String vehicleId) async {
    await _db.deleteNotificationsByVehicleId(vehicleId);
  }

  /// 24 saatlik bildirim sıfırlama kontrolü
  Future<void> checkAndResetDailyNotifications(String userId) async {
    try {
      final lastReset = await SettingsHelper.getLastNotificationReset();
      final now = DateTime.now();

      if (lastReset == null || now.difference(lastReset).inHours >= 24) {
        await deleteAllNotifications(userId);
        await SettingsHelper.setLastNotificationReset(now);
      }
    } catch (e) {
      debugPrint('Error resetting notifications: $e');
    }
  }
}

import 'package:hive_flutter/hive_flutter.dart';
import '../models/user_model.dart';
import '../models/user_vehicle_model.dart';
import '../models/offer_model.dart';
import '../models/notification_model.dart';
import '../models/activity_model.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  // Box isimleri
  static const String usersBox = 'users';
  static const String currentUserBox = 'current_user';
  static const String userVehiclesBox = 'user_vehicles'; // Kullanıcıların araçları
  static const String offersBox = 'offers'; // Teklifler
  static const String notificationsBox = 'notifications'; // Bildirimler
  static const String favoritesBox = 'favorites'; // Favori ilanlar

  // Initialize Hive
  static Future<void> init() async {
    await Hive.initFlutter();
    
    // Boxları aç
    final usersBoxInstance = await Hive.openBox<Map>(usersBox);
    final currentUserBoxInstance = await Hive.openBox<String>(currentUserBox);
    final userVehiclesBoxInstance = await Hive.openBox<Map>(userVehiclesBox);
    final offersBoxInstance = await Hive.openBox<Map>(offersBox);
    final notificationsBoxInstance = await Hive.openBox<Map>(notificationsBox);
    final favoritesBoxInstance = await Hive.openBox<Map>(favoritesBox);
    final dailyQuestsBoxInstance = await Hive.openBox<Map>(dailyQuestsBox);
    final activitiesBoxInstance = await Hive.openBox<Map>(activitiesBox);
    
                
    // Debug: Tüm kullanıcıları listele
    if (usersBoxInstance.isNotEmpty) {
            for (var entry in usersBoxInstance.toMap().entries) {
              }
    } else {
          }
  }

  // Users box'ını al
  Box<Map> get _usersBox => Hive.box<Map>(usersBox);
  
  // Current user box'ını al
  Box<String> get _currentUserBox => Hive.box<String>(currentUserBox);

  // Kullanıcı ekle
  Future<int> insertUser(Map<String, dynamic> user) async {
    try {
      final userId = user['id'] as String;
      // Map<String, dynamic>'i Map'e çevir
      final userMap = Map<dynamic, dynamic>.from(user);
      await _usersBox.put(userId, userMap);
      await _usersBox.flush(); // Verileri diske yaz
                  return 1;
    } catch (e) {
            return -1;
    }
  }

  // Kullanıcı adına göre kullanıcı bul
  Future<Map<String, dynamic>?> getUserByUsername(String username) async {
    try {
                  
      final users = _usersBox.values;
      for (final user in users) {
                if (user['username'] == username) {
                    return Map<String, dynamic>.from(user);
        }
      }
            return null;
    } catch (e) {
            return null;
    }
  }

  // ID'ye göre kullanıcı bul
  Future<Map<String, dynamic>?> getUserById(String userId) async {
    try {
      final user = _usersBox.get(userId);
      return user != null ? Map<String, dynamic>.from(user) : null;
    } catch (e) {
            return null;
    }
  }

  // Aktif kullanıcıyı ayarla
  Future<void> setCurrentUser(String userId) async {
    await _currentUserBox.put('current_user_id', userId);
    await _currentUserBox.flush(); // Verileri diske yaz
  }

  // Aktif kullanıcıyı getir
  Future<Map<String, dynamic>?> getCurrentUser() async {
    try {
      final userId = _currentUserBox.get('current_user_id');
      if (userId == null) {
        return null;
      }
      return await getUserById(userId);
    } catch (e) {
            return null;
    }
  }

  // Çıkış yap (aktif kullanıcıyı temizle)
  Future<void> clearCurrentUser() async {
    await _currentUserBox.delete('current_user_id');
    await _currentUserBox.flush(); // Verileri diske yaz
  }

  // Tüm kullanıcıları getir (debug için)
  Future<List<Map<String, dynamic>>> getAllUsers() async {
    try {
      final users = _usersBox.values;
      return users.map((user) => Map<String, dynamic>.from(user)).toList();
    } catch (e) {
            return [];
    }
  }

  // Kullanıcı sayısını getir
  Future<int> getUserCount() async {
    return _usersBox.length;
  }

  // Kullanıcı güncelle
  Future<bool> updateUser(String userId, Map<String, dynamic> updates) async {
    try {
      final existingUser = await getUserById(userId);
      if (existingUser == null) {
        
        return false;
      }

      // Mevcut kullanıcı bilgilerini güncelle
      final updatedUser = Map<String, dynamic>.from(existingUser);
      updates.forEach((key, value) {
        updatedUser[key] = value;
      });

      await _usersBox.put(userId, updatedUser);
      await _usersBox.flush();
      
      return true;
    } catch (e) {
      
      return false;
    }
  }

  // Şifre güncelle
  Future<bool> updatePassword(String userId, String newPasswordHash) async {
    return await updateUser(userId, {'password': newPasswordHash});
  }

  // Kullanıcıyı sil
  Future<bool> deleteUser(String userId) async {
    try {
      // Önce aktif kullanıcı mı kontrol et
      final currentUserId = _currentUserBox.get('current_user_id');
      if (currentUserId == userId) {
        await clearCurrentUser();
      }

      await _usersBox.delete(userId);
      await _usersBox.flush();
      
      return true;
    } catch (e) {
      
      return false;
    }
  }

  // Database'i temizle (debug için)
  Future<void> clearDatabase() async {
    await _usersBox.clear();
    await _currentUserBox.clear();
    await _userVehiclesBox.clear();
    await _offersBox.clear();
    await _notificationsBox.clear();
    await _activitiesBox.clear();
    await _usersBox.flush();
    await _currentUserBox.flush();
    await _userVehiclesBox.flush();
    await _offersBox.flush();
    await _notificationsBox.flush();
    await _activitiesBox.flush();
  }

  // ============================================================================
  // USER VEHICLES (Kullanıcıların Sahip Olduğu Araçlar)
  // ============================================================================

  // User vehicles box'ını al
  Box<Map> get _userVehiclesBox => Hive.box<Map>(userVehiclesBox);

  // Kullanıcının aracını ekle (satın alma)
  Future<bool> addUserVehicle(UserVehicle vehicle) async {
    try {
      final vehicleMap = Map<dynamic, dynamic>.from(vehicle.toJson());
      await _userVehiclesBox.put(vehicle.id, vehicleMap);
      await _userVehiclesBox.flush();
      
      return true;
    } catch (e) {
      
      return false;
    }
  }

  // Kullanıcının tüm araçlarını getir
  Future<List<UserVehicle>> getUserVehicles(String userId) async {
    try {
      final allVehicles = _userVehiclesBox.values;
      final userVehicles = <UserVehicle>[];
      
      for (final vehicleMap in allVehicles) {
        final vehicle = UserVehicle.fromJson(Map<String, dynamic>.from(vehicleMap));
        if (vehicle.userId == userId) {
          userVehicles.add(vehicle);
        }
      }
      
      // Satın alma tarihine göre sırala (en yeni en üstte)
      userVehicles.sort((a, b) => b.purchaseDate.compareTo(a.purchaseDate));
      
      
      return userVehicles;
    } catch (e) {
      
      return [];
    }
  }

  // Kullanıcının satılmamış araçlarını getir
  Future<List<UserVehicle>> getUserActiveVehicles(String userId) async {
    try {
      final allVehicles = await getUserVehicles(userId);
      return allVehicles.where((v) => !v.isSold).toList();
    } catch (e) {
      
      return [];
    }
  }

  // Kullanıcının satılmış araçlarını getir
  Future<List<UserVehicle>> getUserSoldVehicles(String userId) async {
    try {
      final allVehicles = await getUserVehicles(userId);
      return allVehicles.where((v) => v.isSold).toList();
    } catch (e) {
      
      return [];
    }
  }

  // Tüm kullanıcıların araçlarını getir (admin/sistem işlemleri için)
  Future<List<UserVehicle>> getAllUserVehicles() async {
    try {
      final vehicles = _userVehiclesBox.values
          .map((vehicleMap) => UserVehicle.fromJson(Map<String, dynamic>.from(vehicleMap)))
          .toList();
      return vehicles;
    } catch (e) {
      
      return [];
    }
  }

  // Kullanıcının satışa çıkardığı araçları getir
  Future<List<UserVehicle>> getUserListedVehicles(String userId) async {
    try {
      final allVehicles = await getUserVehicles(userId);
      return allVehicles.where((v) => v.isListedForSale && !v.isSold).toList();
    } catch (e) {
      
      return [];
    }
  }

  // Kullanıcının araç sayısını getir
  Future<int> getUserVehicleCount(String userId) async {
    try {
      final vehicles = await getUserActiveVehicles(userId);
      return vehicles.length;
    } catch (e) {
      
      return 0;
    }
  }

  // Belirli bir aracı getir
  Future<UserVehicle?> getUserVehicleById(String vehicleId) async {
    try {
      final vehicleMap = _userVehiclesBox.get(vehicleId);
      if (vehicleMap == null) return null;
      return UserVehicle.fromJson(Map<String, dynamic>.from(vehicleMap));
    } catch (e) {
      
      return null;
    }
  }

  // Kullanıcının aracını güncelle
  Future<bool> updateUserVehicle(String vehicleId, Map<String, dynamic> updates) async {
    try {
      final existingVehicle = await getUserVehicleById(vehicleId);
      if (existingVehicle == null) {
        
        return false;
      }

      final updatedVehicleJson = existingVehicle.toJson();
      updates.forEach((key, value) {
        updatedVehicleJson[key] = value;
      });

      final vehicleMap = Map<dynamic, dynamic>.from(updatedVehicleJson);
      await _userVehiclesBox.put(vehicleId, vehicleMap);
      await _userVehiclesBox.flush();
      
      return true;
    } catch (e) {
      
      return false;
    }
  }

  // Aracı satışa çıkar
  Future<bool> listVehicleForSale({
    required String vehicleId,
    required double listingPrice,
    required String listingDescription,
  }) async {
    try {
      return await updateUserVehicle(vehicleId, {
        'isListedForSale': true,
        'listingPrice': listingPrice,
        'listingDescription': listingDescription,
        'listedDate': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      
      return false;
    }
  }

  // Kullanıcının aracını sat
  Future<bool> sellUserVehicle(String vehicleId, double salePrice) async {
    try {
      return await updateUserVehicle(vehicleId, {
        'isSold': true,
        'salePrice': salePrice,
        'saleDate': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      
      return false;
    }
  }

  // Kullanıcının aracını sil (kalıcı)
  Future<bool> deleteUserVehicle(String vehicleId) async {
    try {
      await _userVehiclesBox.delete(vehicleId);
      await _userVehiclesBox.flush();
      
      return true;
    } catch (e) {
      
      return false;
    }
  }

  // Kullanıcının toplam harcamasını hesapla
  Future<double> getUserTotalSpent(String userId) async {
    try {
      final vehicles = await getUserVehicles(userId);
      return vehicles.fold<double>(0.0, (double sum, vehicle) => sum + vehicle.purchasePrice);
    } catch (e) {
      
      return 0.0;
    }
  }

  // Kullanıcının toplam kar/zararını hesapla
  Future<double> getUserTotalProfitLoss(String userId) async {
    try {
      final vehicles = await getUserVehicles(userId);
      return vehicles.fold<double>(0.0, (double sum, vehicle) {
        final pl = vehicle.profitLoss ?? 0.0;
        return sum + pl;
      });
    } catch (e) {
      
      return 0.0;
    }
  }

  // ============================================================================
  // OFFERS (Teklifler)
  // ============================================================================

  // Offers box'ını al
  Box<Map> get _offersBox => Hive.box<Map>(offersBox);

  // Teklif ekle
  Future<bool> addOffer(Offer offer) async {
    try {
      final offerMap = Map<dynamic, dynamic>.from(offer.toJson());
      await _offersBox.put(offer.offerId, offerMap);
      await _offersBox.flush();
      
      return true;
    } catch (e) {

      return false;
    }
  }

  // Teklif ID'sine göre teklif getir
  Future<Offer?> getOfferById(String offerId) async {
    try {
      final offerMap = _offersBox.get(offerId);
      if (offerMap == null) return null;
      return Offer.fromJson(Map<String, dynamic>.from(offerMap));
    } catch (e) {
      
      return null;
    }
  }

  // Satıcıya gelen tüm teklifleri getir
  Future<List<Offer>> getOffersBySellerId(String sellerId) async {
    try {
      final offers = _offersBox.values
          .map((offerMap) => Offer.fromJson(Map<String, dynamic>.from(offerMap)))
          .where((offer) => offer.sellerId == sellerId)
          .toList();
      
      // Tarihe göre sırala (en yeni en üstte)
      offers.sort((a, b) => b.offerDate.compareTo(a.offerDate));
      
      return offers;
    } catch (e) {
      
      return [];
    }
  }

  // Belirli bir araca gelen teklifleri getir
  Future<List<Offer>> getOffersByVehicleId(String vehicleId) async {
    try {
      final offers = _offersBox.values
          .map((offerMap) => Offer.fromJson(Map<String, dynamic>.from(offerMap)))
          .where((offer) => offer.vehicleId == vehicleId)
          .toList();
      
      // Tarihe göre sırala (en yeni en üstte)
      offers.sort((a, b) => b.offerDate.compareTo(a.offerDate));
      
      return offers;
    } catch (e) {
      
      return [];
    }
  }

  // Satıcının bekleyen tekliflerini getir
  Future<List<Offer>> getPendingOffersBySellerId(String sellerId) async {
    try {
      final offers = await getOffersBySellerId(sellerId);
      return offers.where((offer) => offer.isPending).toList();
    } catch (e) {
      
      return [];
    }
  }

  // Alıcının gönderdiği tüm teklifleri getir (kullanıcı teklifleri)
  Future<List<Offer>> getOffersByBuyerId(String buyerId) async {
    try {
      final offers = _offersBox.values
          .map((offerMap) => Offer.fromJson(Map<String, dynamic>.from(offerMap)))
          .where((offer) => offer.buyerId == buyerId && offer.isUserOffer)
          .toList();
      
      // Tarihe göre sırala (en yeni en üstte)
      offers.sort((a, b) => b.offerDate.compareTo(a.offerDate));
      
      return offers;
    } catch (e) {
      
      return [];
    }
  }

  // Satıcının bekleyen teklif sayısını getir
  Future<int> getPendingOffersCount(String sellerId) async {
    try {
      final offers = await getPendingOffersBySellerId(sellerId);
      return offers.length;
    } catch (e) {
      
      return 0;
    }
  }

  // Teklifi güncelle
  Future<bool> updateOffer(String offerId, Map<String, dynamic> updates) async {
    try {
      final offerMap = _offersBox.get(offerId);
      if (offerMap == null) {
        
        return false;
      }

      final updatedMap = Map<dynamic, dynamic>.from(offerMap);
      updates.forEach((key, value) {
        updatedMap[key] = value;
      });

      await _offersBox.put(offerId, updatedMap);
      await _offersBox.flush();
      
      return true;
    } catch (e) {
      
      return false;
    }
  }

  // Teklif durumunu güncelle
  Future<bool> updateOfferStatus(String offerId, OfferStatus status) async {
    try {
      return await updateOffer(offerId, {'status': status.index});
    } catch (e) {
      
      return false;
    }
  }

  // Teklifi sil
  Future<bool> deleteOffer(String offerId) async {
    try {
      await _offersBox.delete(offerId);
      await _offersBox.flush();
      
      return true;
    } catch (e) {
      
      return false;
    }
  }

  // Belirli bir araç için diğer tüm teklifleri reddet
  Future<bool> rejectOtherOffers(String vehicleId, String acceptedOfferId) async {
    try {
      final offers = await getOffersByVehicleId(vehicleId);
      
      for (var offer in offers) {
        if (offer.offerId != acceptedOfferId && offer.status == OfferStatus.pending) {
          await updateOfferStatus(offer.offerId, OfferStatus.rejected);
        }
      }
      
      
      return true;
    } catch (e) {
      
      return false;
    }
  }

  // Süresi dolan teklifleri güncelle
  Future<void> expireOldOffers() async {
    try {
      final allOffers = _offersBox.values
          .map((offerMap) => Offer.fromJson(Map<String, dynamic>.from(offerMap)))
          .toList();
      
      for (var offer in allOffers) {
        if (offer.isExpired) {
          await updateOfferStatus(offer.offerId, OfferStatus.expired);
        }
      }
      
      
    } catch (e) {
      
    }
  }

  // Tüm teklifleri temizle (belirli bir araç için)
  Future<bool> deleteOffersForVehicle(String vehicleId) async {
    try {
      final offers = await getOffersByVehicleId(vehicleId);
      
      for (var offer in offers) {
        await deleteOffer(offer.offerId);
      }
      
      
      return true;
    } catch (e) {
      
      return false;
    }
  }

  // ============================================================================
  // NOTIFICATIONS (Bildirimler)
  // ============================================================================

  // Notifications box'ını al
  Box<Map> get _notificationsBox => Hive.box<Map>(notificationsBox);

  // Bildirim ekle
  Future<bool> addNotification(AppNotification notification) async {
    try {
      final notificationMap = Map<dynamic, dynamic>.from(notification.toJson());
      await _notificationsBox.put(notification.id, notificationMap);
      await _notificationsBox.flush();
      
      return true;
    } catch (e) {
      
      return false;
    }
  }

  // Kullanıcının tüm bildirimlerini getir
  Future<List<AppNotification>> getUserNotifications(String userId) async {
    try {
      final allNotifications = _notificationsBox.values;
      final userNotifications = allNotifications
          .where((n) => n['userId'] == userId)
          .map((n) => AppNotification.fromJson(Map<String, dynamic>.from(n)))
          .toList();
      
      // Tarihe göre sırala (en yeni üstte)
      userNotifications.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      
      return userNotifications;
    } catch (e) {
      
      return [];
    }
  }

  // Okunmamış bildirim sayısı
  Future<int> getUnreadNotificationCount(String userId) async {
    try {
      final notifications = await getUserNotifications(userId);
      return notifications.where((n) => !n.isRead).length;
    } catch (e) {
      
      return 0;
    }
  }

  // Bildirimi okundu işaretle
  Future<bool> markNotificationAsRead(String notificationId) async {
    try {
      final notification = _notificationsBox.get(notificationId);
      if (notification != null) {
        notification['isRead'] = true;
        await _notificationsBox.put(notificationId, notification);
        await _notificationsBox.flush();
      }
      return true;
    } catch (e) {
      
      return false;
    }
  }

  // Tüm bildirimleri okundu işaretle
  Future<bool> markAllNotificationsAsRead(String userId) async {
    try {
      final notifications = await getUserNotifications(userId);
      for (var notification in notifications) {
        if (!notification.isRead) {
          await markNotificationAsRead(notification.id);
        }
      }
      return true;
    } catch (e) {
      
      return false;
    }
  }

  // Bildirimi sil
  Future<bool> deleteNotification(String notificationId) async {
    try {
      await _notificationsBox.delete(notificationId);
      await _notificationsBox.flush();
      return true;
    } catch (e) {
      
      return false;
    }
  }

  // Tüm bildirimleri sil
  Future<bool> deleteAllNotifications(String userId) async {
    try {
      final notifications = await getUserNotifications(userId);
      for (var notification in notifications) {
        await deleteNotification(notification.id);
      }
      return true;
    } catch (e) {
      
      return false;
    }
  }

  // ============================================================================
  // DAILY QUESTS (Günlük Görevler)
  // ============================================================================

  static const String dailyQuestsBox = 'daily_quests';

  // Daily Quests box'ını al
  Box<Map> get _dailyQuestsBox => Hive.box<Map>(dailyQuestsBox);

  // Görev ekle
  Future<bool> addDailyQuest(Map<String, dynamic> questMap) async {
    try {
      final questId = questMap['id'] as String;
      await _dailyQuestsBox.put(questId, questMap);
      await _dailyQuestsBox.flush();
      return true;
    } catch (e) {
      return false;
    }
  }

  // Kullanıcının belirli bir tarihteki görevlerini getir
  Future<List<Map<String, dynamic>>> getUserDailyQuests(String userId, DateTime date) async {
    try {
      final allQuests = _dailyQuestsBox.values;
      final userQuests = <Map<String, dynamic>>[];
      
      for (var quest in allQuests) {
        final questDate = DateTime.parse(quest['date'] as String);
        if (quest['userId'] == userId && 
            questDate.year == date.year && 
            questDate.month == date.month && 
            questDate.day == date.day) {
          userQuests.add(Map<String, dynamic>.from(quest));
        }
      }
      
      return userQuests;
    } catch (e) {
      return [];
    }
  }

  // Belirli bir görevi getir
  Future<Map<String, dynamic>?> getDailyQuestById(String questId) async {
    try {
      final questMap = _dailyQuestsBox.get(questId);
      if (questMap != null) {
        return Map<String, dynamic>.from(questMap);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // Görevi güncelle
  Future<bool> updateDailyQuest(String questId, Map<String, dynamic> updates) async {
    try {
      final questMap = _dailyQuestsBox.get(questId);
      if (questMap == null) return false;

      final updatedMap = Map<dynamic, dynamic>.from(questMap);
      updates.forEach((key, value) {
        updatedMap[key] = value;
      });

      await _dailyQuestsBox.put(questId, updatedMap);
      await _dailyQuestsBox.flush();
      
      return true;
    } catch (e) {
      return false;
    }
  }

  // Eski görevleri temizle (opsiyonel, veritabanı şişmesin diye)
  Future<void> clearOldQuests(DateTime beforeDate) async {
    try {
      final keysToDelete = <String>[];
      final allQuests = _dailyQuestsBox.toMap();
      
      allQuests.forEach((key, value) {
        final questDate = DateTime.parse(value['date'] as String);
        if (questDate.isBefore(beforeDate)) {
          keysToDelete.add(key as String);
        }
      });
      
      await _dailyQuestsBox.deleteAll(keysToDelete);
      await _dailyQuestsBox.flush();
    } catch (e) {
      // Hata olsa da devam et
    }
  }
  // ============================================================================
  // ACTIVITIES (Aktivite Geçmişi)
  // ============================================================================

  static const String activitiesBox = 'activities';

  // Activities box'ını al
  Box<Map> get _activitiesBox => Hive.box<Map>(activitiesBox);

  // Aktivite ekle
  Future<bool> addActivity(Activity activity) async {
    try {
      final activityMap = Map<dynamic, dynamic>.from(activity.toJson());
      await _activitiesBox.put(activity.id, activityMap);
      await _activitiesBox.flush();
      return true;
    } catch (e) {
      return false;
    }
  }

  // Kullanıcının aktivitelerini getir
  Future<List<Activity>> getUserActivities(String userId) async {
    try {
      final allActivities = _activitiesBox.values;
      final userActivities = <Activity>[];
      
      for (var activityMap in allActivities) {
        final activity = Activity.fromJson(Map<String, dynamic>.from(activityMap));
        if (activity.userId == userId) {
          userActivities.add(activity);
        }
      }
      
      // Tarihe göre sırala (en yeni en üstte)
      userActivities.sort((a, b) => b.date.compareTo(a.date));
      
      return userActivities;
    } catch (e) {
      return [];
    }
  }

  // Aktivite sil
  Future<bool> deleteActivity(String activityId) async {
    try {
      await _activitiesBox.delete(activityId);
      await _activitiesBox.flush();
      return true;
    } catch (e) {
      return false;
    }
  }

  // Kullanıcının tüm aktivitelerini sil
  Future<bool> clearUserActivities(String userId) async {
    try {
      final activities = await getUserActivities(userId);
      for (var activity in activities) {
        await deleteActivity(activity.id);
      }
      return true;
    } catch (e) {
      return false;
    }
  }
}

import 'package:hive_flutter/hive_flutter.dart';
import '../models/user_model.dart';
import '../models/user_vehicle_model.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  // Box isimleri
  static const String usersBox = 'users';
  static const String currentUserBox = 'current_user';
  static const String userVehiclesBox = 'user_vehicles'; // Kullanıcıların araçları

  // Initialize Hive
  static Future<void> init() async {
    await Hive.initFlutter();
    
    // Boxları aç
    final usersBoxInstance = await Hive.openBox<Map>(usersBox);
    final currentUserBoxInstance = await Hive.openBox<String>(currentUserBox);
    final userVehiclesBoxInstance = await Hive.openBox<Map>(userVehiclesBox);
    
                
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
        print('❌ User not found: $userId');
        return false;
      }

      // Mevcut kullanıcı bilgilerini güncelle
      final updatedUser = Map<String, dynamic>.from(existingUser);
      updates.forEach((key, value) {
        updatedUser[key] = value;
      });

      await _usersBox.put(userId, updatedUser);
      await _usersBox.flush();
      print('✅ User updated: $userId');
      return true;
    } catch (e) {
      print('❌ Error updating user: $e');
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
      print('✅ User deleted: $userId');
      return true;
    } catch (e) {
      print('❌ Error deleting user: $e');
      return false;
    }
  }

  // Database'i temizle (debug için)
  Future<void> clearDatabase() async {
    await _usersBox.clear();
    await _currentUserBox.clear();
    await _userVehiclesBox.clear();
    await _usersBox.flush();
    await _currentUserBox.flush();
    await _userVehiclesBox.flush();
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
      print('✅ Vehicle added to user garage: ${vehicle.fullName} (ID: ${vehicle.id})');
      return true;
    } catch (e) {
      print('❌ Error adding vehicle to user: $e');
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
      
      print('📊 User $userId has ${userVehicles.length} vehicles');
      return userVehicles;
    } catch (e) {
      print('❌ Error getting user vehicles: $e');
      return [];
    }
  }

  // Kullanıcının satılmamış araçlarını getir
  Future<List<UserVehicle>> getUserActiveVehicles(String userId) async {
    try {
      final allVehicles = await getUserVehicles(userId);
      return allVehicles.where((v) => !v.isSold).toList();
    } catch (e) {
      print('❌ Error getting user active vehicles: $e');
      return [];
    }
  }

  // Kullanıcının satılmış araçlarını getir
  Future<List<UserVehicle>> getUserSoldVehicles(String userId) async {
    try {
      final allVehicles = await getUserVehicles(userId);
      return allVehicles.where((v) => v.isSold).toList();
    } catch (e) {
      print('❌ Error getting user sold vehicles: $e');
      return [];
    }
  }

  // Kullanıcının satışa çıkardığı araçları getir
  Future<List<UserVehicle>> getUserListedVehicles(String userId) async {
    try {
      final allVehicles = await getUserVehicles(userId);
      return allVehicles.where((v) => v.isListedForSale && !v.isSold).toList();
    } catch (e) {
      print('❌ Error getting user listed vehicles: $e');
      return [];
    }
  }

  // Kullanıcının araç sayısını getir
  Future<int> getUserVehicleCount(String userId) async {
    try {
      final vehicles = await getUserActiveVehicles(userId);
      return vehicles.length;
    } catch (e) {
      print('❌ Error getting user vehicle count: $e');
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
      print('❌ Error getting user vehicle by id: $e');
      return null;
    }
  }

  // Kullanıcının aracını güncelle
  Future<bool> updateUserVehicle(String vehicleId, Map<String, dynamic> updates) async {
    try {
      final existingVehicle = await getUserVehicleById(vehicleId);
      if (existingVehicle == null) {
        print('❌ Vehicle not found: $vehicleId');
        return false;
      }

      final updatedVehicleJson = existingVehicle.toJson();
      updates.forEach((key, value) {
        updatedVehicleJson[key] = value;
      });

      final vehicleMap = Map<dynamic, dynamic>.from(updatedVehicleJson);
      await _userVehiclesBox.put(vehicleId, vehicleMap);
      await _userVehiclesBox.flush();
      print('✅ Vehicle updated: $vehicleId');
      return true;
    } catch (e) {
      print('❌ Error updating vehicle: $e');
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
      print('❌ Error listing vehicle for sale: $e');
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
      print('❌ Error selling vehicle: $e');
      return false;
    }
  }

  // Kullanıcının aracını sil (kalıcı)
  Future<bool> deleteUserVehicle(String vehicleId) async {
    try {
      await _userVehiclesBox.delete(vehicleId);
      await _userVehiclesBox.flush();
      print('✅ Vehicle deleted: $vehicleId');
      return true;
    } catch (e) {
      print('❌ Error deleting vehicle: $e');
      return false;
    }
  }

  // Kullanıcının toplam harcamasını hesapla
  Future<double> getUserTotalSpent(String userId) async {
    try {
      final vehicles = await getUserVehicles(userId);
      return vehicles.fold<double>(0.0, (double sum, vehicle) => sum + vehicle.purchasePrice);
    } catch (e) {
      print('❌ Error calculating total spent: $e');
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
      print('❌ Error calculating total profit/loss: $e');
      return 0.0;
    }
  }
}

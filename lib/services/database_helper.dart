import 'package:hive_flutter/hive_flutter.dart';
import '../models/user_model.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  // Box isimleri
  static const String usersBox = 'users';
  static const String currentUserBox = 'current_user';

  // Initialize Hive
  static Future<void> init() async {
    await Hive.initFlutter();
    
    // Boxları aç
    final usersBoxInstance = await Hive.openBox<Map>(usersBox);
    final currentUserBoxInstance = await Hive.openBox<String>(currentUserBox);
    
                
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
    await _usersBox.flush();
    await _currentUserBox.flush();
      }
}

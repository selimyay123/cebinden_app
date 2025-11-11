import 'package:crypto/crypto.dart';
import 'dart:convert' as convert;
import '../models/user_model.dart';
import 'database_helper.dart';

class AuthService {
  // Singleton pattern
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final DatabaseHelper _db = DatabaseHelper();

  // Şifreyi hashle
  String _hashPassword(String password) {
    final bytes = convert.utf8.encode(password);
    final hash = sha256.convert(bytes);
    return hash.toString();
  }

  // Aktif kullanıcı var mı kontrol et
  Future<bool> checkUserExists() async {
    final user = await _db.getCurrentUser();
    return user != null;
  }

  // Aktif kullanıcıyı getir
  Future<User?> getCurrentUser() async {
    final userMap = await _db.getCurrentUser();
    
    if (userMap == null) {
      return null;
    }
    
    try {
      return User.fromJson(userMap);
    } catch (e) {
            return null;
    }
  }

  // Giriş yap
  Future<User?> login({
    required String username,
    required String password,
  }) async {
        final hashedPassword = _hashPassword(password);
        
    // Kullanıcıyı database'den bul
    final userMap = await _db.getUserByUsername(username);
    
    if (userMap == null) {
            return null; // Kullanıcı bulunamadı
    }
    
            
    // Şifreyi kontrol et
    if (userMap['password'] != hashedPassword) {
            return null; // Şifre yanlış
    }
    
        
    // Aktif kullanıcıyı ayarla
    await _db.setCurrentUser(userMap['id'] as String);
    
    return User.fromJson(userMap);
  }

  // Yeni kullanıcı kaydı oluştur
  Future<bool> registerUser({
    required String username,
    required String password,
    required String gender,
    required DateTime birthDate,
  }) async {
    if (username.trim().isEmpty || password.isEmpty) {
      return false;
    }

    // Kullanıcı adı kontrolü
    final existingUser = await _db.getUserByUsername(username);
    if (existingUser != null) {
      return false; // Kullanıcı adı zaten var
    }
    
    // Yeni kullanıcı oluştur
    final newUser = User.create(
      username: username.trim(),
      password: _hashPassword(password),
      gender: gender,
      birthDate: birthDate,
    );

    // Database'e ekle
    final result = await _db.insertUser({
      'id': newUser.id,
      'username': newUser.username,
      'password': newUser.password,
      'gender': newUser.gender,
      'birthDate': newUser.birthDate.toIso8601String(),
      'registeredAt': newUser.registeredAt.toIso8601String(),
      'balance': newUser.balance,
      'profitLossPercentage': newUser.profitLossPercentage,
      'profileImageUrl': newUser.profileImageUrl,
      'currency': newUser.currency,
    });

    if (result == -1) {
      return false; // Hata oluştu
    }
    
    // Aktif kullanıcıyı ayarla
    await _db.setCurrentUser(newUser.id);
    
    return true;
  }

  // Çıkış yap
  Future<void> logout() async {
    await _db.clearCurrentUser();
  }

  // Şifre değiştir
  Future<bool> changePassword({
    required String userId,
    required String oldPassword,
    required String newPassword,
  }) async {
    try {
      // Kullanıcıyı getir
      final userMap = await _db.getUserById(userId);
      if (userMap == null) {
        return false;
      }

      final user = User.fromJson(userMap);

      // Eski şifre doğru mu?
      if (user.password != _hashPassword(oldPassword)) {
        return false; // Eski şifre yanlış
      }

      // Yeni şifreyi hashle ve güncelle
      final newPasswordHash = _hashPassword(newPassword);
      return await _db.updatePassword(userId, newPasswordHash);
    } catch (e) {
      print('❌ Error changing password: $e');
      return false;
    }
  }

  // Kullanıcı bilgilerini güncelle
  Future<bool> updateUserInfo({
    required String userId,
    String? currency,
  }) async {
    try {
      final updates = <String, dynamic>{};
      if (currency != null) updates['currency'] = currency;

      if (updates.isEmpty) return true;

      return await _db.updateUser(userId, updates);
    } catch (e) {
      print('❌ Error updating user info: $e');
      return false;
    }
  }

  // Hesabı sil
  Future<bool> deleteAccount(String userId) async {
    try {
      return await _db.deleteUser(userId);
    } catch (e) {
      print('❌ Error deleting account: $e');
      return false;
    }
  }

  // Tüm kullanıcıları getir (debug için)
  Future<List<User>> getAllUsers() async {
    final usersMapList = await _db.getAllUsers();
    
    final List<User> users = [];
    for (final userMap in usersMapList) {
      try {
        users.add(User.fromJson(userMap));
      } catch (e) {
                continue;
      }
    }
    
    return users;
  }

  // Kullanıcı sayısı (debug için)
  Future<int> getUserCount() async {
    return await _db.getUserCount();
  }
}


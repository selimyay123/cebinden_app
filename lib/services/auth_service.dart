import 'package:crypto/crypto.dart';
import 'dart:convert' as convert;
import 'package:profanity_filter/profanity_filter.dart';
import '../models/user_model.dart';
import 'database_helper.dart';
import 'firebase_auth_service.dart';

class AuthService {
  // Singleton pattern
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  final DatabaseHelper _db = DatabaseHelper();
  final FirebaseAuthService _firebaseAuth = FirebaseAuthService();
  final ProfanityFilter _profanityFilter;

  AuthService._internal() : _profanityFilter = ProfanityFilter.filterAdditionally([
      'amk', 'aq', 'sik', 'yarrak', 'oç', 'pic', 'piç', 'yavşak', 'göt', 'meme', 
      'sokuk', 'siktir', 'sikiş', 'kaşar', 'orospu', 'orosbu', 'kahpe', 'ibne', 
      'ipne', 'puşt', 'pezevenk', 'sikik', 'yarak', 'amcık', 'ananı', 'bacını',
      'sikerim', 'sokayım', 'kaltak', 'dalyarak', 'taşşak', 'tassak'
    ]);

  // Küfür kontrolü
  bool hasProfanity(String text) {
    return _profanityFilter.hasProfanity(text);
  }

  // Admin kontrolü
  bool get isAdmin {
    // Şu anki kullanıcıyı alıp kontrol etmek yerine, 
    // giriş yapan kullanıcının email'ini kontrol edeceğiz.
    // Ancak burada doğrudan kullanıcı objesine erişimimiz yok.
    // Bu yüzden bu kontrolü UI tarafında veya user objesi üzerinden yapacağız.
    return false; 
  }

  // Kullanıcı admin mi? (User objesi üzerinden)
  bool isUserAdmin(User user) {
    return user.email == 'selimyay123@gmail.com';
  }

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
    
    final user = User.fromJson(userMap);

    // Yasaklı mı kontrol et
    if (user.isBanned) {
      await logout();
      return null;
    }

    return user;
  }

  // Yeni kullanıcı kaydı oluştur
  Future<bool> registerUser({
    required String username,
    required String password,
  }) async {
    if (username.trim().isEmpty || password.isEmpty) {
      return false;
    }

    // Küfür kontrolü
    if (_profanityFilter.hasProfanity(username)) {
      return false; // Uygunsuz kullanıcı adı
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
    );

    // Database'e ekle
    final result = await _db.insertUser({
      'id': newUser.id,
      'username': newUser.username,
      'password': newUser.password,
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

  // Google ile giriş yap
  Future<User?> loginWithGoogle() async {
    try {
      // Firebase üzerinden Google Sign-In
      final user = await _firebaseAuth.signInWithGoogle();
      
      if (user == null) {
        return null; // Kullanıcı giriş iptal etti veya hata oluştu
      }
      
      // Aktif kullanıcıyı ayarla
      await _db.setCurrentUser(user.id);
      
      // Yasaklı mı kontrol et
      if (user.isBanned) {
        await logout();
        return null;
      }

      return user;
    } catch (e) {
      
      return null;
    }
  }

  // Apple ile giriş yap
  Future<User?> loginWithApple() async {
    try {
      // Firebase üzerinden Apple Sign-In
      final user = await _firebaseAuth.signInWithApple();
      
      if (user == null) {
        return null; // Kullanıcı giriş iptal etti veya hata oluştu
      }
      
      // Aktif kullanıcıyı ayarla
      await _db.setCurrentUser(user.id);
      
      // Yasaklı mı kontrol et
      if (user.isBanned) {
        await logout();
        return null;
      }

      return user;
    } catch (e) {
      return null;
    }
  }

  // Çıkış yap
  Future<void> logout() async {
    await _db.clearCurrentUser();
    await _firebaseAuth.signOut(); // Google'dan da çıkış yap
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
      
      return false;
    }
  }

  // Kullanıcı adı değiştir
  // Kullanıcı adı değiştir
  Future<bool> changeUsername({
    required String userId,
    required String newUsername,
  }) async {
    // Yeni kullanıcı adı dolu mu kontrol et
    if (newUsername.trim().isEmpty) return false;

    // Küfür kontrolü
    if (_profanityFilter.hasProfanity(newUsername)) {
      return false; // Uygunsuz kullanıcı adı
    }

    // Kullanıcıyı getir
    final userMap = await _db.getUserById(userId);
    if (userMap == null) return false;
    final user = User.fromJson(userMap);

    // Süre kontrolü
    if (user.usernameChangeCount > 0) {
      if (user.lastUsernameChangeDate != null) {
        final daysSinceLastChange = DateTime.now().difference(user.lastUsernameChangeDate!).inDays;
        if (daysSinceLastChange < 7) {
          return false; // 7 gün geçmedi
        }
      }
    }

    // Kullanıcı adı zaten alınmış mı kontrol et
    final existingUser = await _db.getUserByUsername(newUsername.trim());
    if (existingUser != null) return false;

    // Kullanıcı adını güncelle
    return await _db.updateUser(userId, {
      'username': newUsername.trim(),
      'usernameChangeCount': user.usernameChangeCount + 1,
      'lastUsernameChangeDate': DateTime.now().toIso8601String(),
    });
  }

  // Kullanıcı bilgilerini güncelle
  Future<bool> updateUserInfo({
    required String userId,
    String? currency,
    String? profileImageUrl,
  }) async {
    try {
      final updates = <String, dynamic>{};
      if (currency != null) updates['currency'] = currency;
      if (profileImageUrl != null) updates['profileImageUrl'] = profileImageUrl;

      if (updates.isEmpty) return true;

      return await _db.updateUser(userId, updates);
    } catch (e) {
      
      return false;
    }
  }

  // Hesabı sil
  Future<bool> deleteAccount(String userId) async {
    try {
      return await _db.deleteUser(userId);
    } catch (e) {
      
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
  // Kullanıcıyı yasakla
  Future<bool> banUser(String userId) async {
    try {
      return await _db.updateUser(userId, {'isBanned': true});
    } catch (e) {
      print('Error banning user: $e');
      return false;
    }
  }
}


import 'package:crypto/crypto.dart';
import 'dart:convert' as convert;
import 'package:profanity_filter/profanity_filter.dart';
import '../models/user_model.dart';
import 'database_helper.dart';
import 'firebase_auth_service.dart';
import 'cloud_service.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;

import 'leaderboard_service.dart';
import 'staff_service.dart'; // Import StaffService

class AuthService {
  // Singleton pattern
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  final DatabaseHelper _db = DatabaseHelper();
  final FirebaseAuthService _firebaseAuth = FirebaseAuthService();
  final ProfanityFilter _profanityFilter;

  AuthService._internal()
    : _profanityFilter = ProfanityFilter.filterAdditionally([
        'amk',
        'aq',
        'sik',
        'yarrak',
        'oç',
        'pic',
        'piç',
        'yavşak',
        'göt',
        'meme',
        'sokuk',
        'siktir',
        'sikiş',
        'kaşar',
        'orospu',
        'orosbu',
        'kahpe',
        'ibne',
        'ipne',
        'puşt',
        'pezevenk',
        'sikik',
        'yarak',
        'amcık',
        'ananı',
        'bacını',
        'sikerim',
        'sokayım',
        'kaltak',
        'dalyarak',
        'taşşak',
        'tassak',
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
    return user.email == 'selimyay123@gmail.com' ||
        user.email == 'caneryokusm@gmail.com';
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

    // 1. Önce kullanıcıyı database'den bul (YEREL KONTROL)
    var userMap = await _db.getUserByUsername(username);
    User? user;

    if (userMap != null) {
      // Yerelde bulundu, şifre kontrolü yap
      if (userMap['password'] != hashedPassword) {
        // Şifre yanlış (yerel hash ile uyuşmuyor).
        // ANCAK: Kullanıcı şifresini "Şifremi Unuttum" ile Firebase üzerinden değiştirmiş olabilir.
        // Bu durumda Firebase'e bu şifreyle girmeyi deneyelim.
        final email = userMap['email'] as String?;
        if (email != null && email.isNotEmpty) {
          try {
            await _firebaseAuth.signInWithEmailAndPassword(email, password);
            // Eğer hata almazsak, Firebase şifresi bu demektir!
            // Yerel şifreyi güncelle.
            userMap['password'] = hashedPassword;
            await _db.updateUser(userMap['id'], {'password': hashedPassword});
            // Cloud'u da güncellemek iyi olur
            try {
              final userObj = User.fromJson(userMap);
              await CloudService().saveUser(
                userObj.copyWith(password: hashedPassword),
              );
            } catch (_) {}

            // Devam et...
            user = User.fromJson(userMap);
          } catch (e) {
            return null; // Hem yerel hem Firebase yanlış
          }
        } else {
          return null; // Email yok, kurtaramayız
        }
      } else {
        user = User.fromJson(userMap);
      }
    }

    // 2. Yerelde yoksa veya yukarıdaki akışta bulunamadıysa Buluta bak (CLOUD FALLBACK)
    if (user == null) {
      try {
        final cloudUser = await CloudService().getUserByUsername(username);

        if (cloudUser != null) {
          // Bulutta bulundu, şifre kontrolü yap
          if (cloudUser.password == hashedPassword) {
            // Şifre doğru! Kullanıcıyı ve araçlarını yerel DB'ye restore et

            // Kullanıcıyı kaydet
            await _db.insertUser(cloudUser.toJson());

            // Araçları çek ve kaydet
            final vehicles = await CloudService().getUserVehicles(cloudUser.id);
            for (var vehicle in vehicles) {
              await _db.addUserVehicle(vehicle);
            }

            user = cloudUser;
          } else {
            // Yerelde yok, Bulutta var ama şifre yanlış.
            // Burada da Firebase Recovery denenebilir ama şimdilik pas geçiyorum.
            return null;
          }
        } else {
          return null; // Ne yerelde ne bulutta var
        }
      } catch (e) {
        return null; // Bağlantı hatası vb.
      }
    }

    // Kullanıcı bulundu ve şifre (hash) doğru.
    // ŞİMDİ FIREBASE AUTH GİRİŞİ YAPMALIYIZ (Eğer email varsa)
    if (user.email != null && user.email!.isNotEmpty) {
      try {
        final credential = await _firebaseAuth.signInWithEmailAndPassword(
          user.email!,
          password,
        );
        if (credential != null) {
        } else {}
      } catch (e) {
        // Firebase girişi başarısız olsa bile (örn: internet yok, veya firebase hesabı silinmiş ama DB'de var),
        // Yerel giriş devam etmeli mi?
        // "Hesap Silme" gibi kritik işlemler için Firebase Auth şart.
        // Ancak "Offline Oyun" için yerel giriş yeterli olabilir.
        // Şimdilik sadece logluyoruz, girişi engellemiyor.
        // Kullanıcı hesap silmeye çalışırsa "Giriş yapmalısınız" hatası alacak, bu da doğru davranış.
      }
    }

    // Aktif kullanıcıyı ayarla
    await _db.setCurrentUser(user.id);

    // Yasaklı mı kontrol et
    if (user.isBanned) {
      await logout();
      return null;
    }

    // Staff servisini başlat (Kullanıcıya özel personelleri yükle)
    await StaffService().init();

    return user;
  }

  // Yeni kullanıcı kaydı oluştur
  Future<bool> registerUser({
    required String username,
    required String email,
    required String password,
  }) async {
    if (username.trim().isEmpty || email.trim().isEmpty || password.isEmpty) {
      return false;
    }

    // Küfür kontrolü
    if (_profanityFilter.hasProfanity(username)) {
      return false; // Uygunsuz kullanıcı adı
    }

    // Kullanıcı adı kontrolü (Global)
    final cloudUser = await CloudService().getUserByUsername(username);
    if (cloudUser != null) {
      return false; // Kullanıcı adı zaten var
    }

    try {
      // 1. Firebase Auth ile kullanıcı oluştur
      firebase_auth.User? firebaseUser;
      try {
        firebaseUser = await _firebaseAuth.registerWithEmailAndPassword(
          email,
          password,
        );
      } catch (e) {
        return false;
      }

      if (firebaseUser == null) {
        return false;
      }

      // 2. Yeni kullanıcı modelini oluştur
      final newUser = User(
        id: firebaseUser.uid,
        username: username.trim(),
        email: email.trim(),
        password: _hashPassword(password),
        registeredAt: DateTime.now(),
        balance: 1000000.0,
        authProvider: 'email',
      );

      // 3. Database'e ekle
      final result = await _db.insertUser(newUser.toJson());

      if (result == -1) {
        return false;
      }

      // Aktif kullanıcıyı ayarla
      await _db.setCurrentUser(newUser.id);

      // Staff servisini başlat (Yeni kullanıcı için boş liste yükler)
      await StaffService().init();

      return true;
    } catch (e) {
      return false;
    }
  }

  // Şifre sıfırlama e-postası gönder
  Future<bool> sendPasswordResetEmail(String email) async {
    return await _firebaseAuth.sendPasswordResetEmail(email);
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

      // Staff servisini başlat
      await StaffService().init();

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

      // Staff servisini başlat
      await StaffService().init();

      return user;
    } catch (e) {
      return null;
    }
  }

  // Çıkış yap
  Future<void> logout() async {
    await _db.clearCurrentUser();
    await _firebaseAuth.signOut(); // Google'dan da çıkış yap

    // Staff servisini temizle (Önceki kullanıcının personellerini sil)
    StaffService().clearStaff();
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
        final daysSinceLastChange = DateTime.now()
            .difference(user.lastUsernameChangeDate!)
            .inDays;
        if (daysSinceLastChange < 7) {
          return false; // 7 gün geçmedi
        }
      }
    }

    // Kullanıcı adı zaten alınmış mı kontrol et
    final existingUser = await _db.getUserByUsername(newUsername.trim());
    if (existingUser != null) return false;

    final cloudExistingUser = await CloudService().getUserByUsername(
      newUsername.trim(),
    );
    if (cloudExistingUser != null) return false;

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
  Future<bool> deleteAccount(String userId, {bool force = false}) async {
    try {
      // 0. Önce Firebase Auth'dan sil (En kritiği bu)
      // Eğer bu başarısız olursa (örn: requires-recent-login), işlem durmalı
      bool authDeleted = false;
      try {
        authDeleted = await _firebaseAuth.deleteUser();
      } catch (e) {
        if (!force) rethrow; // Force değilse hatayı fırlat
      }

      if (!authDeleted && !force) {
        // Auth silinemedi ve force değil, işlemi durdur
        return false;
      }

      // 1. Cloud'dan sil (Firestore)
      try {
        await CloudService().deleteUser(userId);
      } catch (e) {
        if (!force) rethrow;
      }

      // 1.5 Leaderboard'dan sil
      try {
        await LeaderboardService().deleteUserScore(userId);
        // ignore: empty_catches
      } catch (e) {}

      // 2. Local verileri sil (Hive)
      await _db.deleteUserData(userId);

      // 3. Oturumu kapat
      await logout();

      return true;
    } catch (e) {
      // Debug Log

      // Eğer hata 'requires-recent-login' ise yukarıya fırlat ki UI bilsin
      // Type check bazen başarısız olabiliyor, string kontrolü ekliyoruz
      if (e.toString().contains('requires-recent-login')) {
        throw firebase_auth.FirebaseAuthException(
          code: 'requires-recent-login',
          message: 'Re-login required',
        );
      } else if (e is firebase_auth.FirebaseAuthException &&
          e.code == 'requires-recent-login') {
        rethrow;
      } else {
        // Diğer hataları da fırlat ki UI görebilsin
        rethrow;
      }
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
      return false;
    }
  }

  // E-posta doğrulama gönder
  Future<void> sendEmailVerification() async {
    await _firebaseAuth.sendEmailVerification();
  }

  // E-posta doğrulanmış mı kontrol et
  bool get isEmailVerified {
    return _firebaseAuth.isEmailVerified;
  }

  // Kullanıcı verilerini yenile
  Future<void> reloadUser() async {
    await _firebaseAuth.reloadUser();
  }

  // Re-authentication Methods
  Future<bool> reauthenticateWithPassword(String password) async {
    return await _firebaseAuth.reauthenticateWithPassword(password);
  }

  Future<bool> reauthenticateWithGoogle() async {
    return await _firebaseAuth.reauthenticateWithGoogle();
  }

  Future<bool> reauthenticateWithApple() async {
    return await _firebaseAuth.reauthenticateWithApple();
  }
}

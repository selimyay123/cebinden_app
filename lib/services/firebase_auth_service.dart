import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../models/user_model.dart';
import 'database_helper.dart';
import 'package:uuid/uuid.dart';
import 'cloud_service.dart';

class FirebaseAuthService {
  static final FirebaseAuthService _instance = FirebaseAuthService._internal();
  factory FirebaseAuthService() => _instance;
  FirebaseAuthService._internal();

  final firebase_auth.FirebaseAuth _firebaseAuth = firebase_auth.FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    // iOS için CLIENT_ID manuel olarak belirtilmeli, Android'de google-services.json'dan otomatik alınır
    clientId: Platform.isIOS 
        ? '585097479960-jd9clpbd09ttok1lgienfbaaedqofv9c.apps.googleusercontent.com'
        : null,
    scopes: [
      'email',
      'profile',
    ],
  );

  /// Google ile giriş yap
  /// Returns: User nesnesi veya null (başarısız olursa)
  Future<User?> signInWithGoogle() async {
    try {
      // 1. Google Sign-In akışını başlat
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      
      if (googleUser == null) {
        // Kullanıcı giriş işlemini iptal etti
        return null;
      }

      // 2. Google kimlik doğrulama detaylarını al
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      // 3. Firebase credential oluştur
      final firebase_auth.AuthCredential credential = firebase_auth.GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // 4. Firebase'e giriş yap
      final firebase_auth.UserCredential userCredential = 
          await _firebaseAuth.signInWithCredential(credential);
      
      final firebase_auth.User? firebaseUser = userCredential.user;
      
      if (firebaseUser == null) {
        return null;
      }

      // 5. Kullanıcıyı local database'de kontrol et veya oluştur
      final existingUser = await _findUserByGoogleId(firebaseUser.uid);
      
      if (existingUser != null) {
        // Mevcut kullanıcı - giriş yap
        return existingUser;
      } else {
        // 🆕 Cloud Save Check (Bulutta var mı?)
        final cloudUser = await CloudService().getUserByGoogleId(firebaseUser.uid);
        
        if (cloudUser != null) {
          // Bulutta bulundu! Restore et
          await DatabaseHelper().insertUser(cloudUser.toJson());
          
          // Araçları da restore et
          final vehicles = await CloudService().getUserVehicles(cloudUser.id);
          for (var vehicle in vehicles) {
            await DatabaseHelper().addUserVehicle(vehicle);
          }
          
          return cloudUser;
        }
        
        // Yeni kullanıcı - kayıt oluştur
        final newUser = await _createGoogleUser(firebaseUser);
        return newUser;
      }
      
    } catch (e) {
      print("GOOGLE SIGN IN ERROR: $e");
      return null;
    }
  }

  /// Google kullanıcı ID'sine göre local database'de kullanıcı ara
  Future<User?> _findUserByGoogleId(String googleUserId) async {
    try {
      final usersMapList = await DatabaseHelper().getAllUsers();
      
      for (var userMap in usersMapList) {
        if (userMap['googleUserId'] == googleUserId) {
          return User.fromJson(userMap);
        }
      }
      
      return null;
    } catch (e) {
      
      return null;
    }
  }

  /// Google bilgilerinden yeni kullanıcı oluştur
  Future<User> _createGoogleUser(firebase_auth.User firebaseUser) async {
    try {
      // Google'dan gelen bilgilerle kullanıcı oluştur
      final newUser = User(
        id: const Uuid().v4(),
        username: firebaseUser.displayName ?? firebaseUser.email?.split('@')[0] ?? 'GoogleUser',
        password: '', // Google ile giriş için şifre gerekmez
        registeredAt: DateTime.now(),
        balance: 1000000.0, // Başlangıç parası
        profitLossPercentage: 0.0,
        profileImageUrl: firebaseUser.photoURL,
        currency: 'TL',
        authProvider: 'google',
        googleUserId: firebaseUser.uid,
        email: firebaseUser.email,
      );

      // Local database'e kaydet
      await DatabaseHelper().insertUser(newUser.toJson());
      
      
      return newUser;
      
    } catch (e) {
      
      rethrow;
    }
  }

  /// Google'dan çıkış yap
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      await _firebaseAuth.signOut();
      
    } catch (e) {
      
    }
  }

  /// Mevcut Firebase kullanıcısını al
  firebase_auth.User? getCurrentFirebaseUser() {
    return _firebaseAuth.currentUser;
  }

  /// Firebase kullanıcısı giriş yapmış mı?
  bool isSignedIn() {
    return _firebaseAuth.currentUser != null;
  }
  /// Apple ile giriş yap
  Future<User?> signInWithApple() async {
    try {
      // 1. Apple Sign-In akışını başlat
      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      // 2. OAuthCredential oluştur
      final firebase_auth.OAuthCredential credential = firebase_auth.OAuthProvider('apple.com').credential(
        idToken: appleCredential.identityToken,
        accessToken: appleCredential.authorizationCode,
      );

      // 3. Firebase'e giriş yap
      final firebase_auth.UserCredential userCredential = 
          await _firebaseAuth.signInWithCredential(credential);
      
      final firebase_auth.User? firebaseUser = userCredential.user;
      
      if (firebaseUser == null) {
        return null;
      }

      // 4. Kullanıcıyı local database'de kontrol et veya oluştur
      // Apple ID'ye göre ara
      final existingUser = await _findUserByAppleId(firebaseUser.uid);
      
      if (existingUser != null) {
        return existingUser;
      } else {
        // 🆕 Cloud Save Check (Bulutta var mı?)
        final cloudUser = await CloudService().getUserByAppleId(firebaseUser.uid);
        
        if (cloudUser != null) {
          // Bulutta bulundu! Restore et
          await DatabaseHelper().insertUser(cloudUser.toJson());
          
          // Araçları da restore et
          final vehicles = await CloudService().getUserVehicles(cloudUser.id);
          for (var vehicle in vehicles) {
            await DatabaseHelper().addUserVehicle(vehicle);
          }
          
          return cloudUser;
        }

        // Yeni kullanıcı oluştur
        final newUser = await _createAppleUser(firebaseUser, appleCredential);
        return newUser;
      }
    } catch (e) {
      print("Apple Sign In Error: $e");
      return null;
    }
  }

  /// Apple kullanıcı ID'sine göre local database'de kullanıcı ara
  Future<User?> _findUserByAppleId(String appleUserId) async {
    try {
      final usersMapList = await DatabaseHelper().getAllUsers();
      
      for (var userMap in usersMapList) {
        if (userMap['appleUserId'] == appleUserId) {
          return User.fromJson(userMap);
        }
      }
      
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Apple bilgilerinden yeni kullanıcı oluştur
  Future<User> _createAppleUser(
      firebase_auth.User firebaseUser, AuthorizationCredentialAppleID appleCredential) async {
    try {
      String displayName = '';
      if (appleCredential.givenName != null && appleCredential.familyName != null) {
        displayName = '${appleCredential.givenName} ${appleCredential.familyName}';
      } else if (firebaseUser.displayName != null && firebaseUser.displayName!.isNotEmpty) {
        displayName = firebaseUser.displayName!;
      }
      
      // Eğer isim hala boşsa veya "Apple User" ise ve email varsa, email'in baş kısmını kullan
      if ((displayName.isEmpty || displayName == 'Apple User') && firebaseUser.email != null) {
        // Private relay email kontrolü
        if (firebaseUser.email!.contains('privaterelay.appleid.com')) {
          displayName = 'Apple User';
        } else {
          displayName = firebaseUser.email!.split('@')[0];
        }
      } else if (displayName.isEmpty) {
        displayName = 'Apple User';
      }

      final newUser = User(
        id: firebaseUser.uid,
        username: displayName,
        password: '', // Şifre yok (Apple ile giriş)
        registeredAt: DateTime.now(),
        balance: 1000000.0, // Başlangıç parası
        level: 1,
        xp: 0,
        // garageLimit: 3, // Varsayılan değer (User modelinden gelir)
        authProvider: 'apple',
        appleUserId: appleCredential.userIdentifier,
        email: firebaseUser.email,
      );

      await DatabaseHelper().insertUser(newUser.toJson()); // Assuming DatabaseHelper().insertUser still takes a map
      return newUser;
    } catch (e) {
      rethrow;
    }
  }
}

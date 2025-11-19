import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:google_sign_in/google_sign_in.dart';
import '../models/user_model.dart';
import 'database_helper.dart';
import 'package:uuid/uuid.dart';

class FirebaseAuthService {
  static final FirebaseAuthService _instance = FirebaseAuthService._internal();
  factory FirebaseAuthService() => _instance;
  FirebaseAuthService._internal();

  final firebase_auth.FirebaseAuth _firebaseAuth = firebase_auth.FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    // iOS için CLIENT_ID manuel olarak belirtilmeli
    clientId: '585097479960-jd9clpbd09ttok1lgienfbaaedqofv9c.apps.googleusercontent.com',
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
        // Yeni kullanıcı - kayıt oluştur
        final newUser = await _createGoogleUser(firebaseUser);
        return newUser;
      }
      
    } catch (e) {
      
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
        gender: 'Erkek', // Varsayılan (kullanıcı daha sonra değiştirebilir)
        birthDate: DateTime(1990, 1, 1), // Varsayılan (kullanıcı daha sonra değiştirebilir)
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
}


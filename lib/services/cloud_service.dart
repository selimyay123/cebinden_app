import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../models/user_vehicle_model.dart';

class CloudService {
  static final CloudService _instance = CloudService._internal();
  factory CloudService() => _instance;
  CloudService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String usersCollection = 'users';
  static const String vehiclesCollection = 'vehicles';

  // ============================================================================
  // USER OPERATIONS
  // ============================================================================

  /// Kullanıcıyı Firestore'a kaydet (Full Sync)
  Future<void> saveUser(User user) async {
    try {
      await _firestore.collection(usersCollection).doc(user.id).set(user.toJson());
    } catch (e) {
      print('Cloud Save Error (User): $e');
      // Hata fırlatma, sessizce devam et (Offline olabilir)
    }
  }

  /// Google ID'ye göre kullanıcı bul
  Future<User?> getUserByGoogleId(String googleId) async {
    try {
      final querySnapshot = await _firestore
          .collection(usersCollection)
          .where('googleUserId', isEqualTo: googleId)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        return User.fromJson(querySnapshot.docs.first.data());
      }
      return null;
    } catch (e) {
      print('Cloud Fetch Error (Google): $e');
      return null;
    }
  }

  /// Apple ID'ye göre kullanıcı bul
  Future<User?> getUserByAppleId(String appleId) async {
    try {
      final querySnapshot = await _firestore
          .collection(usersCollection)
          .where('appleUserId', isEqualTo: appleId)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        return User.fromJson(querySnapshot.docs.first.data());
      }
      return null;
    } catch (e) {
      print('Cloud Fetch Error (Apple): $e');
      return null;
    }
  }

  // ============================================================================
  // VEHICLE OPERATIONS
  // ============================================================================

  /// Aracı Firestore'a kaydet
  /// Araçlar users/{userId}/vehicles/{vehicleId} altında saklanır
  Future<void> saveVehicle(UserVehicle vehicle) async {
    try {
      await _firestore
          .collection(usersCollection)
          .doc(vehicle.userId)
          .collection(vehiclesCollection)
          .doc(vehicle.id)
          .set(vehicle.toJson());
    } catch (e) {
      print('Cloud Save Error (Vehicle): $e');
    }
  }

  /// Aracı Firestore'dan sil
  Future<void> deleteVehicle(String userId, String vehicleId) async {
    try {
      await _firestore
          .collection(usersCollection)
          .doc(userId)
          .collection(vehiclesCollection)
          .doc(vehicleId)
          .delete();
    } catch (e) {
      print('Cloud Delete Error (Vehicle): $e');
    }
  }

  /// Kullanıcının tüm araçlarını getir
  Future<List<UserVehicle>> getUserVehicles(String userId) async {
    try {
      final querySnapshot = await _firestore
          .collection(usersCollection)
          .doc(userId)
          .collection(vehiclesCollection)
          .get();

      return querySnapshot.docs
          .map((doc) => UserVehicle.fromJson(doc.data()))
          .toList();
    } catch (e) {
      print('Cloud Fetch Error (Vehicles): $e');
      return [];
    }
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'auth_service.dart';

class AdminService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthService _authService = AuthService();

  // Koleksiyon adı
  static const String _reportsCollection = 'reports';

  // Bekleyen raporları getir
  Stream<QuerySnapshot> getPendingReports() {
    return _firestore
        .collection(_reportsCollection)
        .where('status', isEqualTo: 'pending')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  // Raporu çözüldü olarak işaretle
  Future<bool> resolveReport(String reportId) async {
    try {
      await _firestore.collection(_reportsCollection).doc(reportId).update({
        'status': 'resolved',
        'resolvedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      return false;
    }
  }

  // Raporu reddet (yoksay)
  Future<bool> dismissReport(String reportId) async {
    try {
      await _firestore.collection(_reportsCollection).doc(reportId).update({
        'status': 'dismissed',
        'dismissedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      return false;
    }
  }

  // Kullanıcıyı yasakla ve ilgili raporu çözüldü işaretle
  Future<bool> banUserAndResolveReport({
    required String userId,
    required String reportId,
  }) async {
    try {
      // 1. Kullanıcıyı yasakla
      final banSuccess = await _authService.banUser(userId);
      if (!banSuccess) return false;

      // 2. Raporu çözüldü işaretle
      await resolveReport(reportId);

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Kullanıcı adına göre altın ata (pendingGold olarak)
  /// saveUser() tarafından ezilmemesi için ayrı bir alan kullanıyoruz
  Future<Map<String, String>?> assignGold(String query, double amount) async {
    try {
      debugPrint('🔍 Altın atama: "$query" için $amount altın aranıyor...');

      // 1. Önce ID (Document ID) ile ara
      var userDoc = await _firestore.collection('users').doc(query).get();
      QuerySnapshot? querySnapshot;

      if (!userDoc.exists) {
        // 2. ID ile bulunamadıysa Username ile ara
        querySnapshot = await _firestore
            .collection('users')
            .where('username', isEqualTo: query)
            .limit(1)
            .get();

        // 3. Bulunamazsa Email ile ara
        if (querySnapshot.docs.isEmpty) {
          debugPrint('ℹ️ Username ile bulunamadı, email ile deneniyor...');
          querySnapshot = await _firestore
              .collection('users')
              .where('email', isEqualTo: query)
              .limit(1)
              .get();
        }

        if (querySnapshot.docs.isEmpty) {
          debugPrint('❌ Kullanıcı bulunamadı: $query');
          return null;
        }
        userDoc =
            querySnapshot.docs.first as DocumentSnapshot<Map<String, dynamic>>;
      }

      final data = userDoc.data() as Map<String, dynamic>;
      final foundUsername = data['username'] as String? ?? 'Unknown';
      final foundEmail = data['email'] as String? ?? 'No Email';
      final userId = userDoc.id;

      debugPrint(
        '✅ Kullanıcı bulundu: $foundUsername ($foundEmail) [$userId]. pendingGold artırılıyor...',
      );

      // pendingGold alanını artır
      await _firestore.collection('users').doc(userId).set({
        'pendingGold': FieldValue.increment(amount),
      }, SetOptions(merge: true));

      debugPrint('🚀 Altın başarıyla pendingGold olarak tanımlandı.');

      return {'username': foundUsername, 'email': foundEmail, 'userId': userId};
    } catch (e) {
      debugPrint('🔥 assignGold Hatası: $e');
      return null;
    }
  }

  /// Bekleyen altını talep et (Uygulama açılışında çağrılır)
  Future<double> claimPendingGold(String userId) async {
    try {
      debugPrint('📡 Firestore bekleyen altın kontrolü: $userId');
      final docRef = _firestore.collection('users').doc(userId);
      final doc = await docRef.get();

      if (!doc.exists) {
        debugPrint('ℹ️ Firestore dökümanı bulunamadı.');
        return 0;
      }

      final data = doc.data()!;
      final pendingGold = (data['pendingGold'] as num?)?.toDouble() ?? 0;

      if (pendingGold > 0) {
        debugPrint('💰 $pendingGold bekleyen altın bulundu!');
        // pendingGold'u sıfırla
        await docRef.update({'pendingGold': 0});
        debugPrint('🧹 pendingGold temizlendi.');
      } else {
        debugPrint('ℹ️ Bekleyen altın yok (0).');
      }

      return pendingGold;
    } catch (e) {
      debugPrint('🔥 claimPendingGold Hatası: $e');
      return 0;
    }
  }
}

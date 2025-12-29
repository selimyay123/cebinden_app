import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

class ReportService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Uuid _uuid = const Uuid();

  // Koleksiyon adı
  static const String _collection = 'reports';

  /// Bir kullanıcıyı raporla
  Future<bool> reportUser({
    required String reporterId,
    required String reportedUserId,
    required String reportedUsername,
    required String reason,
    String? description,
  }) async {
    try {
      final reportId = _uuid.v4();
      final now = DateTime.now();

      await _firestore.collection(_collection).doc(reportId).set({
        'id': reportId,
        'reporterId': reporterId,
        'reportedUserId': reportedUserId,
        'reportedUsername': reportedUsername,
        'reason': reason,
        'description': description,
        'status': 'pending', // pending, reviewed, resolved, dismissed
        'createdAt': now.toIso8601String(),
        'timestamp': FieldValue.serverTimestamp(),
      });

      return true;
    } catch (e) {
      print('Error reporting user: $e');
      return false;
    }
  }
  /// Kullanıcının daha önce raporlayıp raporlamadığını kontrol et
  Future<bool> hasReported(String reporterId, String reportedUserId) async {
    try {
      final querySnapshot = await _firestore
          .collection(_collection)
          .where('reporterId', isEqualTo: reporterId)
          .where('reportedUserId', isEqualTo: reportedUserId)
          .limit(1)
          .get();

      return querySnapshot.docs.isNotEmpty;
    } catch (e) {
      print('Error checking report status: $e');
      return false;
    }
  }
}

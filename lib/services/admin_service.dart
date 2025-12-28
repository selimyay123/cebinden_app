import 'package:cloud_firestore/cloud_firestore.dart';
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
      print('Error resolving report: $e');
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
      print('Error dismissing report: $e');
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
      print('Error banning user and resolving report: $e');
      return false;
    }
  }
}

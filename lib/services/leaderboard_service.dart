import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class LeaderboardService {
  static final LeaderboardService _instance = LeaderboardService._internal();
  factory LeaderboardService() => _instance;
  LeaderboardService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String collectionName = 'leaderboard';

  /// Kullanıcı skorunu Firestore'a günceller
  Future<void> updateUserScore(User user) async {
    try {
      // Sadece gerekli alanları gönderiyoruz
      final userData = {
        'userId': user.id,
        'username': user.username,
        'balance': user.balance,
        'profileImageUrl': user.profileImageUrl,
        'level': user.level,
        'isVip': user.isVip,
        'email': user.email, // E-posta adresini de ekle (filtreleme için)
        'lastUpdated': FieldValue.serverTimestamp(),
      };

      // Kullanıcı ID'sini belge ID'si olarak kullanıyoruz, böylece her kullanıcının tek bir kaydı olur
      await _firestore
          .collection(collectionName)
          .doc(user.id)
          .set(userData, SetOptions(merge: true));
    } catch (e) {
      // Hata durumunda sessizce devam et, kullanıcı deneyimini bozma
    }
  }

  /// Kullanıcı skorunu siler (Hesap silme durumunda)
  Future<void> deleteUserScore(String userId) async {
    try {
      await _firestore.collection(collectionName).doc(userId).delete();
      // ignore: empty_catches
    } catch (e) {}
  }

  /// En zengin ilk N kullanıcıyı getirir
  Future<List<Map<String, dynamic>>> getTopPlayers({int limit = 100}) async {
    try {
      final querySnapshot = await _firestore
          .collection(collectionName)
          .orderBy('balance', descending: true)
          .limit(limit + 5) // Filtreleme ihtimaline karşı biraz fazla çek
          .get();

      return querySnapshot.docs
          .map((doc) => doc.data())
          .where(
            (data) =>
                data['email'] != 'selimyay123@gmail.com' &&
                data['email'] != 'caneryokusm@gmail.com',
          ) // Test hesabını gizle
          .take(limit)
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Kullanıcının kendi sıralamasını getirir (Opsiyonel, maliyetli olabilir)
  /// Not: Büyük veri setlerinde bu işlem için farklı bir yaklaşım (örn: Cloud Functions) gerekebilir.
  /// Şimdilik basit bir implementasyon yapıyoruz.
  Future<int?> getUserRank(String userId) async {
    try {
      // Bu basit yöntem çok sayıda kullanıcıda performans sorunu yaratabilir
      // Ancak MVP için yeterli olacaktır.
      // Daha iyi bir yöntem: Kullanıcının balance'ından yüksek olanların sayısını (count) almak.

      final userDoc = await _firestore
          .collection(collectionName)
          .doc(userId)
          .get();
      if (!userDoc.exists) return null;

      final userBalance = userDoc.data()?['balance'] as double? ?? 0;

      final countQuery = await _firestore
          .collection(collectionName)
          .where('balance', isGreaterThan: userBalance)
          .count()
          .get();

      return (countQuery.count ?? 0) + 1;
    } catch (e) {
      return null;
    }
  }
}

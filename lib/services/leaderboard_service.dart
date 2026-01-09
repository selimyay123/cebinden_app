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
        'lastUpdated': FieldValue.serverTimestamp(),
      };

      // Kullanıcı ID'sini belge ID'si olarak kullanıyoruz, böylece her kullanıcının tek bir kaydı olur
      await _firestore.collection(collectionName).doc(user.id).set(userData, SetOptions(merge: true));
    } catch (e) {
      print('Error updating leaderboard score: $e');
      // Hata durumunda sessizce devam et, kullanıcı deneyimini bozma
    }
  }

  /// En zengin ilk N kullanıcıyı getirir
  Future<List<Map<String, dynamic>>> getTopPlayers({int limit = 10}) async {
    try {
      final querySnapshot = await _firestore
          .collection(collectionName)
          .orderBy('balance', descending: true)
          .limit(limit)
          .get();

      return querySnapshot.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      print('Error fetching leaderboard: $e');
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
      
      final userDoc = await _firestore.collection(collectionName).doc(userId).get();
      if (!userDoc.exists) return null;
      
      final userBalance = userDoc.data()?['balance'] as double? ?? 0;
      
      final countQuery = await _firestore
          .collection(collectionName)
          .where('balance', isGreaterThan: userBalance)
          .count()
          .get();
          
      return (countQuery.count ?? 0) + 1;
    } catch (e) {
      print('Error fetching user rank: $e');
      return null;
    }
  }
}

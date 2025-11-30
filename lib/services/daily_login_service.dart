import '../models/user_model.dart';
import 'database_helper.dart';

class DailyLoginService {
  final DatabaseHelper _db = DatabaseHelper();

  // Singleton pattern
  static final DailyLoginService _instance = DailyLoginService._internal();
  factory DailyLoginService() => _instance;
  DailyLoginService._internal();

  /// Günlük giriş ödülünü kontrol et
  /// Ödül alınabilir durumda mı ve kaçıncı gün?
  Future<Map<String, dynamic>> checkStreak(String userId) async {
    final userMap = await _db.getUserById(userId);
    if (userMap == null) return {'canClaim': false, 'streak': 1};
    final user = User.fromJson(userMap);

    final now = DateTime.now();
    final lastRewardDate = user.lastDailyRewardDate;

    // Hiç ödül alınmamışsa
    if (lastRewardDate == null) {
      return {'canClaim': true, 'streak': 1};
    }

    // Bugün ödül alınmış mı?
    if (_isSameDay(lastRewardDate, now)) {
      return {'canClaim': false, 'streak': user.consecutiveLoginDays};
    }

    // Dün ödül alınmış mı? (Streak devam ediyor mu?)
    if (_isConsecutiveDay(lastRewardDate, now)) {
      // Streak 7 günü geçtiyse başa dön (veya 7'de kal, isteğe bağlı. Burada 7 döngüsü yapalım)
      int nextStreak = user.consecutiveLoginDays + 1;
      if (nextStreak > 7) nextStreak = 1;
      
      return {'canClaim': true, 'streak': nextStreak};
    }

    // Streak bozulmuş, başa dön
    return {'canClaim': true, 'streak': 1};
  }

  /// Ödülü topla
  Future<bool> claimReward(String userId, {bool isDouble = false}) async {
    final status = await checkStreak(userId);
    if (!status['canClaim']) return false;

    final streak = status['streak'] as int;
    
    // Ödül miktarı: 7. gün 0.2 Gold, diğer günler 0.1 Gold
    double baseReward = (streak == 7) ? 0.2 : 0.1;
    
    // Reklam izlendiyse iki katı
    double finalReward = isDouble ? baseReward * 2 : baseReward;

    final userMap = await _db.getUserById(userId);
    if (userMap == null) return false;
    final user = User.fromJson(userMap);

    // User güncelle
    await _db.updateUser(userId, {
      'gold': user.gold + finalReward,
      'consecutiveLoginDays': streak,
      'lastDailyRewardDate': DateTime.now().toIso8601String(),
    });

    return true;
  }

  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }

  bool _isConsecutiveDay(DateTime lastDate, DateTime currentDate) {
    final difference = currentDate.difference(lastDate).inDays;
    return difference == 1 || (difference == 0 && lastDate.day != currentDate.day); // Gece yarısı geçişi için
  }
}

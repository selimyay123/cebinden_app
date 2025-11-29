import '../models/user_model.dart';
import 'database_helper.dart';

/// XP kazanım kaynakları
enum XPSource {
  vehiclePurchase,      // Araç satın alma
  vehicleSale,          // Araç satışı
  offerMade,            // Teklif gönderme
  offerAccepted,        // Teklif kabul edilmesi
  counterOfferSuccess,  // Başarılı karşı teklif
  dailyLogin,           // Günlük giriş bonusu
  profitBonus,          // Kâr bonusu
}

/// XP Kazanım Sonucu
class XPGainResult {
  final int xpGained;
  final int oldLevel;
  final int newLevel;
  final bool leveledUp;
  final LevelUpReward? rewards;
  
  XPGainResult({
    required this.xpGained,
    required this.oldLevel,
    required this.newLevel,
    required this.leveledUp,
    this.rewards,
  });
  
  factory XPGainResult.empty() => XPGainResult(
    xpGained: 0,
    oldLevel: 0,
    newLevel: 0,
    leveledUp: false,
  );
  
  bool get hasGain => xpGained > 0;
}

/// Seviye Atlama Ödülü
class LevelUpReward {
  final int level;
  final double cashBonus;
  final double goldBonus;
  final List<String> unlocks;
  
  LevelUpReward({
    required this.level,
    required this.cashBonus,
    required this.goldBonus,
    required this.unlocks,
  });
}

/// XP Yönetim Servisi
class XPService {
  final DatabaseHelper _db = DatabaseHelper();
  
  // XP Kazanma Miktarları (Ayarlanabilir)
  static const int XP_VEHICLE_PURCHASE = 50;
  static const int XP_VEHICLE_SALE = 100;
  static const int XP_OFFER_MADE = 10;
  static const int XP_OFFER_ACCEPTED = 30;
  static const int XP_COUNTER_OFFER_SUCCESS = 50;
  static const int XP_DAILY_LOGIN_BASE = 25;
  static const int XP_CONSECUTIVE_LOGIN_BONUS = 10; // Her ardışık gün için +10
  
  /// Kâr bazlı bonus XP hesapla
  /// Her 100,000 TL kâr için +10 XP (maksimum 200 XP)
  static int calculateProfitBonusXP(double profit) {
    if (profit > 0) {
      return ((profit / 100000).floor() * 10).clamp(0, 200);
    }
    return 0;
  }
  
  /// XP Ekle ve seviye kontrolü yap
  Future<XPGainResult> addXP(
    String userId,
    int xpAmount,
    XPSource source, {
    Map<String, dynamic>? additionalStats,
  }) async {
    final userMap = await _db.getUserById(userId);
    if (userMap == null) return XPGainResult.empty();
    final user = User.fromJson(userMap);
    
    final oldLevel = user.level;
    final newXP = user.xp + xpAmount;
    final newLevel = User.calculateLevel(newXP);
    final leveledUp = newLevel > oldLevel;
    
    // Güncellenecek alanlar
    final updates = <String, dynamic>{
      'xp': newXP,
      'level': newLevel,
    };
    
    // İstatistik güncellemeleri
    if (additionalStats != null) {
      updates.addAll(additionalStats);
    }
    
    // User'ı güncelle
    await _db.updateUser(userId, updates);
    
    // Seviye atlandıysa ödülleri hesapla ve ver
    LevelUpReward? rewards;
    if (leveledUp) {
      rewards = await _processLevelUpRewards(userId, newLevel);
    }
    
    return XPGainResult(
      xpGained: xpAmount,
      oldLevel: oldLevel,
      newLevel: newLevel,
      leveledUp: leveledUp,
      rewards: rewards,
    );
  }
  
  /// Seviye atlama ödüllerini işle ve kullanıcıya ver
  Future<LevelUpReward> _processLevelUpRewards(String userId, int newLevel) async {
    final userMap = await _db.getUserById(userId);
    if (userMap == null) {
      return LevelUpReward(level: newLevel, cashBonus: 0, goldBonus: 0, unlocks: []);
    }
    final user = User.fromJson(userMap);
    
    // Ödül miktarlarını hesapla
    final cashReward = newLevel * 50000.0; // Level 2 → 100k, Level 3 → 150k
    final goldReward = newLevel >= 5 ? (newLevel / 5).floor() * 0.05 : 0.0;
    
    // Ödülleri kullanıcıya ekle
    final newBalance = user.balance + cashReward;
    final newGold = user.gold + goldReward;
    
    await _db.updateUser(userId, {
      'balance': newBalance,
      'gold': newGold,
    });
    
    // Kilitleri aç
    final unlocks = _getUnlocksForLevel(newLevel);
    
    return LevelUpReward(
      level: newLevel,
      cashBonus: cashReward,
      goldBonus: goldReward,
      unlocks: unlocks,
    );
  }
  
  /// Seviye bazlı kilit açma özellikleri
  List<String> _getUnlocksForLevel(int level) {
    final unlocks = <String>[];
    
    if (level == 5) unlocks.add('xp.unlock.premiumVehicles');
    if (level == 10) unlocks.add('xp.unlock.advancedOffers');
    if (level == 15) unlocks.add('xp.unlock.autoSellBot');
    if (level == 25) unlocks.add('xp.unlock.vipStatus');
    if (level == 50) unlocks.add('xp.unlock.specialBadges');
    
    return unlocks;
  }
  
  /// Günlük giriş bonusunu kontrol et ve ver
  Future<XPGainResult> checkDailyLoginBonus(String userId) async {
    final userMap = await _db.getUserById(userId);
    if (userMap == null) return XPGainResult.empty();
    final user = User.fromJson(userMap);
    
    final now = DateTime.now();
    final lastLogin = user.lastLoginDate;
    
    // İlk giriş
    if (lastLogin == null) {
      await _db.updateUser(userId, {
        'lastLoginDate': now.toIso8601String(),
        'consecutiveLoginDays': 1,
      });
      return await addXP(userId, XP_DAILY_LOGIN_BASE, XPSource.dailyLogin);
    }
    
    // Aynı gün tekrar giriş (bonus yok)
    if (_isSameDay(lastLogin, now)) {
      return XPGainResult.empty();
    }
    
    // Ardışık gün kontrolü
    final isConsecutive = _isConsecutiveDay(lastLogin, now);
    final newStreak = isConsecutive ? user.consecutiveLoginDays + 1 : 1;
    
    await _db.updateUser(userId, {
      'lastLoginDate': now.toIso8601String(),
      'consecutiveLoginDays': newStreak,
    });
    
    // Bonus XP hesapla
    final bonusXP = (XP_DAILY_LOGIN_BASE + (newStreak * XP_CONSECUTIVE_LOGIN_BONUS)).toInt();
    
    return await addXP(userId, bonusXP, XPSource.dailyLogin);
  }
  
  /// Aynı gün mü kontrolü
  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year && 
           date1.month == date2.month && 
           date1.day == date2.day;
  }
  
  /// Ardışık gün mü kontrolü
  bool _isConsecutiveDay(DateTime lastDate, DateTime currentDate) {
    final difference = currentDate.difference(lastDate).inDays;
    return difference == 1;
  }
  
  /// Araç satın alma XP'si ver
  Future<XPGainResult> onVehiclePurchase(String userId) async {
    final userMap = await _db.getUserById(userId);
    if (userMap == null) return XPGainResult.empty();
    final user = User.fromJson(userMap);
    
    return await addXP(
      userId,
      XP_VEHICLE_PURCHASE,
      XPSource.vehiclePurchase,
      additionalStats: {
        'totalVehiclesBought': user.totalVehiclesBought + 1,
      },
    );
  }
  
  /// Araç satışı XP'si ver (kâr bonusu dahil)
  Future<XPGainResult> onVehicleSale(String userId, double profit) async {
    final userMap = await _db.getUserById(userId);
    if (userMap == null) return XPGainResult.empty();
    final user = User.fromJson(userMap);
    
    final profitBonus = calculateProfitBonusXP(profit);
    final totalXP = XP_VEHICLE_SALE + profitBonus;
    
    return await addXP(
      userId,
      totalXP,
      XPSource.vehicleSale,
      additionalStats: {
        'totalVehiclesSold': user.totalVehiclesSold + 1,
      },
    );
  }
  
  /// Teklif gönderme XP'si ver
  Future<XPGainResult> onOfferMade(String userId) async {
    final userMap = await _db.getUserById(userId);
    if (userMap == null) return XPGainResult.empty();
    final user = User.fromJson(userMap);
    
    return await addXP(
      userId,
      XP_OFFER_MADE,
      XPSource.offerMade,
      additionalStats: {
        'totalOffersMade': user.totalOffersMade + 1,
      },
    );
  }
  
  /// Teklif kabul edilmesi XP'si ver
  Future<XPGainResult> onOfferAccepted(String userId) async {
    return await addXP(userId, XP_OFFER_ACCEPTED, XPSource.offerAccepted);
  }
  
  /// Başarılı karşı teklif XP'si ver
  Future<XPGainResult> onCounterOfferSuccess(String userId) async {
    final userMap = await _db.getUserById(userId);
    if (userMap == null) return XPGainResult.empty();
    final user = User.fromJson(userMap);
    
    return await addXP(
      userId,
      XP_COUNTER_OFFER_SUCCESS,
      XPSource.counterOfferSuccess,
      additionalStats: {
        'successfulNegotiations': user.successfulNegotiations + 1,
      },
    );
  }
}


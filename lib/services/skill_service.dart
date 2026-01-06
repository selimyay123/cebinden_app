import 'dart:math';
import '../models/user_model.dart';
import '../models/vehicle_model.dart';
import 'database_helper.dart';
import 'game_time_service.dart';
import 'market_refresh_service.dart';

class SkillService {
  static final SkillService _instance = SkillService._internal();
  factory SkillService() => _instance;
  SkillService._internal();

  final DatabaseHelper _db = DatabaseHelper();
  final GameTimeService _gameTime = GameTimeService();

  // Yetenek ID'leri
  static const String skillQuickBuy = 'quick_buy';
  static const String skillQuickSell = 'quick_sell';
  static const String skillSweetTalk = 'sweet_talk';
  static const String skillLowballer = 'lowballer';
  static const String skillExpertiseExpert = 'expertise_expert';
  static const String skillTimeMaster = 'time_master';

  // Yetenek Tanımları
  static const Map<String, Map<String, dynamic>> skillDefinitions = {
    skillQuickBuy: {
      'maxLevel': 3,
      'costs': [1, 2, 3], // Seviye 1, 2, 3 maliyetleri
      'dailyLimit': 3,
    },
    skillQuickSell: {
      'maxLevel': 3,
      'costs': [1, 2, 3],
      'dailyLimit': 3,
    },
    skillSweetTalk: {
      'maxLevel': 3,
      'costs': [1, 2, 3],
    },
    skillLowballer: {
      'maxLevel': 3,
      'costs': [1, 2, 3],
    },
    skillExpertiseExpert: {
      'maxLevel': 1,
      'costs': [1],
      'dailyLimit': 3,
    },
    skillTimeMaster: {
      'maxLevel': 1,
      'costs': [1],
      'dailyLimit': 99, // Unlimited effectively
    },
  };

  // Tatlı Dil Bonusu
  static const Map<int, double> sweetTalkBonuses = {
    1: 0.05, // %5
    2: 0.10, // %10
    3: 0.15, // %15
  };

  // Ölücü Bonusu
  static const Map<int, double> lowballerBonuses = {
    1: 0.05, // %5
    2: 0.10, // %10
    3: 0.15, // %15
  };

  // Hızlı Sat Kar Marjları
  static const Map<int, double> quickSellMargins = {
    1: 0.03, // %3
    2: 0.04, // %4
    3: 0.05, // %5
  };

  /// Kullanıcının yetenek seviyesini getir
  int getSkillLevel(User user, String skillId) {
    return user.skills[skillId] ?? 0;
  }

  /// Yeteneği yükselt
  Future<bool> upgradeSkill(String userId, String skillId) async {
    final userMap = await _db.getUserById(userId);
    if (userMap == null) return false;
    final user = User.fromJson(userMap);

    final currentLevel = getSkillLevel(user, skillId);
    final def = skillDefinitions[skillId];
    if (def == null) return false;

    final maxLevel = def['maxLevel'] as int;
    if (currentLevel >= maxLevel) return false;

    final costs = def['costs'] as List<int>;
    final cost = costs[currentLevel]; // currentLevel 0 ise index 0 (1. seviye maliyeti)

    if (user.skillPoints < cost) return false;

    // Yeni yetenek haritası
    final newSkills = Map<String, int>.from(user.skills);
    newSkills[skillId] = currentLevel + 1;

    // Kullanıcıyı güncelle
    final updatedUser = user.copyWith(
      skillPoints: user.skillPoints - cost,
      skills: newSkills,
    );

    await _db.updateUser(userId, updatedUser.toJson());
    return true;
  }

  /// Yetenek kullanılabilir mi? (Günlük limit kontrolü)
  bool canUseSkill(User user, String skillId) {
    final currentLevel = getSkillLevel(user, skillId);
    if (currentLevel == 0) return false;

    final def = skillDefinitions[skillId];
    if (def == null) return false;

    final dailyLimit = def['dailyLimit'] as int;
    
    // Gün kontrolü
    if (user.lastSkillUseDay != _gameTime.currentDay) {
      return true; // Farklı gün (yeni veya resetlenmiş), limit sıfırlandı
    }

    final usageCount = user.dailySkillUses[skillId] ?? 0;
    return usageCount < dailyLimit;
  }

  /// Yetenek kullanımını kaydet
  Future<void> recordSkillUsage(String userId, String skillId) async {
    final userMap = await _db.getUserById(userId);
    if (userMap == null) return;
    final user = User.fromJson(userMap);

    final currentDay = _gameTime.currentDay;
    Map<String, int> newDailyUses;

    if (user.lastSkillUseDay != currentDay) {
      // Farklı gün, sayaçları sıfırla
      newDailyUses = {skillId: 1};
    } else {
      // Aynı gün, sayacı artır
      newDailyUses = Map<String, int>.from(user.dailySkillUses);
      newDailyUses[skillId] = (newDailyUses[skillId] ?? 0) + 1;
    }

    final updatedUser = user.copyWith(
      dailySkillUses: newDailyUses,
      lastSkillUseDay: currentDay,
    );

    await _db.updateUser(userId, updatedUser.toJson());
  }

  /// Hızlı Al yeteneği için araç bul
  Future<Vehicle?> findQuickBuyVehicle(User user) async {
    final level = getSkillLevel(user, skillQuickBuy);
    if (level == 0) return null;

    int minScore, maxScore;

    switch (level) {
      case 1:
        minScore = 0;
        maxScore = 70;
        break;
      case 2:
        minScore = 50;
        maxScore = 85;
        break;
      case 3:
        minScore = 75;
        maxScore = 100;
        break;
      default:
        return null;
    }

    // MarketRefreshService'den aktif ilanları al
    final marketService = MarketRefreshService();
    final allListings = marketService.getActiveListings();
    
    final candidates = allListings.where((v) {
      // Skor aralığında olsun
      return v.score >= minScore && v.score <= maxScore;
    }).toList();

    if (candidates.isEmpty) return null;

    // Rastgele birini seç
    return candidates[Random().nextInt(candidates.length)];
  }
  
  /// Kalan kullanım hakkını getir
  int getRemainingDailyUses(User user, String skillId) {
    final def = skillDefinitions[skillId];
    if (def == null) return 0;
    
    final dailyLimit = def['dailyLimit'] as int;
    
    if (user.lastSkillUseDay != _gameTime.currentDay) {
      return dailyLimit;
    }
    
    final usage = user.dailySkillUses[skillId] ?? 0;
    return (dailyLimit - usage).clamp(0, dailyLimit);
  }

  /// Hızlı Satış fiyatını hesapla
  int calculateQuickSellPrice(User user, Vehicle vehicle) {
    final level = getSkillLevel(user, skillQuickSell);
    if (level == 0) return 0;

    final margin = quickSellMargins[level] ?? 0.0;
    // Araç fiyatı üzerinden kar marjı ekle
    // Not: Burada aracın piyasa değerini mi yoksa alış fiyatını mı baz alacağız?
    // Genelde "kar" dendiğinde alış fiyatı üzerine eklenir.
    // Ancak Vehicle modelinde purchasePrice yok (UserVehicle'da var).
    // Bu metod Vehicle alıyor ama UserVehicle olması daha mantıklı olabilir.
    // Şimdilik Vehicle.price (piyasa değeri) üzerinden hesaplayalım, çünkü "Hızlı Sat" genelde piyasa değerine yakın veya üstünde satmak demektir.
    // VEYA: Kullanıcı isteği "kar payı" diyor.
    // Eğer UserVehicle ise purchasePrice var.
    
    // Basitlik için: Piyasa değeri * (1 + margin)
    return (vehicle.price * (1 + margin)).round();
  }
}

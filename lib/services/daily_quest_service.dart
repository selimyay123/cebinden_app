import 'dart:math';
import '../models/daily_quest_model.dart';
import '../models/user_model.dart';
import 'database_helper.dart';
import 'xp_service.dart';

class DailyQuestService {
  final DatabaseHelper _db = DatabaseHelper();
  final XPService _xpService = XPService();

  // Singleton pattern
  static final DailyQuestService _instance = DailyQuestService._internal();
  factory DailyQuestService() => _instance;
  DailyQuestService._internal();

  /// Kullanıcının günlük görevlerini kontrol et ve yoksa oluştur
  Future<List<DailyQuest>> checkAndGenerateQuests(String userId) async {
    final now = DateTime.now();
    
    // Bugüne ait görevleri getir
    final questsMap = await _db.getUserDailyQuests(userId, now);
    
    // Eğer görev varsa onları döndür
    if (questsMap.isNotEmpty) {
      return questsMap.map((map) => DailyQuest.fromJson(map)).toList();
    }
    
    // Görev yoksa yeni görevler oluştur
    final newQuests = _generateRandomQuests(userId);
    
    // Veritabanına kaydet
    for (var quest in newQuests) {
      await _db.addDailyQuest(quest.toJson());
    }
    
    return newQuests;
  }

  /// Rastgele 3 görev oluştur
  List<DailyQuest> _generateRandomQuests(String userId) {
    final quests = <DailyQuest>[];
    final random = Random();
    
    // Olası görev tipleri
    final possibleTypes = [
      QuestType.buyVehicle,
      QuestType.sellVehicle,
      QuestType.makeOffer,
      QuestType.earnProfit,
      // Login görevi her zaman sabit olabilir veya şansa bağlı
    ];
    
    // 3 farklı görev seç
    // 1. Görev: Araç Alım/Satım (Kolay)
    if (random.nextBool()) {
      quests.add(DailyQuest.create(
        userId: userId,
        type: QuestType.buyVehicle,
        description: "quests.descriptions.buyVehicle",
        targetCount: 2,
        rewardXP: 50,
        rewardMoney: 10000,
      ));
    } else {
      quests.add(DailyQuest.create(
        userId: userId,
        type: QuestType.sellVehicle,
        description: "quests.descriptions.sellVehicle",
        targetCount: 1,
        rewardXP: 50,
        rewardMoney: 15000,
      ));
    }
    
    // 2. Görev: Teklif/Pazarlık (Orta)
    quests.add(DailyQuest.create(
      userId: userId,
      type: QuestType.makeOffer,
      description: "quests.descriptions.makeOffer",
      targetCount: 5,
      rewardXP: 75,
      rewardMoney: 5000,
    ));
    
    // 3. Görev: Kar/Zorlu (Zor)
    quests.add(DailyQuest.create(
      userId: userId,
      type: QuestType.earnProfit,
      description: "quests.descriptions.earnProfit",
      targetCount: 200000, // Miktar olarak tutuyoruz
      rewardXP: 100,
      rewardMoney: 20000,
    ));
    
    return quests;
  }

  /// Görev ilerlemesini güncelle
  Future<void> updateProgress(String userId, QuestType type, int amount) async {
    final now = DateTime.now();
    final questsMap = await _db.getUserDailyQuests(userId, now);
    
    for (var questMap in questsMap) {
      final quest = DailyQuest.fromJson(questMap);
      
      // İlgili tipte ve tamamlanmamış/ödülü alınmamış görevleri bul
      if (quest.type == type && !quest.isClaimed && !quest.isCompleted) {
        final newCount = quest.currentCount + amount;
        
        // Güncelle
        await _db.updateDailyQuest(quest.id, {
          'currentCount': newCount,
        });
      }
    }
  }

  /// Ödülü topla
  Future<bool> claimReward(String userId, String questId) async {
    final questMap = await _db.getDailyQuestById(questId);
    if (questMap == null) return false;
    
    final quest = DailyQuest.fromJson(Map<String, dynamic>.from(questMap));
    
    if (quest.isClaimed || !quest.isCompleted) return false;
    
    // 1. XP Ver
    await _xpService.addXP(userId, quest.rewardXP, XPSource.dailyLogin); // Source'u genel tutabiliriz veya yeni source ekleyebiliriz
    
    // 2. Para Ver
    final userMap = await _db.getUserById(userId);
    if (userMap != null) {
      final user = User.fromJson(userMap);
      await _db.updateUser(userId, {
        'balance': user.balance + quest.rewardMoney,
      });
    }
    
    // 3. Görevi "Ödül Alındı" olarak işaretle
    await _db.updateDailyQuest(questId, {
      'isClaimed': true,
    });
    
    return true;
  }
}

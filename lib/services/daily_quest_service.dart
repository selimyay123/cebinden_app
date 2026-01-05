import 'dart:math';
import '../models/daily_quest_model.dart';
import '../models/user_model.dart';
import 'database_helper.dart';
import 'xp_service.dart';
import 'localization_service.dart';
import '../models/activity_model.dart';

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

  /// Bugünün görevlerini getir
  Future<List<DailyQuest>> getTodayQuests(String userId) async {
    final now = DateTime.now();
    final questsMap = await _db.getUserDailyQuests(userId, now);
    return questsMap.map((map) => DailyQuest.fromJson(map)).toList();
  }

  /// Rastgele 3 görev oluştur
  List<DailyQuest> _generateRandomQuests(String userId) {
    final quests = <DailyQuest>[];
    final random = Random();
    
    // Görev Şablonları Havuzu
    final templates = [
      // --- Araç Alma Görevleri ---
      _QuestTemplate(
        type: QuestType.buyVehicle,
        description: "quests.descriptions.buyVehicle",
        minCount: 1,
        maxCount: 1,
        baseXP: 50,
        baseMoney: 10000,
      ),
      _QuestTemplate(
        type: QuestType.buyVehicle,
        description: "quests.descriptions.buyVehicle",
        minCount: 2,
        maxCount: 3,
        baseXP: 100,
        baseMoney: 25000,
      ),
      
      // --- Araç Satma Görevleri ---
      _QuestTemplate(
        type: QuestType.sellVehicle,
        description: "quests.descriptions.sellVehicle",
        minCount: 1,
        maxCount: 1,
        baseXP: 50,
        baseMoney: 15000,
      ),
      _QuestTemplate(
        type: QuestType.sellVehicle,
        description: "quests.descriptions.sellVehicle",
        minCount: 2,
        maxCount: 3,
        baseXP: 120,
        baseMoney: 35000,
      ),
      
      // --- Teklif Verme Görevleri ---
      _QuestTemplate(
        type: QuestType.makeOffer,
        description: "quests.descriptions.makeOffer",
        minCount: 3,
        maxCount: 5,
        baseXP: 60,
        baseMoney: 5000,
      ),
      _QuestTemplate(
        type: QuestType.makeOffer,
        description: "quests.descriptions.makeOffer",
        minCount: 6,
        maxCount: 10,
        baseXP: 100,
        baseMoney: 12000,
      ),
      
      // --- Kar Etme Görevleri ---
      _QuestTemplate(
        type: QuestType.earnProfit,
        description: "quests.descriptions.earnProfit",
        minCount: 50000,
        maxCount: 100000,
        baseXP: 80,
        baseMoney: 15000,
        step: 10000, // Yuvarlak sayılar için
      ),
      _QuestTemplate(
        type: QuestType.earnProfit,
        description: "quests.descriptions.earnProfit",
        minCount: 150000,
        maxCount: 300000,
        baseXP: 150,
        baseMoney: 40000,
        step: 50000,
      ),
      // --- Marka Spesifik Araç Alma Görevleri ---
      _QuestTemplate(
        type: QuestType.buyVehicle,
        description: "quests.descriptions.buyVehicleBrand",
        minCount: 1,
        maxCount: 2,
        baseXP: 150,
        baseMoney: 30000,
        useBrand: true,
      ),
    ];
    
    // Havuzdan rastgele 3 farklı şablon seç
    // Şablonları karıştır
    templates.shuffle(random);
    
    // İlk 3 tanesini al (veya daha az varsa hepsini)
    final selectedTemplates = templates.take(3).toList();
    
    // Seçilen şablonlardan görevleri oluştur
    for (var template in selectedTemplates) {
      // Hedef sayıyı belirle (min-max arası)
      int targetCount;
      if (template.minCount == template.maxCount) {
        targetCount = template.minCount;
      } else {
        // Step varsa ona göre yuvarla (özellikle para miktarları için)
        if (template.step > 1) {
          final steps = (template.maxCount - template.minCount) ~/ template.step;
          targetCount = template.minCount + (random.nextInt(steps + 1) * template.step);
        } else {
          targetCount = template.minCount + random.nextInt(template.maxCount - template.minCount + 1);
        }
      }
      
      // Ödülleri zorluğa göre ölçekle (basit bir mantık)
      // Eğer maxCount'a yakınsa ödül biraz artabilir, şimdilik base değerleri kullanıyoruz
      // İleride buraya daha karmaşık formül eklenebilir.
      
      String? targetBrand;
      if (template.useBrand) {
        final brands = ['Renauva', 'Volkstar', 'Fialto', 'Oplon', 'Bavora', 'Fortran', 'Mercurion', 'Koyoro', 'Audira', 'Hanto'];
        targetBrand = brands[random.nextInt(brands.length)];
      }

      quests.add(DailyQuest.create(
        userId: userId,
        type: template.type,
        description: template.description,
        targetCount: targetCount,
        rewardXP: template.baseXP,
        rewardMoney: template.baseMoney.toDouble(),
        targetBrand: targetBrand,
      ));
    }
    
    return quests;
  }

  /// Görev ilerlemesini güncelle
  Future<void> updateProgress(String userId, QuestType type, int amount, {String? brand}) async {
    final now = DateTime.now();
    final questsMap = await _db.getUserDailyQuests(userId, now);
    
    for (var questMap in questsMap) {
      final quest = DailyQuest.fromJson(questMap);
      
      // İlgili tipte ve tamamlanmamış/ödülü alınmamış görevleri bul
      if (quest.type == type && !quest.isClaimed && !quest.isCompleted) {
        // Marka kontrolü
        if (quest.targetBrand != null && brand != null) {
          if (quest.targetBrand != brand) continue;
        } else if (quest.targetBrand != null && brand == null) {
          continue; // Marka gerektiren göreve markasız işlem sayılmaz
        }
        
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
    
    // 4. Aktivite Geçmişine Ekle
    await _db.addActivity(Activity.create(
      userId: userId,
      type: ActivityType.income,
      title: 'activity.dailyQuestTitle'.tr(),
      description: 'activity.rewardDesc'.trParams({
        'money': quest.rewardMoney.toStringAsFixed(0),
        'xp': quest.rewardXP.toString(),
      }),
      amount: quest.rewardMoney,
    ));
    
    return true;
  }
}

// Yardımcı sınıf: Görev Şablonu
class _QuestTemplate {
  final QuestType type;
  final String description;
  final int minCount;
  final int maxCount;
  final int baseXP;
  final int baseMoney;
  final int step; // Rastgele sayı üretirken adım aralığı (örn: 10000'er artış)
  final bool useBrand;

  _QuestTemplate({
    required this.type,
    required this.description,
    required this.minCount,
    required this.maxCount,
    required this.baseXP,
    required this.baseMoney,
    this.step = 1,
    this.useBrand = false,
  });
}

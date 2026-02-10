// ignore_for_file: unused_local_variable

import '../models/mission_model.dart';
import '../models/user_model.dart';
import 'database_helper.dart';
import 'xp_service.dart';
import 'localization_service.dart';
import '../models/activity_model.dart';

class MissionService {
  final DatabaseHelper _db = DatabaseHelper();
  final XPService _xpService = XPService();

  // Tüm Görevlerin Listesi
  final List<Mission> _allMissions = [
    Mission(
      id: 'mission_tutorial',
      type: MissionType.tutorial,
      titleKey: 'missions.tutorial.title',
      descriptionKey: 'missions.tutorial.desc',
      rewardXP: 100,
      rewardMoney: 5000,
      targetValue: 1,
    ),
    Mission(
      id: 'mission_first_buy',
      type: MissionType.firstBuy,
      titleKey: 'missions.firstBuy.title',
      descriptionKey: 'missions.firstBuy.desc',
      rewardXP: 150,
      rewardMoney: 10000,
      targetValue: 1,
    ),
    Mission(
      id: 'mission_first_sell',
      type: MissionType.firstSell,
      titleKey: 'missions.firstSell.title',
      descriptionKey: 'missions.firstSell.desc',
      rewardXP: 200,
      rewardMoney: 15000,
      targetValue: 1,
    ),
    Mission(
      id: 'mission_garage_5',
      type: MissionType.garageSize,
      titleKey: 'missions.garage5.title',
      descriptionKey: 'missions.garage5.desc',
      rewardXP: 300,
      rewardMoney: 25000,
      targetValue: 5,
    ),
    Mission(
      id: 'mission_balance_1m',
      type: MissionType.balance,
      titleKey: 'missions.balance1m.title',
      descriptionKey: 'missions.balance1m.desc',
      rewardXP: 500,
      rewardMoney: 50000,
      targetValue: 2000000, // Başlangıç 1M olduğu için 2M hedef
    ),
    Mission(
      id: 'mission_balance_5m',
      type: MissionType.balance,
      titleKey: 'missions.balance5m.title',
      descriptionKey: 'missions.balance5m.desc',
      rewardXP: 1000,
      rewardMoney: 100000,
      targetValue: 5000000,
    ),
    Mission(
      id: 'mission_balance_10m',
      type: MissionType.balance,
      titleKey: 'missions.balance10m.title',
      descriptionKey: 'missions.balance10m.desc',
      rewardXP: 2000,
      rewardMoney: 250000,
      targetValue: 10000000,
    ),
    Mission(
      id: 'mission_level_5',
      type: MissionType.level,
      titleKey: 'missions.level5.title',
      descriptionKey: 'missions.level5.desc',
      rewardXP: 400,
      rewardMoney: 30000,
      targetValue: 5,
    ),
    Mission(
      id: 'mission_level_10',
      type: MissionType.level,
      titleKey: 'missions.level10.title',
      descriptionKey: 'missions.level10.desc',
      rewardXP: 800,
      rewardMoney: 60000,
      targetValue: 10,
    ),
    Mission(
      id: 'mission_level_20',
      type: MissionType.level,
      titleKey: 'missions.level20.title',
      descriptionKey: 'missions.level20.desc',
      rewardXP: 1500,
      rewardMoney: 120000,
      targetValue: 20,
    ),
    Mission(
      id: 'mission_negotiation_10',
      type: MissionType.negotiation,
      titleKey: 'missions.negotiation10.title',
      descriptionKey: 'missions.negotiation10.desc',
      rewardXP: 350,
      rewardMoney: 20000,
      targetValue: 10,
    ),
    Mission(
      id: 'mission_negotiation_20',
      type: MissionType.negotiation,
      titleKey: 'missions.negotiation20.title',
      descriptionKey: 'missions.negotiation20.desc',
      rewardXP: 700,
      rewardMoney: 40000,
      targetValue: 20,
    ),
    Mission(
      id: 'mission_negotiation_50',
      type: MissionType.negotiation,
      titleKey: 'missions.negotiation50.title',
      descriptionKey: 'missions.negotiation50.desc',
      rewardXP: 1200,
      rewardMoney: 80000,
      targetValue: 50,
    ),
    Mission(
      id: 'mission_fleet_10',
      type: MissionType.fleet,
      titleKey: 'missions.fleet10.title',
      descriptionKey: 'missions.fleet10.desc',
      rewardXP: 600,
      rewardMoney: 60000,
      targetValue: 10,
    ),
    Mission(
      id: 'mission_fleet_20',
      type: MissionType.fleet,
      titleKey: 'missions.fleet20.title',
      descriptionKey: 'missions.fleet20.desc',
      rewardXP: 1200,
      rewardMoney: 120000,
      targetValue: 20,
    ),
    Mission(
      id: 'mission_fleet_50',
      type: MissionType.fleet,
      titleKey: 'missions.fleet50.title',
      descriptionKey: 'missions.fleet50.desc',
      rewardXP: 2500,
      rewardMoney: 250000,
      targetValue: 50,
    ),
    Mission(
      id: 'mission_gallery',
      type: MissionType.gallery,
      titleKey: 'missions.gallery.title',
      descriptionKey: 'missions.gallery.desc',
      rewardXP: 1000,
      rewardMoney: 100000,
      targetValue: 1,
    ),
    Mission(
      id: 'mission_collection_master',
      type: MissionType.collection,
      titleKey: 'missions.collectionMaster.title',
      descriptionKey: 'missions.collectionMaster.desc',
      rewardXP: 5000,
      rewardMoney: 500000,
      targetValue: 10, // Toplam 10 marka var
    ),
  ];

  /// Kullanıcının görev durumlarını getir
  Future<List<Mission>> getUserMissions(String userId) async {
    // 1. Kullanıcı bilgilerini al (İlerleme kontrolü için)
    final userMap = await _db.getUserById(userId);
    if (userMap == null) return [];
    final user = User.fromJson(userMap);
    final userVehicles = await _db.getUserVehicles(userId);

    // 2. DB'den kayıtlı görev durumlarını al
    final savedMissions = await _db.getUserMissions(userId);
    final savedMap = {for (var m in savedMissions) m['missionId']: m};

    List<Mission> result = [];

    // Zincirleme görev tanımları
    final Map<String, List<String>> missionChains = {
      'balance': [
        'mission_balance_1m',
        'mission_balance_5m',
        'mission_balance_10m',
      ],
      'level': ['mission_level_5', 'mission_level_10', 'mission_level_20'],
      'negotiation': [
        'mission_negotiation_10',
        'mission_negotiation_20',
        'mission_negotiation_50',
      ],
      'fleet': ['mission_fleet_10', 'mission_fleet_20', 'mission_fleet_50'],
    };

    // Zincirdeki görevleri işle
    Set<String> processedMissions = {};

    // 1. Zincirleri kontrol et
    missionChains.forEach((key, chain) {
      bool foundActive = false;

      for (int i = 0; i < chain.length; i++) {
        final missionId = chain[i];
        final mission = _allMissions.firstWhere((m) => m.id == missionId);
        processedMissions.add(missionId);

        bool isCompleted = false;
        bool isClaimed = false;

        if (savedMap.containsKey(missionId)) {
          final missionData = savedMap[missionId];
          if (missionData != null) {
            isCompleted = missionData['isCompleted'] == 1;
            isClaimed = missionData['isClaimed'] == 1;
          }
        }

        // Eğer bu görev henüz alınmamışsa veya tamamlanmamışsa, bunu göster ve zinciri durdur
        if (!isClaimed) {
          // Durum kontrolü
          if (!isCompleted) {
            isCompleted = _checkCompletion(user, userVehicles.length, mission);
            if (isCompleted) {
              _db.updateMissionProgress(userId, mission.id, true, false);
            }
          }

          result.add(
            mission.copyWith(
              isCompleted: isCompleted,
              isClaimed: isClaimed,
              currentValue: _calculateCurrentValue(
                user,
                userVehicles.length,
                mission,
              ),
            ),
          );
          foundActive = true;
          break; // Zincirin sonraki halkalarını gösterme
        }

        // Eğer son halka ise ve alınmışsa, yine de göster (tamamlandı olarak)
        if (i == chain.length - 1 && isClaimed) {
          result.add(
            mission.copyWith(
              isCompleted: true,
              isClaimed: true,
              currentValue:
                  mission.targetValue, // Tamamlandığı için hedef değere eşit
            ),
          );
        }
      }
    });

    // 2. Zincir dışındaki diğer görevleri ekle
    for (var mission in _allMissions) {
      if (processedMissions.contains(mission.id)) continue;

      bool isCompleted = false;
      bool isClaimed = false;

      if (savedMap.containsKey(mission.id)) {
        final missionData = savedMap[mission.id];
        if (missionData != null) {
          isCompleted = missionData['isCompleted'] == 1;
          isClaimed = missionData['isClaimed'] == 1;
        }
      }

      if (!isCompleted) {
        isCompleted = _checkCompletion(user, userVehicles.length, mission);
        if (isCompleted) {
          await _db.updateMissionProgress(userId, mission.id, true, false);
        }
      }

      result.add(
        mission.copyWith(
          isCompleted: isCompleted,
          isClaimed: isClaimed,
          currentValue: isCompleted
              ? mission.targetValue
              : _calculateCurrentValue(user, userVehicles.length, mission),
        ),
      );
    }

    return result;
  }

  /// Görev tamamlanma kontrolü
  bool _checkCompletion(User user, int vehicleCount, Mission mission) {
    switch (mission.type) {
      case MissionType.tutorial:
        return user.isTutorialCompleted;
      case MissionType.firstBuy:
        return user.totalVehiclesBought >= 1;
      case MissionType.firstSell:
        return user.totalVehiclesSold >= 1;
      case MissionType.garageSize:
        return user.garageLimit >= mission.targetValue;
      case MissionType.balance:
        return user.balance >= mission.targetValue;
      case MissionType.level:
        return user.level >= mission.targetValue;
      case MissionType.negotiation:
        return user.successfulNegotiations >= mission.targetValue;
      case MissionType.fleet:
        return vehicleCount >= mission.targetValue;
      case MissionType.gallery:
        return user.ownsGallery;
      case MissionType.collection:
        // Tüm markaların koleksiyonu tamamlandı mı?
        // Toplam 10 marka var: Renauva, Volkstar, Fialto, Oplon, Bavora, Fortran, Mercurion, Koyoro, Audira, Hanto
        return user.collectedBrandRewards.length >= mission.targetValue;
    }
  }

  /// Mevcut ilerleme değerini hesapla
  double _calculateCurrentValue(User user, int vehicleCount, Mission mission) {
    switch (mission.type) {
      case MissionType.tutorial:
        return user.isTutorialCompleted ? 1.0 : 0.0;
      case MissionType.firstBuy:
        return user.totalVehiclesBought.toDouble();
      case MissionType.firstSell:
        return user.totalVehiclesSold.toDouble();
      case MissionType.garageSize:
        return user.garageLimit.toDouble();
      case MissionType.balance:
        return user.balance;
      case MissionType.level:
        return user.level.toDouble();
      case MissionType.negotiation:
        return user.successfulNegotiations.toDouble();
      case MissionType.fleet:
        return vehicleCount.toDouble();
      case MissionType.gallery:
        return user.ownsGallery ? 1.0 : 0.0;
      case MissionType.collection:
        return user.collectedBrandRewards.length.toDouble();
    }
  }

  /// Ödül talep et
  Future<XPGainResult?> claimReward(String userId, String missionId) async {
    final missions = await getUserMissions(userId);
    final mission = missions.firstWhere(
      (m) => m.id == missionId,
      orElse: () => throw Exception('Mission not found'),
    );

    if (!mission.isCompleted || mission.isClaimed) return null;

    // Ödülleri ver
    final xpResult = await _xpService.addXP(
      userId,
      mission.rewardXP,
      XPSource.achievement,
    ); // XPSource.achievement eklenmeli

    final userMap = await _db.getUserById(userId);
    if (userMap != null) {
      final user = User.fromJson(userMap);
      await _db.updateUser(userId, {
        'balance': user.balance + mission.rewardMoney,
      });
    }

    // DB'yi güncelle
    await _db.updateMissionProgress(userId, missionId, true, true);

    // Aktivite Geçmişine Ekle
    await _db.addActivity(
      Activity.create(
        userId: userId,
        type: ActivityType.income,
        title: 'activity.oneTimeQuestTitle'.tr(),
        description: 'activity.rewardDesc'.trParams({
          'money': mission.rewardMoney.toStringAsFixed(0),
          'xp': mission.rewardXP.toString(),
        }),
        amount: mission.rewardMoney,
      ),
    );

    return xpResult;
  }
}

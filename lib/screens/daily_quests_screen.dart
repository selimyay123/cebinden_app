import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/daily_quest_model.dart';
import '../models/mission_model.dart';
import '../services/daily_quest_service.dart';
import '../services/mission_service.dart';
import '../services/database_helper.dart';
import '../services/localization_service.dart';
import 'main_screen.dart';

class DailyQuestsScreen extends StatefulWidget {
  const DailyQuestsScreen({super.key});

  @override
  State<DailyQuestsScreen> createState() => _DailyQuestsScreenState();
}

class _DailyQuestsScreenState extends State<DailyQuestsScreen> {
  final DailyQuestService _questService = DailyQuestService();
  final MissionService _missionService = MissionService();
  final DatabaseHelper _db = DatabaseHelper();
  
  List<DailyQuest> _quests = [];
  List<Mission> _missions = [];
  bool _isLoading = true;
  Map<String, dynamic>? _currentUser;

  @override
  void initState() {
    super.initState();
    _checkAndLoadQuests();
  }

  Future<void> _checkAndLoadQuests() async {
    setState(() => _isLoading = true);
    
    final user = await _db.getCurrentUser();
    if (user != null) {
      _currentUser = user;
      await _questService.checkAndGenerateQuests(_currentUser!['id']);
      _loadData();
    } else {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    if (_currentUser == null) {
      setState(() => _isLoading = false);
      return;
    }
    
    final quests = await _questService.getTodayQuests(_currentUser!['id']);
    final missions = await _missionService.getUserMissions(_currentUser!['id']);
    
    if (mounted) {
      setState(() {
        _quests = quests;
        _missions = missions;
        _isLoading = false;
      });
    }
  }

  Future<void> _claimReward(DailyQuest quest) async {
    if (_currentUser == null) return;

    final success = await _questService.claimReward(_currentUser!['id'], quest.id);
    if (success) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            elevation: 8,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            behavior: SnackBarBehavior.floating,
            content: Text(
              'quests.rewardClaimed'.trParams({
                'xp': quest.rewardXP.toString(),
                'money': quest.rewardMoney.toStringAsFixed(0),
              }),
            ),
            backgroundColor: Colors.green.withOpacity(0.8),
          ),
        );
        _loadData(); // Listeyi yenile
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            elevation: 8,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.red.withOpacity(0.8),
            content: Text('quests.claimFailed'.tr()),
          ),
        );
      }
    }
  }

  Future<void> _claimMissionReward(Mission mission) async {
    if (_currentUser == null) return;

    final success = await _missionService.claimReward(_currentUser!['id'], mission.id);
    if (success) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            elevation: 8,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            behavior: SnackBarBehavior.floating,
            content: Text(
              'quests.rewardClaimed'.trParams({
                'xp': mission.rewardXP.toString(),
                'money': mission.rewardMoney.toStringAsFixed(0),
              }),
            ),
            backgroundColor: Colors.green.withOpacity(0.8),
          ),
        );
        _loadData(); // Listeyi yenile
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          // title: Text('quests.title'.tr()),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Günlük'), // TODO: Çeviri eklenebilir
              Tab(text: 'Görevler'),
            ],
          ),
        ),
        body: Container(
          decoration: const BoxDecoration(
            image: DecorationImage(
              image: AssetImage('assets/images/general_bg.png'),
              fit: BoxFit.cover,
            ),
          ),
          child: TabBarView(
            children: [
              // 1. Sekme: Günlük Görevler
              _buildDailyQuestsList(),
              
              // 2. Sekme: Başarımlar / Görevler
              _buildMissionsList(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDailyQuestsList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    
    if (_quests.isEmpty) {
      return Center(child: Text('quests.noQuests'.tr()));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _quests.length,
      itemBuilder: (context, index) {
        final quest = _quests[index];
        return _buildQuestCard(quest);
      },
    );
  }

  Widget _buildMissionsList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_missions.isEmpty) {
      return Center(
        child: Text(
          'missions.noMissions'.tr(),
          style: const TextStyle(color: Colors.white70, fontSize: 16),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _missions.length,
      itemBuilder: (context, index) {
        return _buildMissionCard(_missions[index]);
      },
    );
  }

  Widget _buildQuestCard(DailyQuest quest) {
    final isCompleted = quest.isCompleted;
    final isClaimed = quest.isClaimed;
    final progress = quest.progress;

    return Card(
      color: Colors.white.withOpacity(0.7),
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                    child: Text(
                    _getLocalizedDescription(quest),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (isClaimed)
                  const Icon(Icons.check_circle, color: Colors.green)
                else if (isCompleted)
                  ElevatedButton(
                    onPressed: () => _claimReward(quest),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                    child: Text('quests.claimReward'.tr()),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(
                isCompleted ? Colors.green : Colors.blue,
              ),
              minHeight: 8,
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${quest.currentCount} / ${quest.targetCount}',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Row(
                  children: [
                    const Icon(Icons.star, size: 16, color: Colors.amber),
                    const SizedBox(width: 4),
                    Text(
                      '${quest.rewardXP} XP',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.amber,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '${quest.rewardMoney.toStringAsFixed(0)} TL',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMissionCard(Mission mission) {
    final isCompleted = mission.isCompleted;
    final isClaimed = mission.isClaimed;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: Colors.white.withOpacity(0.9),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isCompleted 
                        ? (isClaimed ? Colors.grey.withOpacity(0.2) : Colors.green.withOpacity(0.2))
                        : Colors.blue.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isCompleted ? Icons.check_circle : Icons.star,
                    color: isCompleted 
                        ? (isClaimed ? Colors.grey : Colors.green)
                        : Colors.blue,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        mission.titleKey.tr(),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isClaimed ? Colors.grey : Colors.black87,
                          decoration: isClaimed ? TextDecoration.lineThrough : null,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        mission.descriptionKey.tr(),
                        style: TextStyle(
                          fontSize: 14,
                          color: isClaimed ? Colors.grey : Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Ödüller
                Row(
                  children: [
                    const Icon(Icons.bolt, size: 16, color: Colors.orange),
                    const SizedBox(width: 4),
                    Text(
                      "+${mission.rewardXP} XP",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isClaimed ? Colors.grey : Colors.orange[800],
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Icon(Icons.monetization_on, size: 16, color: Colors.green),
                    const SizedBox(width: 4),
                    Text(
                      NumberFormat.currency(symbol: '₺', decimalDigits: 0).format(mission.rewardMoney),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isClaimed ? Colors.grey : Colors.green[700],
                      ),
                    ),
                  ],
                ),
                // Buton
                if (isClaimed)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check, size: 16, color: Colors.grey),
                        SizedBox(width: 4),
                        Text("Tamamlandı", style: TextStyle(color: Colors.grey, fontSize: 12)),
                      ],
                    ),
                  )
                else
                  ElevatedButton(
                    onPressed: isCompleted ? () => _claimMissionReward(mission) : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isCompleted ? Colors.green : Colors.grey.withOpacity(0.5),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.grey.withOpacity(0.3),
                      disabledForegroundColor: Colors.white.withOpacity(0.5),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text('quests.claimReward'.tr()),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _getLocalizedDescription(DailyQuest quest) {
    // Yeni sistem: Key ise çevir
    if (quest.description.startsWith('quests.')) {
      return quest.description.trParams({
        'count': quest.targetCount.toString(),
        'brand': quest.targetBrand ?? '',
        'amount': _formatCurrency(quest.targetCount.toDouble()),
      });
    }

    // Eski sistem: Hardcoded stringleri yakala ve çevir
    if (quest.description.contains('araç satın al')) {
      return 'quests.descriptions.buyVehicle'.trParams({'count': quest.targetCount.toString()});
    }
    if (quest.description.contains('araç sat')) {
      return 'quests.descriptions.sellVehicle'.trParams({'count': quest.targetCount.toString()});
    }
    if (quest.description.contains('teklif gönder')) {
      return 'quests.descriptions.makeOffer'.trParams({'count': quest.targetCount.toString()});
    }
    if (quest.description.contains('kâr et')) {
      return 'quests.descriptions.earnProfit'.trParams({'amount': _formatCurrency(quest.targetCount.toDouble())});
    }

    // Hiçbiri değilse olduğu gibi göster
    return quest.description;
  }

  String _formatCurrency(double amount) {
    final formatter = NumberFormat('#,###', 'tr_TR');
    return formatter.format(amount);
  }
}

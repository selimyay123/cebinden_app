import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/daily_quest_model.dart';
import '../services/daily_quest_service.dart';
import '../services/database_helper.dart';
import '../services/localization_service.dart';
import 'home_screen.dart';

class DailyQuestsScreen extends StatefulWidget {
  const DailyQuestsScreen({super.key});

  @override
  State<DailyQuestsScreen> createState() => _DailyQuestsScreenState();
}

class _DailyQuestsScreenState extends State<DailyQuestsScreen> {
  final DailyQuestService _questService = DailyQuestService();
  final DatabaseHelper _db = DatabaseHelper();
  
  List<DailyQuest> _quests = [];
  bool _isLoading = true;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _loadQuests();
  }

  Future<void> _loadQuests() async {
    setState(() => _isLoading = true);
    
    final user = await _db.getCurrentUser();
    if (user != null) {
      _currentUserId = user['id'];
      final quests = await _questService.checkAndGenerateQuests(_currentUserId!);
      setState(() {
        _quests = quests;
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _claimReward(DailyQuest quest) async {
    if (_currentUserId == null) return;

    final success = await _questService.claimReward(_currentUserId!, quest.id);
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
        _loadQuests(); // Listeyi yenile
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('quests.title'.tr()),
        actions: [
          IconButton(
            icon: const Icon(Icons.home),
            onPressed: () {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => const HomeScreen()),
                (route) => false,
              );
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _quests.isEmpty
              ? Center(child: Text('quests.noQuests'.tr()))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _quests.length,
                  itemBuilder: (context, index) {
                    final quest = _quests[index];
                    return _buildQuestCard(quest);
                  },
                ),
    );
  }

  Widget _buildQuestCard(DailyQuest quest) {
    final isCompleted = quest.isCompleted;
    final isClaimed = quest.isClaimed;
    final progress = quest.progress;

    return Card(
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

  String _getLocalizedDescription(DailyQuest quest) {
    // Yeni sistem: Key ise çevir
    if (quest.description.startsWith('quests.')) {
      return quest.description.trParams({
        'count': quest.targetCount.toString(),
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

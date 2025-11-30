import 'package:flutter/material.dart';
import '../models/daily_quest_model.dart';
import '../services/daily_quest_service.dart';
import '../services/database_helper.dart';

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
            content: Text(
              'Ödül Alındı! +${quest.rewardXP} XP, +${quest.rewardMoney.toStringAsFixed(0)} TL',
            ),
            backgroundColor: Colors.green,
          ),
        );
        _loadQuests(); // Listeyi yenile
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ödül alınamadı.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Günlük Görevler'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _quests.isEmpty
              ? const Center(child: Text('Bugün için görev bulunamadı.'))
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
                    quest.description,
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
                    child: const Text('Ödülü Al'),
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
}

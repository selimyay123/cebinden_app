import 'package:flutter/material.dart';
import '../services/localization_service.dart';
import '../services/skill_service.dart';
import '../services/database_helper.dart';
import '../models/user_model.dart';

class SkillTreeScreen extends StatefulWidget {
  const SkillTreeScreen({super.key});

  @override
  State<SkillTreeScreen> createState() => _SkillTreeScreenState();
}

class _SkillTreeScreenState extends State<SkillTreeScreen> {
  final DatabaseHelper _db = DatabaseHelper();
  final SkillService _skillService = SkillService();
  User? _currentUser;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final userMap = await _db.getCurrentUser();
    if (userMap != null) {
      if (mounted) {
        setState(() {
          _currentUser = User.fromJson(userMap);
          _isLoading = false;
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _upgradeSkill(String skillId) async {
    if (_currentUser == null) return;

    final success = await _skillService.upgradeSkill(_currentUser!.id, skillId);
    if (success) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('skills.upgradeSuccess'.tr())),
        );
      }
      await _loadUser(); // Refresh UI
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('skills.upgradeFailed'.tr())),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text('home.tasks'.tr()),
        backgroundColor: Colors.deepPurple.withOpacity(0.8),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/general_bg.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: SafeArea(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _currentUser == null
                  ? Center(child: Text('common.userNotFound'.tr()))
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Skill Points Header
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.deepPurple.withOpacity(0.9),
                                  Colors.deepPurpleAccent.withOpacity(0.9)
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.star,
                                    color: Colors.yellow,
                                    size: 32,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'skills.availablePoints'.tr(),
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 14,
                                      ),
                                    ),
                                    Text(
                                      '${_currentUser!.skillPoints}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 32,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),

                          Text(
                            'skills.activeSkills'.tr(),
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                              
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Quick Buy Skill Card
                          _buildSkillCard(
                            skillId: SkillService.skillQuickBuy,
                            title: 'skills.quickBuy'.tr(),
                            description: 'skills.quickBuyDesc'.tr(),
                            icon: Icons.flash_on,
                            color: Colors.orange,
                          ),
                          const SizedBox(height: 16),
                          // Quick Sell Skill Card
                          _buildSkillCard(
                            skillId: SkillService.skillQuickSell,
                            title: 'skills.quickSell'.tr(),
                            description: 'skills.quickSellDesc'.tr(),
                            icon: Icons.sell,
                            color: Colors.green,
                          ),
                          const SizedBox(height: 16),
                          // Sweet Talk Skill Card
                          _buildSkillCard(
                            skillId: SkillService.skillSweetTalk,
                            title: 'skills.sweetTalk'.tr(),
                            description: 'skills.sweetTalkDesc'.tr(),
                            icon: Icons.chat_bubble,
                            color: Colors.blue,
                          ),
                          const SizedBox(height: 16),
                          // Lowballer Skill Card
                          _buildSkillCard(
                            skillId: SkillService.skillLowballer,
                            title: 'skills.lowballer'.tr(),
                            description: 'skills.lowballerDesc'.tr(),
                            icon: Icons.trending_down,
                            color: Colors.red,
                          ),
                          const SizedBox(height: 16),
                          // Expertise Expert Skill Card
                          _buildSkillCard(
                            skillId: SkillService.skillExpertiseExpert,
                            title: 'skills.expertiseExpert'.tr(),
                            description: 'skills.expertiseExpertDesc'.tr(),
                            icon: Icons.fact_check,
                            color: Colors.indigo,
                          ),
                          const SizedBox(height: 16),
                          // Time Master Skill Card
                          _buildSkillCard(
                            skillId: SkillService.skillTimeMaster,
                            title: 'skills.timeMaster'.tr(),
                            description: 'skills.timeMasterDesc'.tr(),
                            icon: Icons.fast_forward,
                            color: Colors.purple,
                          ),
                        ],
                      ),
                    ),
        ),
      ),
    );
  }

  Widget _buildSkillCard({
    required String skillId,
    required String title,
    required String description,
    required IconData icon,
    required MaterialColor color,
  }) {
    final currentLevel = _skillService.getSkillLevel(_currentUser!, skillId);
    final def = SkillService.skillDefinitions[skillId]!;
    final maxLevel = def['maxLevel'] as int;
    final costs = def['costs'] as List<int>;
    
    final isMaxLevel = currentLevel >= maxLevel;
    final nextLevelCost = isMaxLevel ? 0 : costs[currentLevel];
    final canUpgrade = !isMaxLevel && _currentUser!.skillPoints >= nextLevelCost;

    return Card(
      elevation: 4,
      color: Colors.white.withOpacity(0.9),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color.shade700, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${'skills.level'.tr()} $currentLevel / $maxLevel',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              description,
              style: TextStyle(color: Colors.grey[700], height: 1.4),
            ),
            const SizedBox(height: 16),
            
            // Level Progress
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: currentLevel / maxLevel,
                backgroundColor: Colors.grey[200],
                valueColor: AlwaysStoppedAnimation<Color>(color),
                minHeight: 8,
              ),
            ),
            const SizedBox(height: 16),

            // Upgrade Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: canUpgrade ? () => _upgradeSkill(skillId) : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: color,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  disabledBackgroundColor: Colors.grey[300],
                  disabledForegroundColor: Colors.grey[500],
                ),
                child: Text(
                  isMaxLevel 
                    ? 'skills.maxLevel'.tr() 
                    : '${'skills.upgrade'.tr()} ($nextLevelCost SP)',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

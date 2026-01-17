import 'package:flutter/material.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import '../services/localization_service.dart';
import '../services/skill_service.dart';
import '../services/database_helper.dart';
import '../models/user_model.dart';

import '../widgets/modern_alert_dialog.dart';
import '../widgets/custom_snackbar.dart';
import '../widgets/modern_button.dart';

class SkillTreeScreen extends StatefulWidget {
  const SkillTreeScreen({super.key});

  @override
  State<SkillTreeScreen> createState() => _SkillTreeScreenState();
}

class _SkillTreeScreenState extends State<SkillTreeScreen> with SingleTickerProviderStateMixin {
  final DatabaseHelper _db = DatabaseHelper();
  final SkillService _skillService = SkillService();
  User? _currentUser;
  bool _isLoading = true;
  late AnimationController _starController;

  @override
  void initState() {
    super.initState();
    _loadUser();
    _starController = AnimationController(
      duration: const Duration(seconds: 10),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _starController.dispose();
    super.dispose();
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
          CustomSnackBar(
            content: Text('skills.upgradeSuccess'.tr()),
            backgroundColor: Colors.green,
          ),
        );
      }
      await _loadUser(); // Refresh UI
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          CustomSnackBar(
            content: Text('skills.upgradeFailed'.tr()),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showUpgradeConfirmation(String skillId, String title, int cost) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => ModernAlertDialog(
        title: 'skills.upgradeConfirmationTitle'.tr(),
        content: Text(
          'skills.upgradeConfirmationMessage'.trParams({
            'skill': title,
            'cost': cost.toString(),
          }),
        ),
        buttonText: 'common.confirm'.tr(),
        onPressed: () => Navigator.pop(context, true),
        secondaryButtonText: 'common.cancel'.tr(),
        onSecondaryPressed: () => Navigator.pop(context, false),
        icon: Icons.upgrade,
      ),
    );

    if (confirmed == true) {
      await _upgradeSkill(skillId);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text('home.tasks'.tr()),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.deepPurple.withOpacity(0.8), Colors.transparent],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
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
                  : Column(
                      children: [
                        _buildHeader(),
                        Expanded(
                          child: AnimationLimiter(
                            child: ListView(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                              children: AnimationConfiguration.toStaggeredList(
                                duration: const Duration(milliseconds: 375),
                                childAnimationBuilder: (widget) => SlideAnimation(
                                  horizontalOffset: 50.0,
                                  child: FadeInAnimation(
                                    child: widget,
                                  ),
                                ),
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 16),
                                    child: Text(
                                      'skills.activeSkills'.tr(),
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ),
                                  _buildTreeItem(
                                    skillId: SkillService.skillQuickBuy,
                                    title: 'skills.quickBuy'.tr(),
                                    description: 'skills.quickBuyDesc'.tr(),
                                    icon: Icons.flash_on,
                                    color: Colors.orange,
                                    isFirst: true,
                                  ),
                                  _buildTreeItem(
                                    skillId: SkillService.skillQuickSell,
                                    title: 'skills.quickSell'.tr(),
                                    description: 'skills.quickSellDesc'.tr(),
                                    icon: Icons.sell,
                                    color: Colors.green,
                                  ),
                                  _buildTreeItem(
                                    skillId: SkillService.skillSweetTalk,
                                    title: 'skills.sweetTalk'.tr(),
                                    description: 'skills.sweetTalkDesc'.tr(),
                                    icon: Icons.chat_bubble,
                                    color: Colors.blue,
                                  ),
                                  _buildTreeItem(
                                    skillId: SkillService.skillLowballer,
                                    title: 'skills.lowballer'.tr(),
                                    description: 'skills.lowballerDesc'.tr(),
                                    icon: Icons.trending_down,
                                    color: Colors.red,
                                  ),
                                  _buildTreeItem(
                                    skillId: SkillService.skillExpertiseExpert,
                                    title: 'skills.expertiseExpert'.tr(),
                                    description: 'skills.expertiseExpertDesc'.tr(),
                                    icon: Icons.fact_check,
                                    color: Colors.indigo,
                                  ),
                                  _buildTreeItem(
                                    skillId: SkillService.skillTimeMaster,
                                    title: 'skills.timeMaster'.tr(),
                                    description: 'skills.timeMasterDesc'.tr(),
                                    icon: Icons.fast_forward,
                                    color: Colors.purple,
                                    isLast: true,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.deepPurpleAccent.withOpacity(0.7),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          RotationTransition(
            turns: _starController,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.star,
                color: Colors.amber,
                size: 36,
              ),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'skills.availablePoints'.tr(),
                  style: TextStyle(
                    color: Colors.black.withOpacity(0.6),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                TweenAnimationBuilder<int>(
                  tween: IntTween(begin: 0, end: _currentUser!.skillPoints),
                  duration: const Duration(seconds: 1),
                  builder: (context, value, child) {
                    return Text(
                      value.toString(),
                      style: const TextStyle(
                        color: Colors.black87,
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTreeItem({
    required String skillId,
    required String title,
    required String description,
    required IconData icon,
    required MaterialColor color,
    bool isFirst = false,
    bool isLast = false,
  }) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tree Line Column
          SizedBox(
            width: 40,
            child: Column(
              children: [
                // Top Line
                Expanded(
                  child: isFirst
                      ? const SizedBox()
                      : Container(
                          width: 4,
                          color: Colors.white.withOpacity(0.3),
                        ),
                ),
                // Node Dot
                Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: color.withOpacity(0.6),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
                // Bottom Line
                Expanded(
                  child: isLast
                      ? const SizedBox()
                      : Container(
                          width: 4,
                          color: Colors.white.withOpacity(0.3),
                        ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Card
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: _buildSkillCard(
                skillId: skillId,
                title: title,
                description: description,
                icon: icon,
                color: color,
              ),
            ),
          ),
        ],
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

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.7),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            // Background Gradient Border Effect
            Positioned(
              top: 0,
              left: 0,
              bottom: 0,
              width: 6,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [color.shade300, color.shade700],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 16, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: color.withOpacity(0.3)),
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
                            const SizedBox(height: 4),
                            if (isMaxLevel)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Colors.amber, Colors.orange],
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'MASTERED',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1,
                                  ),
                                ),
                              )
                            else
                              Text(
                                '${'skills.level'.tr()} $currentLevel / $maxLevel',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
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
                    style: TextStyle(color: Colors.grey[700], height: 1.4, fontSize: 13),
                  ),
                  const SizedBox(height: 16),

                  // Progress Bar
                  Stack(
                    children: [
                      Container(
                        height: 12,
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      FractionallySizedBox(
                        widthFactor: currentLevel / maxLevel,
                        child: Container(
                          height: 12,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [color.shade300, color.shade600],
                            ),
                            borderRadius: BorderRadius.circular(6),
                            boxShadow: [
                              BoxShadow(
                                color: color.withOpacity(0.4),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Upgrade Button
                  ModernButton(
                    text: isMaxLevel
                        ? 'skills.maxLevel'.tr()
                        : '${'skills.upgrade'.tr()} ($nextLevelCost SP)',
                    onPressed: canUpgrade
                        ? () => _showUpgradeConfirmation(skillId, title, nextLevelCost)
                        : () {}, // Disabled action
                    color: isMaxLevel ? Colors.grey : color,
                    gradientColors: isMaxLevel
                        ? [Colors.grey.shade400, Colors.grey.shade600]
                        : [color.shade400, color.shade700],
                    height: 48,
                    // Disable button visually if not enough points or max level
                    textColor: Colors.white.withOpacity(canUpgrade || isMaxLevel ? 1.0 : 0.5),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

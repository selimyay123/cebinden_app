import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/skill_service.dart';
import '../services/database_helper.dart';
import '../services/localization_service.dart';

class SkillTreeScreen extends StatefulWidget {
  const SkillTreeScreen({Key? key}) : super(key: key);

  @override
  State<SkillTreeScreen> createState() => _SkillTreeScreenState();
}

class _SkillTreeScreenState extends State<SkillTreeScreen> with TickerProviderStateMixin, LocalizationMixin {
  final DatabaseHelper _databaseHelper = DatabaseHelper();
  User? _currentUser;
  bool _isLoading = true;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _loadUser();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _loadUser() async {
    setState(() => _isLoading = true);
    final userMap = await _databaseHelper.getCurrentUser();
    if (userMap != null) {
      _currentUser = User.fromJson(userMap);
    }
    setState(() => _isLoading = false);
  }

  Future<void> _unlockSkill(Skill skill) async {
    if (_currentUser == null) return;

    // Kontroller
    if (!SkillService.canUnlock(_currentUser!, skill.id)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('skills.cannotUnlock'.tr()),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Onay dialogu
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Text(skill.emoji, style: const TextStyle(fontSize: 28)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                skill.nameKey.tr(),
                style: const TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              skill.descKey.tr(),
              style: const TextStyle(fontSize: 15),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: skill.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: skill.primaryColor.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'skills.cost'.tr(),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Row(
                    children: [
                      const Icon(Icons.star, color: Colors.amber, size: 18),
                      const SizedBox(width: 4),
                      Text(
                        '${skill.cost} SP',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('common.cancel'.tr()),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: skill.primaryColor,
              foregroundColor: Colors.white,
            ),
            child: Text('skills.unlock'.tr()),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    // İşlem
    try {
      final newPoints = _currentUser!.skillPoints - skill.cost;
      final newSkills = List<String>.from(_currentUser!.unlockedSkills)..add(skill.id);

      // Veritabanını güncelle
      final success = await _databaseHelper.updateUser(_currentUser!.id, {
        'skillPoints': newPoints,
        'unlockedSkills': newSkills,
      });

      if (success) {
        // UI Güncelle
        await _loadUser();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${skill.emoji} ${skill.nameKey.tr()} ${'skills.unlocked'.tr()}'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('common.error'.tr())),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_currentUser == null) {
      return Scaffold(body: Center(child: Text('common.error'.tr())));
    }

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text('skills.title'.tr()),
        elevation: 0,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFFD700), Color(0xFFFFE55C)],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.amber.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                const Icon(Icons.star, size: 18, color: Colors.black87),
                const SizedBox(width: 6),
                Text(
                  '${_currentUser!.skillPoints} SP',
                  style: const TextStyle(
                    color: Colors.black87,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Info card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.blue, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'skills.info'.tr(),
                      style: const TextStyle(fontSize: 13, color: Colors.black87),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Skills grid
            Wrap(
              spacing: 16,
              runSpacing: 16,
              alignment: WrapAlignment.center,
              children: SkillService.skills.map((skill) => _buildSkillCard(skill)).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSkillCard(Skill skill) {
    final isUnlocked = _currentUser!.unlockedSkills.contains(skill.id);
    final canUnlock = !isUnlocked && SkillService.canUnlock(_currentUser!, skill.id);
    final isLocked = !isUnlocked && !canUnlock;

    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final pulseValue = canUnlock ? _pulseController.value : 0.0;
        
        return Transform.scale(
          scale: 1.0 + (pulseValue * 0.05),
          child: GestureDetector(
            onTap: () => isUnlocked ? null : _unlockSkill(skill),
            child: Container(
              width: 170,
              height: 220,
              decoration: BoxDecoration(
                gradient: isLocked
                    ? LinearGradient(
                        colors: [Colors.grey[300]!, Colors.grey[400]!],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : LinearGradient(
                        colors: [skill.primaryColor, skill.secondaryColor],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: (canUnlock ? skill.primaryColor : Colors.grey).withOpacity(0.3),
                    blurRadius: canUnlock ? 12 : 8,
                    offset: const Offset(0, 4),
                  ),
                ],
                border: canUnlock
                    ? Border.all(color: Colors.white, width: 3)
                    : null,
              ),
              child: Stack(
                children: [
                  // Content
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Emoji icon
                        Text(
                          skill.emoji,
                          style: TextStyle(
                            fontSize: 40,
                            color: isLocked ? Colors.black38 : Colors.white,
                          ),
                        ),
                        
                        const SizedBox(height: 12),
                        
                        // Name
                        Text(
                          skill.nameKey.tr(),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: isLocked ? Colors.black54 : Colors.white,
                          ),
                        ),
                        
                        const SizedBox(height: 8),
                        
                        // Description
                        Text(
                          skill.descKey.tr(),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10,
                            color: isLocked ? Colors.black45 : Colors.white.withOpacity(0.9),
                          ),
                        ),
                        
                        const Spacer(),
                        
                        // Cost or status
                        if (!isUnlocked)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(isLocked ? 0.3 : 0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.star,
                                  size: 14,
                                  color: isLocked ? Colors.black45 : Colors.white,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${skill.cost} SP',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: isLocked ? Colors.black54 : Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        
                        if (isUnlocked)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.check_circle, size: 16, color: Colors.white),
                                const SizedBox(width: 4),
                                Text(
                                  'skills.active'.tr(),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  
                  // Lock icon overlay
                  if (isLocked)
                    Positioned(
                      top: 12,
                      right: 12,
                      child: Icon(
                        Icons.lock,
                        color: Colors.black.withOpacity(0.3),
                        size: 24,
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

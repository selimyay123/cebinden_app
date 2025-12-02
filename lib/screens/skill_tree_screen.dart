import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/skill_service.dart';
import '../services/database_helper.dart';

class SkillTreeScreen extends StatefulWidget {
  const SkillTreeScreen({Key? key}) : super(key: key);

  @override
  State<SkillTreeScreen> createState() => _SkillTreeScreenState();
}

class _SkillTreeScreenState extends State<SkillTreeScreen> {
  final DatabaseHelper _databaseHelper = DatabaseHelper();
  User? _currentUser;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUser();
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
        const SnackBar(content: Text('Bu yeteneği açamazsınız! (Yetersiz puan veya ön koşul)')),
      );
      return;
    }

    // Onay kutusu
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${skill.name} Aç?'),
        content: Text(
          '${skill.description}\n\nBedel: ${skill.cost} Yetenek Puanı',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('AÇ'),
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
              content: Text('${skill.name} açıldı! 🎉'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e')),
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
      return const Scaffold(body: Center(child: Text('Kullanıcı bulunamadı')));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Yetenek Ağacı'),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.amber,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                const Icon(Icons.star, size: 16, color: Colors.black),
                const SizedBox(width: 4),
                Text(
                  '${_currentUser!.skillPoints} SP',
                  style: const TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildBranchSection('Tüccar (Trader)', 'trader', Colors.blue),
            const SizedBox(height: 24),
            _buildBranchSection('Uzman (Expert)', 'expert', Colors.purple),
            const SizedBox(height: 24),
            _buildBranchSection('Patron (Tycoon)', 'tycoon', Colors.green),
          ],
        ),
      ),
    );
  }

  Widget _buildBranchSection(String title, String branchId, Color color) {
    final branchSkills = SkillService.skills.where((s) => s.branch == branchId).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const Divider(),
        const SizedBox(height: 8),
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: branchSkills.map((skill) => _buildSkillNode(skill, color)).toList(),
        ),
      ],
    );
  }

  Widget _buildSkillNode(Skill skill, Color color) {
    final isUnlocked = _currentUser!.unlockedSkills.contains(skill.id);
    final canUnlock = !isUnlocked && SkillService.canUnlock(_currentUser!, skill.id);

    return GestureDetector(
      onTap: () => isUnlocked ? null : _unlockSkill(skill),
      child: Container(
        width: 100,
        height: 120,
        decoration: BoxDecoration(
          color: isUnlocked ? color : Colors.grey[200],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: canUnlock ? Colors.green : (isUnlocked ? color : Colors.grey),
            width: canUnlock ? 3 : 1,
          ),
          boxShadow: canUnlock
              ? [BoxShadow(color: Colors.green.withOpacity(0.3), blurRadius: 8, spreadRadius: 2)]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              skill.icon,
              size: 32,
              color: isUnlocked ? Colors.white : Colors.grey,
            ),
            const SizedBox(height: 8),
            Text(
              skill.name,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isUnlocked ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 4),
            if (!isUnlocked)
              Text(
                '${skill.cost} SP',
                style: const TextStyle(
                  fontSize: 10,
                  color: Colors.black54,
                ),
              ),
            if (isUnlocked)
              const Icon(Icons.check, size: 16, color: Colors.white70),
          ],
        ),
      ),
    );
  }
}

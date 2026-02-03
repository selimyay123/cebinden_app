import 'package:flutter/material.dart';
import '../services/localization_service.dart';
import '../services/staff_service.dart';
import '../models/staff_model.dart';
import 'dart:async';
import '../widgets/modern_alert_dialog.dart';

class ManageStaffScreen extends StatefulWidget {
  const ManageStaffScreen({super.key});

  @override
  State<ManageStaffScreen> createState() => _ManageStaffScreenState();
}

class _ManageStaffScreenState extends State<ManageStaffScreen> {
  final StaffService _staffService = StaffService();
  List<Staff> _staff = [];
  StreamSubscription? _eventSubscription;

  @override
  void initState() {
    super.initState();
    _loadStaff();
    // Simülasyonu başlat (Eğer zaten çalışmıyorsa)
    _staffService.startSimulation();

    // Olayları dinle
    _eventSubscription = _staffService.eventStream.listen((event) {
      if (mounted && (ModalRoute.of(context)?.isCurrent ?? false)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(event),
            backgroundColor: Colors.green[700],
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _eventSubscription?.cancel();
    // Ekrandan çıkınca simülasyon dursun mu?
    // Genelde oyun arka planda devam etsin istenir ama şimdilik durduralım veya açık bırakalım.
    // _staffService.stopSimulation(); // İsteğe bağlı
    super.dispose();
  }

  void _loadStaff() {
    setState(() {
      _staff = _staffService.myStaff;
    });
  }

  void _showFireConfirmDialog(Staff staff) {
    showDialog(
      context: context,
      builder: (dialogContext) => ModernAlertDialog(
        title: 'staff.fire_confirm_title'.tr(
          defaultValue: 'Personeli İşten Çıkar',
        ),
        icon: Icons.person_remove_rounded,
        isDestructive: true,
        content: Text('staff.fire_confirm_desc'.trParams({'name': staff.name})),
        buttonText: 'staff.fire_button'.tr(defaultValue: 'İşten Çıkar'),
        onPressed: () async {
          await _staffService.fireStaff(staff.id);
          if (mounted) {
            Navigator.of(dialogContext).pop();
            _loadStaff();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'staff.fire_success'.trParams({'name': staff.name}),
                  style: const TextStyle(color: Colors.white),
                ),
                backgroundColor: Colors.green[700],
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            );
          }
        },
        secondaryButtonText: 'common.cancel'.tr(defaultValue: 'İptal'),
        onSecondaryPressed: () => Navigator.of(dialogContext).pop(),
      ),
    );
  }

  void _showHireConfirmDialog(Staff candidate) {
    showDialog(
      context: context,
      builder: (dialogContext) => ModernAlertDialog(
        title: 'staff.hire_confirm_title'.tr(defaultValue: 'Personeli İşe Al'),
        icon: Icons.person_add_rounded,
        content: Text(
          'staff.hire_confirm_desc'.trParams({
            'name': candidate.name,
            'salary': candidate.salary.toStringAsFixed(0),
          }),
        ),
        buttonText: 'staff.hire_button'.tr(defaultValue: 'İşe Al'),
        onPressed: () {
          _hireStaff(candidate);
          // 1. Önce dialoğu kapat (dialogContext ile)
          Navigator.of(dialogContext).pop();
          // 2. Sonra aday listesini (BottomSheet) kapat (ekranın context'i ile)
          Navigator.of(context).pop();
        },
        secondaryButtonText: 'common.cancel'.tr(defaultValue: 'İptal'),
        onSecondaryPressed: () => Navigator.of(dialogContext).pop(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.transparent, // Arka plan Container'dan gelecek
        appBar: AppBar(
          title: Text('staff.title'.tr(defaultValue: 'Personel Yönetimi')),
          backgroundColor: Colors.deepPurple,
          foregroundColor: Colors.white,
          centerTitle: true,
          bottom: _staff.isEmpty
              ? null
              : TabBar(
                  indicatorColor: Colors.white,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white70,
                  tabs: [
                    Tab(
                      text: 'staff.cat_sales'.tr(defaultValue: 'Satış Ekibi'),
                      icon: const Icon(Icons.campaign_outlined),
                    ),
                    Tab(
                      text: 'staff.cat_buyer'.tr(
                        defaultValue: 'Satın Alma Ekibi',
                      ),
                      icon: const Icon(Icons.shopping_cart_outlined),
                    ),
                  ],
                ),
        ),
        floatingActionButton: _staff.isEmpty
            ? null
            : FloatingActionButton.extended(
                onPressed: _showHireOptionsDialog,
                label: Text(
                  'staff.hire_button'.tr(defaultValue: 'Personel Al'),
                ),
                icon: const Icon(Icons.add),
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
              ),
        body: Container(
          color: Colors.black,
          child: _staff.isEmpty ? _buildEmptyState() : _buildTabBarView(),
        ),
      ),
    );
  }

  Widget _buildTabBarView() {
    final salesStaff = _staff.where((s) => s.role == StaffRole.sales).toList();
    final buyerStaff = _staff.where((s) => s.role == StaffRole.buyer).toList();

    return TabBarView(
      children: [_buildStaffList(salesStaff), _buildStaffList(buyerStaff)],
    );
  }

  // --- BOŞ DURUM (HİÇ PERSONEL YOK) ---
  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // İkon / Görsel
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.deepPurple.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.supervised_user_circle_outlined,
                size: 100,
                color: Colors.deepPurple.withValues(alpha: 0.8),
              ),
            ),
            const SizedBox(height: 24),

            // Başlık
            Text(
              'staff.empty_title'.tr(defaultValue: 'Henüz Personeliniz Yok'),
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),

            // Açıklama
            Text(
              'staff.empty_desc'.tr(
                defaultValue:
                    'İşlerinizi otomatikleştirmek ve gelirinizi artırmak için profesyonel bir ekip kurun.',
              ),
              style: const TextStyle(
                fontSize: 16,
                color: Colors.white,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),

            // Personel Al Butonu
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: _showHireOptionsDialog,
                icon: const Icon(Icons.add, size: 24),
                label: Text(
                  'staff.hire_button'.tr(defaultValue: 'Personel İşe Al'),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- PERSONEL LİSTESİ ---
  Widget _buildStaffList(List<Staff> staffList) {
    if (staffList.isEmpty) {
      return Center(
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            'Bu departmanda personel yok.',
            style: TextStyle(color: Colors.grey[800], fontSize: 16),
          ),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: staffList.length,
      itemBuilder: (context, index) {
        final staff = staffList[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.deepPurple.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Row(
                  children: [
                    // Avatar
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: Colors.white24,
                      child: Text(
                        staff.name[0].toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 24,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            staff.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${'staff.daily_salary'.tr(defaultValue: 'Günlük Maaş')}: ${staff.salary.toStringAsFixed(0)} TL',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Ayarlar butonu
                    IconButton(
                      icon: const Icon(Icons.settings, color: Colors.white70),
                      onPressed: () {
                        // Gelecekte detaylar için kullanılabilir
                      },
                    ),
                  ],
                ),
                // Alt Kısım: Satış Temsilcisi ise Statlar
                if (staff is SalesAgent) ...[
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8.0),
                    child: Divider(color: Colors.white24),
                  ),
                  _buildStatBar(
                    'staff.persuasion'.tr(defaultValue: 'İkna'),
                    staff.persuasion,
                    textColor: Colors.white,
                  ),
                  _buildStatBar(
                    'staff.speed'.tr(defaultValue: 'Hız'),
                    staff.speed / 2.0,
                    textColor: Colors.white,
                  ),
                  _buildStatBar(
                    'staff.negotiation'.tr(defaultValue: 'Pazarlık'),
                    staff.negotiationSkill * 2,
                    textColor: Colors.white,
                  ),
                ],
                // İŞTEN ÇIKAR BUTONU
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _showFireConfirmDialog(staff),
                    icon: const Icon(Icons.person_remove_outlined, size: 20),
                    label: Text(
                      'staff.fire_button'.tr(defaultValue: 'İşten Çıkar'),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent.withValues(alpha: 0.8),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _getRoleName(StaffRole role) {
    switch (role) {
      case StaffRole.buyer:
        return 'staff.role_buyer'.tr(defaultValue: 'Satın Alma Uzmanı');
      case StaffRole.sales:
        return 'staff.role_sales'.tr(defaultValue: 'Satış Danışmanı');
      case StaffRole.technical:
        return 'staff.role_tech'.tr(defaultValue: 'Teknik Servis');
      case StaffRole.accountant:
        return 'staff.role_accountant'.tr(defaultValue: 'Muhasebeci');
    }
  }

  // --- İŞE ALIM KATEGORİ DIALOGU ---
  void _showHireOptionsDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Colors.deepPurple[900]!.withValues(alpha: 0.95),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Tutamaç
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Başlık
            Text(
              'staff.hire_category_title'.tr(defaultValue: 'Departman Seç'),
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'staff.hire_category_desc'.tr(
                defaultValue: 'Hangi departman için personel arıyorsunuz?',
              ),
              style: const TextStyle(fontSize: 14, color: Colors.white70),
            ),
            const SizedBox(height: 24),

            // Kategoriler Grid
            LayoutBuilder(
              builder: (context, constraints) {
                return GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.1, // Kareye yakın
                  // İki öğeyi ortalamak için padding veya alignment kullanılabilir fakat GridView zaten genişliğe yayılır.
                  children: [
                    _buildCategoryCard(
                      title: 'staff.cat_sales'.tr(
                        defaultValue: 'Satış Temsilcisi',
                      ),
                      icon: Icons.campaign_outlined,
                      color: Colors.green,
                      onTap: () => _handleCategorySelect(StaffRole.sales),
                    ),
                    _buildCategoryCard(
                      title: 'staff.cat_buyer'.tr(defaultValue: 'Satın Alımcı'),
                      icon: Icons.shopping_cart_outlined,
                      color: Colors.blue,
                      onTap: () => _handleCategorySelect(StaffRole.buyer),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryCard({
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    bool isLocked = false,
  }) {
    return InkWell(
      onTap: isLocked ? null : onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: isLocked ? Colors.grey[100] : color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isLocked ? Colors.grey[300]! : color.withValues(alpha: 0.3),
            width: 2,
          ),
        ),
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isLocked
                          ? Colors.grey[300]
                          : color.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      icon,
                      size: 32,
                      color: isLocked ? Colors.grey : color,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isLocked ? Colors.white38 : Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            if (isLocked)
              Positioned(
                top: 8,
                right: 8,
                child: Icon(Icons.lock, size: 16, color: Colors.grey[400]),
              ),
          ],
        ),
      ),
    );
  }

  void _handleCategorySelect(StaffRole role) {
    final roleCount = _staff.where((s) => s.role == role).length;
    final limit = role == StaffRole.sales ? 3 : 5;
    if (roleCount >= limit) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${_getRoleName(role)} departmanı dolu! (Max: $limit)'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    Navigator.pop(context); // Kategori dialogunu kapat
    _showCandidateDialog(role);
  }

  void _showCandidateDialog(StaffRole role) {
    // Rastgele 3 aday oluştur
    final candidates = _staffService.generateCandidates(role);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: BoxDecoration(
          color: Colors.deepPurple[900]!.withValues(alpha: 0.95),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Text(
              '${'staff.searching'.tr(defaultValue: 'Adaylar')}: ${_getRoleName(role)}',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: candidates.length,
                itemBuilder: (context, index) {
                  final candidate = candidates[index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.deepPurple.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: Colors.white24,
                              child: Text(
                                candidate.name[0].toUpperCase(),
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    candidate.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: Colors.white,
                                    ),
                                  ),
                                  Text(
                                    '${'staff.daily_salary'.tr(defaultValue: 'Günlük Maaş')}: ${candidate.salary.toStringAsFixed(0)} TL',
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        if (candidate is SalesAgent) ...[
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8.0),
                            child: Divider(color: Colors.white24),
                          ),
                          _buildStatBar(
                            'staff.persuasion'.tr(defaultValue: 'İkna'),
                            candidate.persuasion,
                            textColor: Colors.white,
                          ),
                          _buildStatBar(
                            'staff.speed'.tr(defaultValue: 'Hız'),
                            candidate.speed / 2.0,
                            textColor: Colors.white,
                          ),
                          _buildStatBar(
                            'staff.negotiation'.tr(defaultValue: 'Pazarlık'),
                            candidate.negotiationSkill * 2,
                            textColor: Colors.white,
                          ),
                        ],
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () => _showHireConfirmDialog(candidate),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.deepPurple,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: Text(
                              'staff.hire_button'.tr(defaultValue: 'İşe Al'),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatBar(String label, double value, {Color? textColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 60,
            child: Text(
              label,
              style: TextStyle(fontSize: 12, color: textColor),
            ),
          ),
          Expanded(
            child: LinearProgressIndicator(
              value: value.clamp(0.0, 1.0),
              backgroundColor: Colors.white24,
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
              minHeight: 6,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        ],
      ),
    );
  }

  void _hireStaff(Staff staff) async {
    await _staffService.hireStaff(staff);
    if (!mounted) return;
    _loadStaff();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'staff.hire_success'.trParams({'name': staff.name}),
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.green[700],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}

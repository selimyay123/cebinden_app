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

class _ManageStaffScreenState extends State<ManageStaffScreen>
    with SingleTickerProviderStateMixin {
  final StaffService _staffService = StaffService();
  List<Staff> _staff = [];
  StreamSubscription? _eventSubscription;
  late TabController _tabController;
  Timer? _uiTimer; // Progress bar animasyonu için

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadStaff();

    // Gerçek zamanlı simülasyonu başlat
    _staffService.startRealTimeLoop();

    // UI Güncelleme Timer'ı (Progress Bar için)
    _uiTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (mounted) {
        setState(() {
          // Sadece UI'yi tetikle, logic StaffService'de dönüyor
        });
      }
    });

    // Olayları dinle
    _eventSubscription = _staffService.eventStream.listen((event) {
      if (mounted) {
        // Eğer event sadece bir action bildirimi veya update ise ignore et
        if (event.startsWith('staff_action_') ||
            event.startsWith('staff_update_')) {
          // Bu eventler sadece UI yenilemesi içindir (listenin yeniden çizilmesi vb.)
          // SnackBar göstermeye gerek yok.
        } else if (ModalRoute.of(context)?.isCurrent ?? false) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(event),
              backgroundColor: Colors.green[700],
              duration: const Duration(milliseconds: 1500),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    });
  }

  @override
  void dispose() {
    _eventSubscription?.cancel();
    _tabController.dispose();
    _uiTimer?.cancel();
    super.dispose();
  }

  void _loadStaff() {
    setState(() {
      _staff = _staffService.myStaff;
    });
  }

  void _showPauseConfirmDialog(Staff staff) {
    final bool isPausing = !staff.isPaused;
    showDialog(
      context: context,
      builder: (dialogContext) => ModernAlertDialog(
        title: isPausing
            ? 'staff.pause_confirm_title'.tr()
            : 'staff.resume_confirm_title'.tr(),
        icon: isPausing
            ? Icons.pause_circle_outline_rounded
            : Icons.play_circle_outline_rounded,
        content: Text(
          isPausing
              ? 'staff.pause_confirm_desc'.trParams({'name': staff.name})
              : 'staff.resume_confirm_desc'.trParams({'name': staff.name}),
        ),
        buttonText: isPausing
            ? 'staff.pause_work'.tr()
            : 'staff.resume_work'.tr(),
        onPressed: () async {
          await _staffService.toggleStaffPause(staff.id);
          if (mounted) {
            Navigator.of(dialogContext).pop();
            _loadStaff(); // UI güncelle
          }
        },
        secondaryButtonText: 'common.cancel'.tr(),
        onSecondaryPressed: () => Navigator.of(dialogContext).pop(),
      ),
    );
  }

  void _showFireConfirmDialog(Staff staff) {
    showDialog(
      context: context,
      builder: (dialogContext) => ModernAlertDialog(
        title: 'staff.fire_confirm_title'.tr(),
        icon: Icons.person_remove_rounded,
        isDestructive: true,
        content: Text('staff.fire_confirm_desc'.trParams({'name': staff.name})),
        buttonText: 'staff.fire_button'.tr(),
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
        secondaryButtonText: 'common.cancel'.tr(),
        onSecondaryPressed: () => Navigator.of(dialogContext).pop(),
      ),
    );
  }

  void _showHireConfirmDialog(Staff candidate) {
    showDialog(
      context: context,
      builder: (dialogContext) => ModernAlertDialog(
        title: 'staff.hire_confirm_title'.tr(),
        icon: Icons.person_add_rounded,
        content: Text(
          'staff.hire_confirm_desc'.trParams({
            'name': candidate.name,
            'salary': candidate.salary.toStringAsFixed(0),
          }),
        ),
        buttonText: 'staff.hire_button'.tr(),
        onPressed: () {
          _hireStaff(candidate);
          Navigator.of(dialogContext).pop(); // Dialog
          Navigator.of(context).pop(); // BottomSheet

          // İlgili sekmeye geç
          if (candidate.role == StaffRole.buyer) {
            _tabController.animateTo(1);
          } else {
            _tabController.animateTo(0);
          }
        },
        secondaryButtonText: 'common.cancel'.tr(),
        onSecondaryPressed: () => Navigator.of(dialogContext).pop(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent, // Arka plan Container'dan gelecek
      appBar: AppBar(
        title: Text('staff.title'.tr()),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        centerTitle: true,
        bottom: _staff.isEmpty
            ? null
            : TabBar(
                controller: _tabController,
                indicatorColor: Colors.white,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white70,
                tabs: [
                  Tab(
                    text: 'staff.cat_sales'.tr(),
                    icon: const Icon(Icons.campaign_outlined),
                  ),
                  Tab(
                    text: 'staff.cat_buyer'.tr(),
                    icon: const Icon(Icons.shopping_cart_outlined),
                  ),
                ],
              ),
      ),
      floatingActionButton: _staff.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: _showHireOptionsDialog,
              label: Text('staff.hire_button'.tr()),
              icon: const Icon(Icons.add),
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white,
            ),
      body: Container(
        color: Colors.black,
        child: _staff.isEmpty ? _buildEmptyState() : _buildTabBarView(),
      ),
    );
  }

  Widget _buildTabBarView() {
    final salesStaff = _staff.where((s) => s.role == StaffRole.sales).toList();
    final buyerStaff = _staff.where((s) => s.role == StaffRole.buyer).toList();

    return TabBarView(
      controller: _tabController,
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
              'staff.empty_title'.tr(),
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
              'staff.empty_desc'.tr(),
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
                  'staff.hire_button'.tr(),
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
        child: Text(
          'staff.no_personnel_in_dept'.tr(),
          style: TextStyle(color: Colors.white, fontSize: 16),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: staffList.length,
      itemBuilder: (context, index) {
        final staff = staffList[index];

        // Progress Bar Hesaplama
        final now = DateTime.now();
        final diff = now.difference(staff.lastActionTime).inMilliseconds;
        final totalMs = staff.actionIntervalSeconds * 1000;
        final progress = (diff / totalMs).clamp(0.0, 1.0);

        String skillText = "";
        String speedText = "${staff.actionIntervalSeconds}s";

        if (staff is SalesAgent) {
          skillText = "%${(staff.skill * 100).toInt()} Başarı";
        } else if (staff is BuyerAgent) {
          skillText = "%${(staff.skill * 100).toInt()} Başarı";
        }

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
                            '${'staff.daily_salary'.tr()}: ${staff.salary.toStringAsFixed(0)} TL',
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
                      onPressed: () {},
                    ),
                  ],
                ),

                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12.0),
                  child: Divider(color: Colors.white24),
                ),

                // İŞLEM İLERLEME ÇUBUĞU
                // Sözleşme Durumu
                Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: Row(
                    children: [
                      Icon(Icons.date_range, color: Colors.white70, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        'staff.contract_remaining'.trParams({
                          'days':
                              (StaffService.CONTRACT_DURATION_DAYS -
                                      DateTime.now()
                                          .difference(staff.hiredDate)
                                          .inDays)
                                  .toString(),
                        }),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),

                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "İşlem Durumu",
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                        Text(
                          "${(progress * 100).toInt()}%",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    LinearProgressIndicator(
                      value: progress,
                      backgroundColor: Colors.black26,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        Colors.greenAccent,
                      ),
                      minHeight: 8,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // STATLAR (Basit)
                Row(
                  children: [
                    _buildSimpleStat("Hız", speedText, Icons.timer),
                    const SizedBox(width: 16),
                    _buildSimpleStat("Yetenek", skillText, Icons.star),
                  ],
                ),

                SizedBox(height: 12),

                // DURAKLAT / DEVAM ETTİR BUTONU
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _showPauseConfirmDialog(staff),
                    icon: Icon(
                      staff.isPaused
                          ? Icons.play_arrow_rounded
                          : Icons.pause_rounded,
                      size: 20,
                    ),
                    label: Text(
                      staff.isPaused
                          ? 'staff.resume_work'.tr()
                          : 'staff.pause_work'.tr(),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: staff.isPaused
                          ? Colors.green.withValues(alpha: 0.8)
                          : Colors.orange.withValues(alpha: 0.8),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // İŞTEN ÇIKAR BUTONU
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _showFireConfirmDialog(staff),
                    icon: const Icon(Icons.person_remove_outlined, size: 20),
                    label: Text(
                      'staff.fire_button'.tr(),
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

  Widget _buildSimpleStat(String label, String value, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white10,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment:
              MainAxisAlignment.center, // Center content horizontally
          children: [
            Icon(icon, color: Colors.white70, size: 16),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(color: Colors.white54, fontSize: 11),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _getRoleName(StaffRole role) {
    switch (role) {
      case StaffRole.buyer:
        return 'staff.role_buyer'.tr();
      case StaffRole.sales:
        return 'staff.role_sales'.tr();
      default:
        return role.toString();
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
            Text(
              'staff.hire_category_title'.tr(),
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'staff.hire_category_desc'.tr(),
              style: const TextStyle(fontSize: 14, color: Colors.white70),
            ),
            const SizedBox(height: 24),
            LayoutBuilder(
              builder: (context, constraints) {
                return GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.1,
                  children: [
                    _buildCategoryCard(
                      title: 'staff.cat_sales'.tr(),
                      icon: Icons.campaign_outlined,
                      color: Colors.green,
                      onTap: () => _handleCategorySelect(StaffRole.sales),
                    ),
                    _buildCategoryCard(
                      title: 'staff.cat_buyer'.tr(),
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
            if (isLocked) Icon(Icons.lock, size: 16, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }

  void _handleCategorySelect(StaffRole role) {
    final roleCount = _staff.where((s) => s.role == role).length;
    final limit = (role == StaffRole.sales || role == StaffRole.buyer) ? 2 : 5;
    if (roleCount >= limit) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(milliseconds: 1500),
          content: Text(
            'staff.department_full'.trParams({'limit': limit.toString()}),
            style: const TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
      return;
    }
    Navigator.pop(context);
    _showCandidateDialog(role);
  }

  void _showCandidateDialog(StaffRole role) {
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
              '${'staff.searching'.tr()}: ${_getRoleName(role)}',
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

                  String skillText = "";
                  String speedText = "${candidate.actionIntervalSeconds}s";
                  if (candidate is SalesAgent) {
                    skillText = "${(candidate.skill * 100).toInt()}%";
                  } else if (candidate is BuyerAgent) {
                    skillText = "${(candidate.skill * 100).toInt()}%";
                  }

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
                                    '${'staff.daily_salary'.tr()}: ${candidate.salary.toStringAsFixed(0)} TL',
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
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            _buildSimpleStat("Hız", speedText, Icons.timer),
                            const SizedBox(width: 12),
                            _buildSimpleStat("Yetenek", skillText, Icons.star),
                          ],
                        ),
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
                              'staff.hire_button'.tr(),
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

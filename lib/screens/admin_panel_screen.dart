import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/admin_service.dart';
import '../services/auth_service.dart';
import '../services/database_helper.dart';
import 'package:intl/intl.dart';
import '../services/localization_service.dart';

class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({super.key});

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen>
    with SingleTickerProviderStateMixin {
  final AdminService _adminService = AdminService();
  late TabController _tabController;

  // Gold assignment
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _goldAmountController = TextEditingController();
  bool _isAssigning = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _emailController.dispose();
    _goldAmountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'admin.title'.tr(),
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.deepPurple,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white54,
          labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600),
          unselectedLabelStyle: GoogleFonts.poppins(
            fontWeight: FontWeight.w400,
          ),
          tabs: [
            Tab(
              icon: const Icon(Icons.report_rounded, size: 20),
              text: 'admin.reports_tab'.tr(),
            ),
            Tab(
              icon: const Icon(Icons.monetization_on_rounded, size: 20),
              text: 'admin.gold_tab'.tr(),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildReportsTab(), _buildGoldTab()],
      ),
    );
  }

  // ─── TAB 1: Reports ────────────────────────────────────────────────
  Widget _buildReportsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: _adminService.getPendingReports(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'admin.error'.tr(),
              style: const TextStyle(color: Colors.white),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.deepPurple),
          );
        }

        final reports = snapshot.data!.docs;

        if (reports.isEmpty) {
          return Center(
            child: Text(
              'admin.noReports'.tr(),
              style: GoogleFonts.poppins(color: Colors.white70),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: reports.length,
          itemBuilder: (context, index) {
            final report = reports[index].data() as Map<String, dynamic>;
            final reportId = reports[index].id;
            final timestamp =
                (report['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();

            return Card(
              color: const Color(0xFF1E1E1E),
              margin: const EdgeInsets.only(bottom: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'admin.reported'.trParams({
                            'username': report['reportedUsername'],
                          }),
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          DateFormat('dd/MM/yyyy HH:mm').format(timestamp),
                          style: GoogleFonts.poppins(
                            color: Colors.white54,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'admin.reason'.trParams({'reason': report['reason']}),
                      style: GoogleFonts.poppins(color: Colors.white70),
                    ),
                    if (report['description'] != null &&
                        report['description'].toString().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          'admin.description'.trParams({
                            'description': report['description'],
                          }),
                          style: GoogleFonts.poppins(
                            color: Colors.white54,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => _dismissReport(reportId),
                          child: Text(
                            'admin.dismiss'.tr(),
                            style: const TextStyle(color: Colors.grey),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () => _banUser(
                            reportId: reportId,
                            userId: report['reportedUserId'],
                            username: report['reportedUsername'],
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                          ),
                          child: Text('admin.ban'.tr()),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ─── TAB 2: Gold Assignment ────────────────────────────────────────
  Widget _buildGoldTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          // Header
          Center(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [Colors.amber.shade700, Colors.orange.shade400],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.amber.withValues(alpha: 0.3),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: const Icon(
                Icons.monetization_on_rounded,
                color: Colors.white,
                size: 40,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Center(
            child: Text(
              'admin.gold_tab'.tr(),
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 32),

          // Username field
          Text(
            'admin.username_label'.tr(),
            style: GoogleFonts.poppins(
              color: Colors.white70,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _emailController,
            style: GoogleFonts.poppins(color: Colors.white),
            keyboardType: TextInputType.text,
            decoration: InputDecoration(
              hintText: 'admin.username_hint'.tr(),
              hintStyle: GoogleFonts.poppins(color: Colors.white38),
              prefixIcon: const Icon(
                Icons.person_rounded,
                color: Colors.white54,
              ),
              filled: true,
              fillColor: const Color(0xFF1E1E1E),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: Colors.deepPurple,
                  width: 1.5,
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Gold amount field
          Text(
            'admin.gold_amount_hint'.tr(),
            style: GoogleFonts.poppins(
              color: Colors.white70,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _goldAmountController,
            style: GoogleFonts.poppins(color: Colors.white),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              hintText: '0.0',
              hintStyle: GoogleFonts.poppins(color: Colors.white38),
              prefixIcon: Icon(
                Icons.monetization_on_rounded,
                color: Colors.amber.shade400,
              ),
              filled: true,
              fillColor: const Color(0xFF1E1E1E),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: Colors.deepPurple,
                  width: 1.5,
                ),
              ),
            ),
          ),
          const SizedBox(height: 32),

          // Assign button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _isAssigning ? null : _assignGold,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber.shade700,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey[700],
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 4,
              ),
              child: _isAssigning
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.5,
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.send_rounded, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'admin.assign_gold'.tr(),
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Actions ───────────────────────────────────────────────────────

  Future<void> _assignGold() async {
    final username = _emailController.text.trim();
    final amountText = _goldAmountController.text.trim();

    if (username.isEmpty || amountText.isEmpty) return;

    final amount = double.tryParse(amountText);
    if (amount == null || amount <= 0) return;

    setState(() => _isAssigning = true);

    final result = await _adminService.assignGold(username, amount);

    // Eğer atanan kullanıcı mevcut kullanıcıysa, yerel DB'yi de güncelle
    if (result != null) {
      final currentUser = await AuthService().getCurrentUser();
      if (currentUser != null && currentUser.id == result['userId']) {
        final newGold = currentUser.gold + amount;
        await DatabaseHelper().updateUser(currentUser.id, {'gold': newGold});
      }
    }

    setState(() => _isAssigning = false);

    if (!mounted) return;

    if (result != null) {
      _emailController.clear();
      _goldAmountController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 4),
          backgroundColor: Colors.green[700],
          behavior: SnackBarBehavior.floating,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'admin.gold_assigned_success'.trParams({
                  'username': result['username']!,
                  'amount': amount.toStringAsFixed(0),
                }),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                'Email: ${result['email']}',
                style: const TextStyle(fontSize: 12),
              ),
              Text(
                'ID: ${result['userId']}',
                style: const TextStyle(fontSize: 10, color: Colors.white70),
              ),
            ],
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(milliseconds: 2000),
          content: Text('admin.user_not_found'.tr()),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _dismissReport(String reportId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: Text(
          'admin.dismissConfirmTitle'.tr(),
          style: const TextStyle(color: Colors.white),
        ),
        content: Text(
          'admin.dismissConfirmMessage'.tr(),
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'common.cancel'.tr(),
              style: const TextStyle(color: Colors.white54),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.grey),
            child: Text(
              'admin.dismiss'.tr(),
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final success = await _adminService.dismissReport(reportId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            duration: const Duration(milliseconds: 1500),
            content: Text(
              success ? 'admin.reportDismissed'.tr() : 'admin.error'.tr(),
            ),
            backgroundColor: success ? Colors.grey : Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _banUser({
    required String reportId,
    required String userId,
    required String username,
  }) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: Text(
          'admin.banConfirmTitle'.tr(),
          style: const TextStyle(color: Colors.white),
        ),
        content: Text(
          'admin.banConfirmMessage'.trParams({'username': username}),
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'common.cancel'.tr(),
              style: const TextStyle(color: Colors.white54),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(
              'admin.ban'.tr(),
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final success = await _adminService.banUserAndResolveReport(
        userId: userId,
        reportId: reportId,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            duration: const Duration(milliseconds: 1500),
            content: Text(
              success ? 'admin.userBanned'.tr() : 'admin.error'.tr(),
            ),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
      }
    }
  }
}

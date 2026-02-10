// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/leaderboard_service.dart';
import '../services/friend_service.dart';
import '../services/database_helper.dart';
import '../models/user_model.dart';
import '../services/localization_service.dart';

import 'package:lottie/lottie.dart';
import '../services/report_service.dart';
import '../widgets/custom_snackbar.dart';
import '../widgets/user_profile_avatar.dart';
import '../widgets/modern_alert_dialog.dart';
import '../widgets/social_background.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  final LeaderboardService _leaderboardService = LeaderboardService();
  final DatabaseHelper _databaseHelper = DatabaseHelper();

  User? _currentUser;
  List<Map<String, dynamic>> _topPlayers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Aktif kullanıcıyı al
      final currentUserMap = await _databaseHelper.getCurrentUser();
      if (currentUserMap != null) {
        _currentUser = User.fromJson(currentUserMap);
        // Kullanıcı verisini güncelle (her girişte sync etmek iyi bir fikir)
        if (_currentUser != null) {
          _leaderboardService.updateUserScore(_currentUser!);
        }
      }

      // Liderlik tablosunu çek
      final players = await _leaderboardService.getTopPlayers(limit: 100);

      if (mounted) {
        setState(() {
          _topPlayers = players;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: Colors.deepPurpleAccent.withValues(alpha: 0.5),
        elevation: 0,
        title: Text(
          'drawer.leaderboard'.tr(),
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadData,
          ),
        ],
      ),
      body: SocialBackground(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFFE5B80B)),
              )
            : _topPlayers.isEmpty
            ? Center(
                child: Text(
                  'Henüz veri yok.',
                  style: GoogleFonts.poppins(color: Colors.white70),
                ),
              )
            : Column(
                children: [
                  // Bilgilendirme Mesajı
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      vertical: 8,
                      horizontal: 16,
                    ),
                    color: Colors.black.withValues(alpha: 0.3),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.info_outline,
                          color: Colors.white54,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'auth.reportInfo'.tr(),
                            style: GoogleFonts.poppins(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _topPlayers.length,
                      itemBuilder: (context, index) {
                        final player = _topPlayers[index];
                        final isCurrentUser =
                            _currentUser?.id == player['userId'];
                        final rank = index + 1;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: isCurrentUser
                                ? const Color(
                                    0xFFE5B80B,
                                  ).withValues(alpha: 0.15)
                                : Colors.deepPurple.shade900.withValues(
                                    alpha: 0.5,
                                  ), // Şeffaf koyu mor

                            borderRadius: BorderRadius.circular(16),
                            border: isCurrentUser
                                ? Border.all(
                                    color: const Color(
                                      0xFFE5B80B,
                                    ).withValues(alpha: 0.5),
                                  )
                                : null,
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            leading: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  width:
                                      50, // Sabit genişlik ile hizalamayı koru
                                  height: 50,
                                  child: rank == 1
                                      ? Lottie.asset(
                                          'assets/animations/1st.json',
                                        )
                                      : Center(
                                          child: Container(
                                            width: 30,
                                            height: 30,
                                            alignment: Alignment.center,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: _getRankColor(rank),
                                            ),
                                            child: Text(
                                              '$rank',
                                              style: GoogleFonts.poppins(
                                                color: rank <= 3
                                                    ? Colors.black
                                                    : Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                              ),
                                            ),
                                          ),
                                        ),
                                ),
                                const SizedBox(width: 12),
                                Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: Colors.grey[800]!,
                                          width: 1,
                                        ),
                                      ),
                                      child: UserProfileAvatar(
                                        imageUrl: player['profileImageUrl'],
                                        username: player['username'],
                                        radius: 19,
                                        backgroundColor: Colors.grey[800],
                                        textColor: Colors.white,
                                        fontSize: 16,
                                      ),
                                    ),
                                    if ((player['respectCount'] ?? 0) > 0)
                                      Positioned(
                                        top: -4,
                                        right: -8,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 4,
                                            vertical: 1,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.pinkAccent,
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.pinkAccent
                                                    .withValues(alpha: 0.4),
                                                blurRadius: 4,
                                                spreadRadius: 1,
                                              ),
                                            ],
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(
                                                Icons.favorite,
                                                color: Colors.white,
                                                size: 10,
                                              ),
                                              const SizedBox(width: 2),
                                              Text(
                                                '${player['respectCount']}',
                                                style: GoogleFonts.poppins(
                                                  color: Colors.white,
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                            title: Text(
                              player['username'] ?? 'Bilinmeyen Oyuncu',
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              'Seviye ${player['level'] ?? 1}',
                              style: GoogleFonts.poppins(
                                color: Colors.white54,
                                fontSize: 12,
                              ),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _formatMoney(player['balance']),
                                  style: GoogleFonts.poppins(
                                    color: const Color(0xFFE5B80B),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                                if (!isCurrentUser) ...[
                                  const SizedBox(width: 8),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.person_add,
                                      color: Colors.white70,
                                      size: 20,
                                    ),
                                    tooltip: 'drawer.social.addFriend'.tr(),
                                    onPressed: () {
                                      showDialog(
                                        context: context,
                                        builder: (context) => ModernAlertDialog(
                                          title: 'drawer.social.addFriend'.tr(),
                                          content: Text(
                                            'drawer.social.addFriendConfirm'
                                                .trParams({
                                                  '0': player['username'] ?? '',
                                                }),
                                            style: const TextStyle(
                                              color: Colors.white70,
                                            ),
                                          ),
                                          buttonText: 'common.add'.tr(),
                                          onPressed: () {
                                            Navigator.pop(
                                              context,
                                            ); // Close dialog
                                            _sendFriendRequest(
                                              player['userId'],
                                            );
                                          },
                                          secondaryButtonText: 'common.cancel'
                                              .tr(),
                                          onSecondaryPressed: () =>
                                              Navigator.pop(context),
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ],
                            ),
                            onTap: () {
                              _showUserDetailDialog(
                                rank: rank,
                                username:
                                    player['username'] ?? 'Bilinmeyen Oyuncu',
                                profileImageUrl: player['profileImageUrl'],
                                balance: player['balance'],
                              );
                            },
                            onLongPress: () {
                              if (!isCurrentUser) {
                                _showReportDialog(
                                  userId: player['userId'],
                                  username:
                                      player['username'] ?? 'Bilinmeyen Oyuncu',
                                );
                              }
                            },
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

  Color _getRankColor(int rank) {
    switch (rank) {
      case 1:
        return const Color(0xFFFFD700); // Altın
      case 2:
        return const Color(0xFFC0C0C0); // Gümüş
      case 3:
        return const Color(0xFFCD7F32); // Bronz
      default:
        return const Color(0xFF2C2C2C); // Diğerleri
    }
  }

  Future<void> _sendFriendRequest(String toUserId) async {
    if (_currentUser == null) return;
    try {
      await FriendService().sendFriendRequest(_currentUser!.id, toUserId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            duration: const Duration(milliseconds: 1500),
            content: Text('drawer.social.requestSent'.tr()),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            duration: const Duration(milliseconds: 1500),
            content: Text(
              'Hata: $e',
            ), // "Request already sent" or "Already friends"
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  String _formatMoney(dynamic amount) {
    if (amount == null) return '0';

    // Ensure amount is treated as a number
    double value;
    if (amount is int) {
      value = amount.toDouble();
    } else if (amount is double) {
      value = amount;
    } else if (amount is String) {
      value = double.tryParse(amount) ?? 0;
    } else {
      return '0';
    }

    if (value < 1000000) {
      return '${'common.money_prefix_less_than'.tr()}1${'common.money_suffix_m'.tr()}';
    } else if (value < 1000000000) {
      int millions = (value / 1000000).floor();
      return '$millions${'common.money_suffix_m'.tr()}';
    } else {
      int billions = (value / 1000000000).floor();
      return '$billions${'common.money_suffix_b'.tr()}';
    }
  }

  Future<void> _showReportDialog({
    required String userId,
    required String username,
  }) async {
    if (_currentUser == null) return;

    // Önce rapor kontrolü yap
    final hasReported = await ReportService().hasReported(
      _currentUser!.id,
      userId,
    );
    if (hasReported) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          CustomSnackBar(
            duration: const Duration(milliseconds: 1500),
            content: Text('report.alreadyReported'.tr()),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    if (!mounted) return;

    String? selectedReasonKey;
    final TextEditingController otherReasonController = TextEditingController();

    // Rapor nedenleri listesi (key'ler)
    final List<String> reportReasons = ['inappropriateUsername', 'other'];

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (innerContext, setState) {
          return AlertDialog(
            backgroundColor: const Color(0xFF1E1E1E),
            title: Text(
              'report.title'.tr(),
              style: GoogleFonts.poppins(color: Colors.white),
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'report.message'.trParams({'username': username}),
                      style: GoogleFonts.poppins(color: Colors.white70),
                    ),
                    const SizedBox(height: 16),
                    ...reportReasons.map((reasonKey) {
                      return RadioListTile<String>(
                        title: Text(
                          'report.reasons.$reasonKey'.tr(),
                          style: GoogleFonts.poppins(color: Colors.white),
                        ),
                        value: reasonKey,
                        groupValue: selectedReasonKey,
                        activeColor: Colors.deepPurpleAccent,
                        contentPadding: EdgeInsets.zero,
                        onChanged: (value) {
                          setState(() {
                            selectedReasonKey = value;
                          });
                        },
                      );
                    }),

                    // "Diğer" seçildiyse açıklama alanı göster
                    if (selectedReasonKey == 'other') ...[
                      const SizedBox(height: 8),
                      TextField(
                        controller: otherReasonController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'report.reasonHint'.tr(),
                          hintStyle: const TextStyle(color: Colors.white38),
                          enabledBorder: OutlineInputBorder(
                            borderSide: const BorderSide(color: Colors.white24),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: const BorderSide(
                              color: Colors.deepPurpleAccent,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        maxLines: 3,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text(
                  'report.cancel'.tr(),
                  style: const TextStyle(color: Colors.white54),
                ),
              ),
              ElevatedButton(
                onPressed: selectedReasonKey == null
                    ? null // Seçim yapılmadıysa buton pasif
                    : () async {
                        if (_currentUser == null) return;

                        String finalReason = 'report.reasons.$selectedReasonKey'
                            .tr();

                        // "Diğer" seçildiyse ve açıklama girildiyse onu ekle
                        if (selectedReasonKey == 'other') {
                          final otherText = otherReasonController.text.trim();
                          if (otherText.isNotEmpty) {
                            finalReason += ': $otherText';
                          }
                        }

                        Navigator.pop(dialogContext); // Dialog'u kapat

                        // Raporu gönder
                        final success = await ReportService().reportUser(
                          reporterId: _currentUser!.id,
                          reportedUserId: userId,
                          reportedUsername: username,
                          reason: finalReason,
                        );

                        if (mounted) {
                          if (success) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              CustomSnackBar(
                                duration: const Duration(milliseconds: 1500),
                                content: Text('report.success'.tr()),
                                backgroundColor: Colors.green,
                              ),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              CustomSnackBar(
                                duration: const Duration(milliseconds: 1500),
                                content: Text('report.error'.tr()),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.redAccent.withValues(
                    alpha: 0.3,
                  ),
                  disabledForegroundColor: Colors.white38,
                ),
                child: Text('report.submit'.tr()),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showUserDetailDialog({
    required int rank,
    required String username,
    required String? profileImageUrl,
    required dynamic balance,
  }) async {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        elevation: 0,
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.deepPurple,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.deepPurple.shade500, Colors.deepPurple.shade900],
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 🏆 Sıralama Rozeti
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: (rank <= 3 ? _getRankColor(rank) : Colors.white)
                      .withValues(alpha: rank <= 3 ? 0.2 : 0.1),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: (rank <= 3 ? _getRankColor(rank) : Colors.white54)
                        .withValues(alpha: 0.5),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: (rank <= 3 ? _getRankColor(rank) : Colors.white)
                          .withValues(alpha: 0.2),
                      blurRadius: 10,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.emoji_events,
                      color: rank <= 3 ? _getRankColor(rank) : Colors.white,
                      size: 24,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '#$rank',
                      style: GoogleFonts.poppins(
                        color: rank <= 3 ? _getRankColor(rank) : Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 24,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // 👤 Profil Resmi
              Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 110,
                    height: 110,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: _getRankColor(rank).withValues(alpha: 0.4),
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: _getRankColor(rank), width: 3),
                    ),
                    child: UserProfileAvatar(
                      imageUrl: profileImageUrl,
                      username: username,
                      radius: 48,
                      backgroundColor: Colors.grey[900],
                      textColor: Colors.white,
                      fontSize: 32,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 🏷️ Kullanıcı Adı
              Text(
                username,
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 22,
                  shadows: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.5),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),

              // 💰 Bakiye
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFE5B80B).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFFE5B80B).withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.account_balance_wallet,
                      color: Color(0xFFE5B80B),
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _formatMoney(balance),
                      style: GoogleFonts.poppins(
                        color: const Color(0xFFE5B80B),
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // ❌ Kapat Butonu
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white.withValues(alpha: 0.1),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                        color: Colors.white.withValues(alpha: 0.2),
                      ),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    'common.close'.tr(),
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
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
}

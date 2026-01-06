import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/leaderboard_service.dart';
import '../services/friend_service.dart';
import '../services/database_helper.dart';
import '../models/user_model.dart';
import '../services/localization_service.dart';
import 'package:intl/intl.dart';
import 'package:lottie/lottie.dart';
import '../services/report_service.dart';
import '../widgets/custom_snackbar.dart';
import '../widgets/user_profile_avatar.dart';

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
  final NumberFormat _currencyFormat = NumberFormat.currency(locale: 'tr_TR', symbol: 'TL', decimalDigits: 0);

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
      final players = await _leaderboardService.getTopPlayers(limit: 20);
      
      if (mounted) {
        setState(() {
          _topPlayers = players;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading leaderboard: $e');
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
        backgroundColor: Colors.transparent,
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
      body: Stack(
        children: [
          // Arka Plan Resmi
          Positioned.fill(
            child: Image.asset(
              'assets/images/social_bg.jpeg',
              fit: BoxFit.cover,
            ),
          ),
          // Karartma Katmanı (Okunabilirlik için)
          Positioned.fill(
            child: Container(
              color: Colors.black.withOpacity(0.7),
            ),
          ),
          // İçerik
          _isLoading
              ? const Center(child: CircularProgressIndicator(color: Color(0xFFE5B80B)))
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
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                          color: Colors.black.withOpacity(0.3),
                          child: Row(
                            children: [
                              const Icon(Icons.info_outline, color: Colors.white54, size: 16),
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
                        final isCurrentUser = _currentUser?.id == player['userId'];
                        final rank = index + 1;
                        
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: isCurrentUser 
                                ? const Color(0xFFE5B80B).withOpacity(0.15) 
                                : const Color(0xFF1E1E1E).withOpacity(0.8), // Hafif şeffaflık
                            borderRadius: BorderRadius.circular(16),
                            border: isCurrentUser 
                                ? Border.all(color: const Color(0xFFE5B80B).withOpacity(0.5))
                                : null,
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            leading: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  width: 50, // Sabit genişlik ile hizalamayı koru
                                  height: 50,
                                  child: rank == 1 
                                    ? Lottie.asset('assets/animations/1st.json')
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
                                              color: rank <= 3 ? Colors.black : Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ),
                                      ),
                                ),
                                const SizedBox(width: 12),
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.grey[800]!, width: 1),
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
                            trailing: Text(
                              _formatMoney(player['balance']),
                              style: GoogleFonts.poppins(
                                color: const Color(0xFFE5B80B),
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            onLongPress: () {
                              if (!isCurrentUser) {
                                _showReportDialog(
                                  userId: player['userId'],
                                  username: player['username'] ?? 'Bilinmeyen Oyuncu',
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
        ],
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
            content: Text('drawer.social.requestSent'.tr()),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hata: $e'), // "Request already sent" or "Already friends"
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  String _formatMoney(dynamic amount) {
    if (amount == null) return 'TL0';
    return _currencyFormat.format(amount);
  }

  Future<void> _showReportDialog({required String userId, required String username}) async {
    if (_currentUser == null) return;

    // Önce rapor kontrolü yap
    final hasReported = await ReportService().hasReported(_currentUser!.id, userId);
    if (hasReported) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          CustomSnackBar(
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
    final List<String> reportReasons = [
      'inappropriateUsername',
      'other',
    ];

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
                    }).toList(),
                    
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
                            borderSide: const BorderSide(color: Colors.deepPurpleAccent),
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
                child: Text('report.cancel'.tr(), style: const TextStyle(color: Colors.white54)),
              ),
              ElevatedButton(
                onPressed: selectedReasonKey == null 
                    ? null // Seçim yapılmadıysa buton pasif
                    : () async {
                        if (_currentUser == null) return;
                        
                        String finalReason = 'report.reasons.$selectedReasonKey'.tr();
                        
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
                                content: Text('report.success'.tr()),
                                backgroundColor: Colors.green,
                              ),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              CustomSnackBar(
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
                  disabledBackgroundColor: Colors.redAccent.withOpacity(0.3),
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
}

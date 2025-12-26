import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/leaderboard_service.dart';
import '../services/friend_service.dart';
import '../services/database_helper.dart';
import '../models/user_model.dart';
import '../services/localization_service.dart';
import 'package:intl/intl.dart';
import 'package:lottie/lottie.dart';

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
  final NumberFormat _currencyFormat = NumberFormat.currency(locale: 'tr_TR', symbol: '₺', decimalDigits: 0);

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
          'Liderlik Tablosu',
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
                  : ListView.builder(
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
                                  child: CircleAvatar(
                                    backgroundColor: Colors.grey[800],
                                    backgroundImage: player['profileImageUrl'] != null
                                        ? (player['profileImageUrl'].startsWith('assets/')
                                            ? AssetImage(player['profileImageUrl'])
                                            : NetworkImage(player['profileImageUrl'])) as ImageProvider
                                        : null,
                                    child: player['profileImageUrl'] == null
                                        ? Text(
                                            (player['username'] ?? '?')[0].toUpperCase(),
                                            style: const TextStyle(color: Colors.white),
                                          )
                                        : null,
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
                          ),
                        );
                      },
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
    if (amount == null) return '₺0';
    return _currencyFormat.format(amount);
  }
}

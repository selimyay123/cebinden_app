import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/friend_service.dart';
import '../../services/database_helper.dart';
import '../../models/user_model.dart';
import '../../services/localization_service.dart';
import '../../widgets/user_profile_avatar.dart';

class RequestsTab extends StatefulWidget {
  const RequestsTab({super.key});

  @override
  State<RequestsTab> createState() => _RequestsTabState();
}

class _RequestsTabState extends State<RequestsTab> {
  final FriendService _friendService = FriendService();
  final DatabaseHelper _databaseHelper = DatabaseHelper();

  User? _currentUser;

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
  }

  Future<void> _loadCurrentUser() async {
    final userMap = await _databaseHelper.getCurrentUser();
    if (userMap != null) {
      setState(() {
        _currentUser = User.fromJson(userMap);
      });
    }
  }

  Future<void> _acceptRequest(String requestId, String fromUserId) async {
    if (_currentUser == null) return;

    try {
      // Gönderen kişinin bilgilerini al (Leaderboard'dan veya Users'dan)
      final fromUser = await _friendService.getSocialUser(fromUserId);

      if (fromUser != null) {
        await _friendService.acceptFriendRequest(
          requestId,
          fromUserId,
          _currentUser!.id,
          _currentUser!.username,
          _currentUser!.profileImageUrl,
          fromUser.username,
          fromUser.profileImageUrl,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('drawer.social.requestAccepted'.tr()),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        throw Exception('Kullanıcı bilgileri bulunamadı');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _rejectRequest(String requestId) async {
    try {
      await _friendService.rejectFriendRequest(requestId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('drawer.social.requestRejected'.tr())),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        shape: BoxShape.circle,
      ),
      child: IconButton(
        icon: Icon(icon, color: color, size: 20),
        onPressed: onPressed,
        constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
        padding: EdgeInsets.zero,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUser == null) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFE5B80B)),
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: _friendService.getIncomingRequests(_currentUser!.id),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Hata: ${snapshot.error}',
              style: const TextStyle(color: Colors.white),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFFE5B80B)),
          );
        }

        final docs = snapshot.data?.docs ?? [];

        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.mark_email_read, size: 90, color: Colors.white),
                const SizedBox(height: 16),
                Text(
                  'drawer.social.noRequests'.tr(),
                  style: GoogleFonts.poppins(color: Colors.white, fontSize: 18),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.only(top: 20, bottom: 20),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;
            final fromUserId = data['fromId'] as String;

            return FutureBuilder<SocialUser?>(
              future: _friendService.getSocialUser(fromUserId),
              builder: (context, userSnapshot) {
                if (!userSnapshot.hasData) {
                  return const SizedBox.shrink(); // Yükleniyor veya bulunamadı
                }

                final user = userSnapshot.data!;

                return Container(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.deepPurple.shade800,
                        Colors.deepPurple.shade500,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.1),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.4),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    leading: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white24, width: 2),
                      ),
                      child: UserProfileAvatar(
                        imageUrl: user.profileImageUrl,
                        username: user.username,
                        radius: 22,
                        backgroundColor: Colors.grey[900],
                        textColor: Colors.white,
                      ),
                    ),
                    title: Text(
                      user.username,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    subtitle: Text(
                      'Seviye ${user.level}',
                      style: TextStyle(color: Colors.grey[400], fontSize: 12),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildActionButton(
                          icon: Icons.check_circle_rounded,
                          color: Colors.greenAccent,
                          onPressed: () => _acceptRequest(doc.id, fromUserId),
                        ),
                        _buildActionButton(
                          icon: Icons.cancel_rounded,
                          color: Colors.redAccent,
                          onPressed: () => _rejectRequest(doc.id),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

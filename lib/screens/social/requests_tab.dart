import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/friend_service.dart';
import '../../services/database_helper.dart';
import '../../models/user_model.dart';
import '../../services/localization_service.dart';

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
            SnackBar(content: Text('drawer.social.requestAccepted'.tr()), backgroundColor: Colors.green),
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

  @override
  Widget build(BuildContext context) {
    if (_currentUser == null) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFFE5B80B)));
    }

    return StreamBuilder<QuerySnapshot>(
      stream: _friendService.getIncomingRequests(_currentUser!.id),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Hata: ${snapshot.error}', style: const TextStyle(color: Colors.white)));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFFE5B80B)));
        }

        final docs = snapshot.data?.docs ?? [];

        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.mark_email_read, size: 64, color: Colors.grey[800]),
                const SizedBox(height: 16),
                Text(
                  'drawer.social.noRequests'.tr(),
                  style: GoogleFonts.poppins(color: Colors.grey),
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
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.deepPurple.shade900.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.grey[800],
                      backgroundImage: user.profileImageUrl != null
                          ? (user.profileImageUrl!.startsWith('assets/')
                              ? AssetImage(user.profileImageUrl!)
                              : NetworkImage(user.profileImageUrl!)) as ImageProvider
                          : null,
                      child: user.profileImageUrl == null
                          ? Text(user.username[0].toUpperCase())
                          : null,
                    ),
                    title: Text(
                      user.username,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      'Seviye ${user.level}',
                      style: TextStyle(color: Colors.grey[400]),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.check_circle, color: Colors.green),
                          onPressed: () => _acceptRequest(doc.id, fromUserId),
                        ),
                        IconButton(
                          icon: const Icon(Icons.cancel, color: Colors.red),
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

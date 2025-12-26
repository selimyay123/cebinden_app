import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/friend_service.dart';
import '../../services/chat_service.dart';
import '../../services/database_helper.dart';
import '../../models/user_model.dart';
import '../../services/localization_service.dart';
import 'chat_screen.dart';

class FriendsTab extends StatefulWidget {
  const FriendsTab({super.key});

  @override
  State<FriendsTab> createState() => _FriendsTabState();
}

class _FriendsTabState extends State<FriendsTab> {
  final FriendService _friendService = FriendService();
  final ChatService _chatService = ChatService();
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

  void _openChat(String friendId, String friendName, String? friendImage) {
    if (_currentUser == null) return;

    final chatId = _chatService.getChatId(_currentUser!.id, friendId);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          chatId: chatId,
          currentUserId: _currentUser!.id,
          otherUserId: friendId,
          otherUserName: friendName,
          otherUserImage: friendImage,
        ),
      ),
    );
  }

  Future<void> _removeFriend(String friendId, String friendName) async {
    if (_currentUser == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: Text('drawer.social.removeFriend'.tr(), style: const TextStyle(color: Colors.white)),
        content: Text(
          'drawer.social.removeFriendConfirm'.trParams({'0': friendName}), 
          style: const TextStyle(color: Colors.white70)
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('common.cancel'.tr(), style: const TextStyle(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('common.delete'.tr(), style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _friendService.removeFriend(_currentUser!.id, friendId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('drawer.social.friendRemoved'.tr()),
              backgroundColor: Colors.green.withOpacity(0.8),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 8,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Hata: $e'),
              backgroundColor: Colors.red.withOpacity(0.8),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 8,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUser == null) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFFE5B80B)));
    }

    return StreamBuilder<QuerySnapshot>(
      stream: _friendService.getFriends(_currentUser!.id),
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
                Icon(Icons.people_outline, size: 64, color: Colors.grey[800]),
                const SizedBox(height: 16),
                Text(
                  'drawer.social.noFriends'.tr(),
                  style: GoogleFonts.poppins(color: Colors.grey),
                ),
                TextButton(
                  onPressed: () {
                    // Switch to Search tab (parent controller)
                    DefaultTabController.of(context).animateTo(2);
                  },
                  child: Text('drawer.social.findFriends'.tr(), style: const TextStyle(color: Color(0xFFE5B80B))),
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
            final friendId = doc.id;
            final friendName = data['username'] ?? 'Bilinmeyen';
            final friendImage = data['profileImageUrl'];

            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.deepPurple.shade900.withOpacity(0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                onTap: () => _openChat(friendId, friendName, friendImage),
                leading: CircleAvatar(
                  backgroundColor: Colors.grey[800],
                  backgroundImage: friendImage != null
                      ? (friendImage.startsWith('assets/') 
                          ? AssetImage(friendImage) 
                          : NetworkImage(friendImage)) as ImageProvider
                      : null,
                  child: friendImage == null
                      ? Text(friendName.isNotEmpty ? friendName[0].toUpperCase() : '?')
                      : null,
                ),
                title: Text(
                  friendName,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chat_bubble_outline, color: Colors.purpleAccent),
                      onPressed: () => _openChat(friendId, friendName, friendImage),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () => _removeFriend(friendId, friendName),
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
}

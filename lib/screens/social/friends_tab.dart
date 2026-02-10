import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/friend_service.dart';
// import '../../services/chat_service.dart';
import '../../services/database_helper.dart';
import '../../models/user_model.dart';
import '../../widgets/modern_alert_dialog.dart';
import '../../services/localization_service.dart';
// import 'chat_screen.dart';
import '../../widgets/user_profile_avatar.dart';
import '../../services/interaction_service.dart';

class FriendsTab extends StatefulWidget {
  const FriendsTab({super.key});

  @override
  State<FriendsTab> createState() => _FriendsTabState();
}

class _FriendsTabState extends State<FriendsTab> {
  final FriendService _friendService = FriendService();
  // final ChatService _chatService = ChatService();
  final DatabaseHelper _databaseHelper = DatabaseHelper();
  final InteractionService _interactionService = InteractionService();

  User? _currentUser;

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
  }

  Future<void> _loadCurrentUser() async {
    final userMap = await _databaseHelper.getCurrentUser();
    if (userMap != null) {
      if (mounted) {
        setState(() {
          _currentUser = User.fromJson(userMap);
        });
      }
    }
  }

  Future<void> _sendRespect(String toUserId) async {
    if (_currentUser == null) return;

    final success = await _interactionService.sendRespect(
      _currentUser!.id,
      toUserId,
    );
    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('social.interaction.respect_sent'.tr()),
          backgroundColor: Colors.amber,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('social.interaction.already_respected'.tr()),
          backgroundColor: Colors.grey,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  /*
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
  */

  Future<void> _removeFriend(String friendId, String friendName) async {
    if (_currentUser == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => ModernAlertDialog(
        title: 'drawer.social.removeFriend'.tr(),
        content: Text(
          'drawer.social.removeFriendConfirm'.trParams({'0': friendName}),
          style: const TextStyle(color: Colors.white70),
        ),
        buttonText: 'common.delete'.tr(),
        onPressed: () => Navigator.pop(context, true),
        secondaryButtonText: 'common.cancel'.tr(),
        onSecondaryPressed: () => Navigator.pop(context, false),
        icon: Icons.person_remove,
        iconColor: Colors.redAccent,
      ),
    );

    if (confirm == true) {
      try {
        await _friendService.removeFriend(_currentUser!.id, friendId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('drawer.social.friendRemoved'.tr()),
              backgroundColor: Colors.green.withValues(alpha: 0.8),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 8,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Hata: $e'),
              backgroundColor: Colors.red.withValues(alpha: 0.8),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 8,
            ),
          );
        }
      }
    }
  }

  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
    String? tooltip,
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
        tooltip: tooltip,
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
      stream: _friendService.getFriends(_currentUser!.id),
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
                Icon(Icons.people_outline, size: 90, color: Colors.white),
                const SizedBox(height: 16),
                Text(
                  'drawer.social.noFriends'.tr(),
                  style: GoogleFonts.poppins(color: Colors.white, fontSize: 18),
                ),
                TextButton(
                  onPressed: () {
                    // Switch to Search tab (parent controller)
                    DefaultTabController.of(context).animateTo(2);
                  },
                  child: Text(
                    'drawer.social.findFriends'.tr(),
                    style: const TextStyle(
                      color: Color(0xFFE5B80B),
                      fontSize: 16,
                    ),
                  ),
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
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
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
                // onTap: () => _openChat(friendId, friendName, friendImage),
                leading: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white24, width: 2),
                  ),
                  child: UserProfileAvatar(
                    imageUrl: friendImage,
                    username: friendName,
                    radius: 22,
                    backgroundColor: Colors.grey[900],
                    textColor: Colors.white,
                  ),
                ),
                title: Text(
                  friendName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildActionButton(
                      icon: Icons.favorite_rounded,
                      color: Colors.pinkAccent,
                      tooltip: 'social.interaction.respect'.tr(),
                      onPressed: () => _sendRespect(friendId),
                    ),
                    /*
                    _buildActionButton(
                      icon: Icons.chat_bubble_rounded,
                      color: Colors.blueAccent,
                      onPressed: () =>
                          _openChat(friendId, friendName, friendImage),
                    ),
                    */
                    _buildActionButton(
                      icon: Icons.delete_rounded,
                      color: Colors.redAccent,
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

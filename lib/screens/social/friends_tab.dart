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
          content: Text('social_interaction.respect_sent'.tr()),
          backgroundColor: Colors.amber,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('social_interaction.already_respected'.tr()),
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

  Future<void> _confirmBlockUser(String userId, String username) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => ModernAlertDialog(
        title: 'social_interaction.blockConfirmTitle'.tr(),
        content: Text(
          'social_interaction.blockConfirmDesc'.trParams({'name': username}),
          style: const TextStyle(color: Colors.white70),
        ),
        buttonText: 'social_interaction.block'.tr(),
        onPressed: () => Navigator.pop(context, true),
        secondaryButtonText: 'common.cancel'.tr(),
        onSecondaryPressed: () => Navigator.pop(context, false),
        icon: Icons.block,
        iconColor: Colors.redAccent,
      ),
    );

    if (confirm == true) {
      try {
        await _interactionService.blockUser(_currentUser!.id, userId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('social_interaction.blockedEffect'.tr()),
              backgroundColor: Colors.black87,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('${'common.error'.tr()}: $e')));
        }
      }
    }
  }

  Future<void> _showReportDialog(String userId, String username) async {
    final reasonController = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => ModernAlertDialog(
        title: 'social_interaction.reportTitle'.tr(),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'social_interaction.reportDesc'.tr(),
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: InputDecoration(
                hintText: 'social_interaction.reportReason'.tr(),
                hintStyle: const TextStyle(color: Colors.white30),
                filled: true,
                fillColor: Colors.black26,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              maxLines: 3,
              style: const TextStyle(color: Colors.white),
            ),
          ],
        ),
        buttonText: 'social_interaction.report'.tr(),
        onPressed: () => Navigator.pop(context, true),
        secondaryButtonText: 'common.cancel'.tr(),
        onSecondaryPressed: () => Navigator.pop(context, false),
        icon: Icons.flag,
        iconColor: Colors.orangeAccent,
      ),
    );

    if (result == true) {
      try {
        await _interactionService.reportUser(
          _currentUser!.id,
          userId,
          'User Report',
          reasonController.text,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('social_interaction.reportSent'.tr()),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('${'common.error'.tr()}: $e')));
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
                      tooltip: 'social_interaction.respect'.tr(),
                      onPressed: () => _sendRespect(friendId),
                    ),
                    PopupMenuButton<String>(
                      icon: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.more_vert,
                          color: Colors.white70,
                          size: 20,
                        ),
                      ),
                      color: const Color(0xFF1E1E2C),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      onSelected: (value) {
                        if (value == 'remove') {
                          _removeFriend(friendId, friendName);
                        } else if (value == 'block') {
                          _confirmBlockUser(friendId, friendName);
                        } else if (value == 'report') {
                          _showReportDialog(friendId, friendName);
                        }
                      },
                      itemBuilder: (BuildContext context) =>
                          <PopupMenuEntry<String>>[
                            PopupMenuItem<String>(
                              value: 'remove',
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.person_remove,
                                    color: Colors.orangeAccent,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'drawer.social.removeFriend'.tr(),
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                ],
                              ),
                            ),
                            PopupMenuItem<String>(
                              value: 'report',
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.flag,
                                    color: Colors.white70,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'social_interaction.report'.tr(),
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                ],
                              ),
                            ),
                            PopupMenuItem<String>(
                              value: 'block',
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.block,
                                    color: Colors.redAccent,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'social_interaction.block'.tr(),
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                ],
                              ),
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
}

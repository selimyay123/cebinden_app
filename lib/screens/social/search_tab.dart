import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/friend_service.dart';
import '../../services/interaction_service.dart';
import '../../services/database_helper.dart';
import '../../services/localization_service.dart';
import '../../widgets/user_profile_avatar.dart';
import '../../widgets/modern_alert_dialog.dart';

class SearchTab extends StatefulWidget {
  const SearchTab({super.key});

  @override
  State<SearchTab> createState() => _SearchTabState();
}

class _SearchTabState extends State<SearchTab> {
  final TextEditingController _searchController = TextEditingController();
  final FriendService _friendService = FriendService();
  final InteractionService _interactionService = InteractionService();
  final DatabaseHelper _databaseHelper = DatabaseHelper();

  List<SocialUser> _searchResults = [];
  bool _isLoading = false;
  String? _currentUserId;
  Set<String> _blockedUserIds = {};

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
  }

  Future<void> _loadCurrentUser() async {
    final user = await _databaseHelper.getCurrentUser();
    if (user != null) {
      setState(() {
        _currentUserId = user['id'];
      });
      _fetchBlockedUsers();
    }
  }

  Future<void> _fetchBlockedUsers() async {
    if (_currentUserId == null) return;
    try {
      final blockedIds = await _interactionService.getBlockedUserIds(
        _currentUserId!,
      );
      if (mounted) {
        setState(() {
          _blockedUserIds = Set.from(blockedIds);
        });
      }
    } catch (e) {
      debugPrint('Error fetching blocked users: $e');
    }
  }

  Future<void> _performSearch(String query) async {
    if (query.isEmpty) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final results = await _friendService.searchUsers(query);
      setState(() {
        _searchResults = results;
        _isLoading = false;
      });
      // Refresh blocked list to ensure UI is up to date
      _fetchBlockedUsers();
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Hata: $e')));
      }
    }
  }

  Future<void> _sendRequest(String toUserId) async {
    if (_currentUserId == null) return;

    try {
      await _friendService.sendFriendRequest(_currentUserId!, toUserId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('drawer.social.requestSent'.tr()),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hata: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
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
        await _interactionService.blockUser(_currentUserId!, userId);
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
          // Refresh search results to remove blocked user
          _performSearch(_searchController.text);
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

  Future<void> _confirmUnblockUser(String userId, String username) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => ModernAlertDialog(
        title: 'social_interaction.unblock'.tr(),
        content: Text(
          'social_interaction.unblockConfirmDesc'.trParams({'name': username}),
          style: const TextStyle(color: Colors.white70),
        ),
        buttonText: 'social_interaction.unblock'.tr(),
        onPressed: () => Navigator.pop(context, true),
        secondaryButtonText: 'common.cancel'.tr(),
        onSecondaryPressed: () => Navigator.pop(context, false),
        icon: Icons.check_circle,
        iconColor: Colors.greenAccent,
      ),
    );

    if (confirm == true) {
      try {
        await _interactionService.unblockUser(_currentUserId!, userId);
        if (mounted) {
          setState(() {
            _blockedUserIds.remove(userId);
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('social_interaction.unblockedEffect'.tr()),
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
          _currentUserId!,
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
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextField(
            controller: _searchController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'drawer.social.searchHint'.tr(),
              hintStyle: TextStyle(color: Colors.grey[600]),
              prefixIcon: const Icon(Icons.search, color: Colors.grey),
              filled: true,
              fillColor: Colors.deepPurple.shade900.withValues(alpha: 0.5),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              suffixIcon: IconButton(
                icon: const Icon(
                  Icons.arrow_forward_rounded,
                  color: Colors.purpleAccent,
                ),
                onPressed: () => _performSearch(_searchController.text),
              ),
            ),
            onSubmitted: _performSearch,
          ),
        ),
        Expanded(
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: Color(0xFFE5B80B)),
                )
              : _searchResults.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.person_search, size: 90, color: Colors.white),
                      const SizedBox(height: 16),
                      Text(
                        'drawer.social.searchHint'.tr(),
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.only(bottom: 20),
                  itemCount: _searchResults.length,
                  itemBuilder: (context, index) {
                    final user = _searchResults[index];
                    if (user.id == _currentUserId) {
                      return const SizedBox.shrink();
                    }

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
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 12,
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildActionButton(
                              icon: Icons.person_add_rounded,
                              color: Colors.purpleAccent,
                              onPressed: () => _sendRequest(user.id),
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
                                if (value == 'block') {
                                  _confirmBlockUser(user.id, user.username);
                                } else if (value == 'unblock') {
                                  _confirmUnblockUser(user.id, user.username);
                                } else if (value == 'report') {
                                  _showReportDialog(user.id, user.username);
                                }
                              },
                              itemBuilder: (BuildContext context) =>
                                  <PopupMenuEntry<String>>[
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
                                            style: const TextStyle(
                                              color: Colors.white,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (_blockedUserIds.contains(user.id))
                                      PopupMenuItem<String>(
                                        value: 'unblock',
                                        child: Row(
                                          children: [
                                            const Icon(
                                              Icons.check_circle,
                                              color: Colors.greenAccent,
                                              size: 20,
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              'social_interaction.unblock'.tr(),
                                              style: const TextStyle(
                                                color: Colors.white,
                                              ),
                                            ),
                                          ],
                                        ),
                                      )
                                    else
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
                                              style: const TextStyle(
                                                color: Colors.white,
                                              ),
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
                ),
        ),
      ],
    );
  }
}

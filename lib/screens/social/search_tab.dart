import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/friend_service.dart';
import '../../services/database_helper.dart';
import '../../services/localization_service.dart';
import '../../widgets/user_profile_avatar.dart';
import '../../services/interaction_service.dart';

class SearchTab extends StatefulWidget {
  const SearchTab({super.key});

  @override
  State<SearchTab> createState() => _SearchTabState();
}

class _SearchTabState extends State<SearchTab> {
  final TextEditingController _searchController = TextEditingController();
  final FriendService _friendService = FriendService();
  final DatabaseHelper _databaseHelper = DatabaseHelper();
  final InteractionService _interactionService = InteractionService();

  List<SocialUser> _searchResults = [];
  bool _isLoading = false;
  String? _currentUserId;

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

  Future<void> _sendRespect(String toUserId) async {
    if (_currentUserId == null) return;

    final success = await _interactionService.sendRespect(
      _currentUserId!,
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
              fillColor: Colors.deepPurple.shade900.withOpacity(0.5),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              suffixIcon: IconButton(
                icon: const Icon(
                  Icons.arrow_forward,
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
                      Icon(
                        Icons.person_search,
                        size: 64,
                        color: Colors.grey[800],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'drawer.social.searchHint'.tr(),
                        style: GoogleFonts.poppins(color: Colors.grey),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _searchResults.length,
                  itemBuilder: (context, index) {
                    final user = _searchResults[index];
                    if (user.id == _currentUserId)
                      return const SizedBox.shrink();

                    return Container(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.deepPurple.shade900.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        leading: UserProfileAvatar(
                          imageUrl: user.profileImageUrl,
                          username: user.username,
                          radius: 20,
                          backgroundColor: Colors.grey[800],
                          textColor: Colors.white,
                        ),
                        title: Text(
                          user.username,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: Text(
                          'Seviye ${user.level}',
                          style: TextStyle(color: Colors.grey[400]),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(
                                Icons.thumb_up_alt_outlined,
                                color: Colors.amber,
                              ),
                              tooltip: 'social.interaction.respect'.tr(),
                              onPressed: () => _sendRespect(user.id),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.person_add,
                                color: Colors.purpleAccent,
                              ),
                              onPressed: () => _sendRequest(user.id),
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

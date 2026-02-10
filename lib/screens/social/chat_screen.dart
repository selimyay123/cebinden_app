import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../widgets/modern_alert_dialog.dart';
import '../../services/chat_service.dart';
import '../../services/localization_service.dart';
import '../../widgets/social_background.dart';
// import '../../utils/quick_chat_data.dart';

class ChatScreen extends StatefulWidget {
  final String chatId;
  final String currentUserId;
  final String otherUserId;
  final String otherUserName;
  final String? otherUserImage;

  const ChatScreen({
    super.key,
    required this.chatId,
    required this.currentUserId,
    required this.otherUserId,
    required this.otherUserName,
    this.otherUserImage,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ChatService _chatService = ChatService();
  final ScrollController _scrollController = ScrollController();
  // DateTime? _lastMessageTime;

  /*
  void _sendMessage(String messageKey) {
    // Basic flood protection: prevent sending more than one message every 2 seconds
    if (_lastMessageTime != null &&
        DateTime.now().difference(_lastMessageTime!) <
            const Duration(seconds: 2)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'social.chat.cooldown'.tr(
              defaultValue:
                  "Please wait a moment before sending another message.",
            ),
          ),
          backgroundColor: Colors.redAccent,
          duration: const Duration(milliseconds: 1500),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    _lastMessageTime = DateTime.now();

    _chatService.sendMessage(widget.chatId, messageKey, widget.currentUserId, [
      widget.currentUserId,
      widget.otherUserId,
    ]);

    // Scroll to bottom
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0, // Reverse list
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }
*/

  Future<void> _deleteMessage(String messageId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => ModernAlertDialog(
        title: 'drawer.social.deleteMessage'.tr(),
        content: Text(
          'drawer.social.deleteMessageConfirm'.tr(),
          style: const TextStyle(color: Colors.white70),
        ),
        buttonText: 'common.delete'.tr(),
        onPressed: () => Navigator.pop(context, true),
        secondaryButtonText: 'common.cancel'.tr(),
        onSecondaryPressed: () => Navigator.pop(context, false),
        icon: Icons.delete,
        iconColor: Colors.redAccent,
      ),
    );

    if (confirm == true) {
      await _chatService.deleteMessage(
        widget.chatId,
        messageId,
        widget.currentUserId,
      );
    }
  }

  Future<void> _clearChat() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => ModernAlertDialog(
        title: 'drawer.social.clearChat'.tr(),
        content: Text(
          'drawer.social.clearChatConfirm'.tr(),
          style: const TextStyle(color: Colors.white70),
        ),
        buttonText: 'common.delete'.tr(),
        onPressed: () => Navigator.pop(context, true),
        secondaryButtonText: 'common.cancel'.tr(),
        onSecondaryPressed: () => Navigator.pop(context, false),
        icon: Icons.delete_sweep,
        iconColor: Colors.redAccent,
      ),
    );

    if (confirm == true) {
      await _chatService.clearChat(widget.chatId, widget.currentUserId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('drawer.social.chatCleared'.tr()),
            backgroundColor: Colors.green.withValues(alpha: 0.8),
            action: SnackBarAction(
              label: 'OK',
              textColor: Colors.white,
              onPressed: () {},
            ),
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

  /*
  void _showQuickChatSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return DefaultTabController(
          length: QuickChatData.categories.length,
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.5,
            child: Column(
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[600],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'social.chat.quick_message'.tr(),
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                TabBar(
                  isScrollable: true,
                  labelColor: const Color(0xFFE5B80B),
                  unselectedLabelColor: Colors.grey,
                  indicatorColor: const Color(0xFFE5B80B),
                  tabs: QuickChatData.categories.map((category) {
                    return Tab(
                      text: category['labelKey'].toString().tr(),
                      icon: Text(
                        category['icon'] as String,
                        style: const TextStyle(fontSize: 20),
                      ),
                    );
                  }).toList(),
                ),
                Expanded(
                  child: TabBarView(
                    children: QuickChatData.categories.map((category) {
                      final messages = category['messages'] as List<String>;
                      return GridView.builder(
                        padding: const EdgeInsets.all(16),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              childAspectRatio: 2.5,
                              crossAxisSpacing: 10,
                              mainAxisSpacing: 10,
                            ),
                        itemCount: messages.length,
                        itemBuilder: (context, index) {
                          final msgKey = messages[index];
                          return Material(
                            color: Colors.deepPurple.shade800,
                            borderRadius: BorderRadius.circular(12),
                            child: InkWell(
                              onTap: () {
                                Navigator.pop(context); // Close sheet
                                _sendMessage(msgKey);
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  msgKey.tr(),
                                  style: GoogleFonts.poppins(
                                    color: Colors.white,
                                    fontSize: 13,
                                  ),
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
*/

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: Colors.deepPurple.shade900,
        title: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: Colors.grey[800],
              backgroundImage: widget.otherUserImage != null
                  ? (widget.otherUserImage!.startsWith('assets/')
                            ? AssetImage(widget.otherUserImage!)
                            : NetworkImage(widget.otherUserImage!))
                        as ImageProvider
                  : null,
              child: widget.otherUserImage == null
                  ? Text(
                      widget.otherUserName.isNotEmpty
                          ? widget.otherUserName[0].toUpperCase()
                          : '?',
                    )
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                widget.otherUserName,
                style: GoogleFonts.poppins(color: Colors.white, fontSize: 16),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            color: const Color(0xFF2C2C2C),
            onSelected: (value) {
              if (value == 'clear') {
                _clearChat();
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'clear',
                child: Row(
                  children: [
                    const Icon(Icons.delete_sweep, color: Colors.red, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'drawer.social.clearChat'.tr(),
                      style: const TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: SocialBackground(
        child: Column(
          children: [
            Expanded(
              child: StreamBuilder<DocumentSnapshot>(
                stream: _chatService.getChat(widget.chatId),
                builder: (context, chatSnapshot) {
                  Timestamp? clearedAt;
                  if (chatSnapshot.hasData && chatSnapshot.data!.exists) {
                    final data =
                        chatSnapshot.data!.data() as Map<String, dynamic>;
                    final clearedAtMap =
                        data['clearedAt'] as Map<String, dynamic>?;
                    if (clearedAtMap != null) {
                      clearedAt =
                          clearedAtMap[widget.currentUserId] as Timestamp?;
                    }
                  }

                  return StreamBuilder<QuerySnapshot>(
                    stream: _chatService.getMessages(
                      widget.chatId,
                      after: clearedAt,
                    ),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Center(
                          child: CircularProgressIndicator(
                            color: Color(0xFFE5B80B),
                          ),
                        );
                      }

                      final docs = snapshot.data!.docs;

                      // Filter deleted messages
                      final visibleDocs = docs.where((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        final deletedBy = List<String>.from(
                          data['deletedBy'] ?? [],
                        );
                        return !deletedBy.contains(widget.currentUserId);
                      }).toList();

                      return ListView.builder(
                        reverse: true,
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: visibleDocs.length,
                        itemBuilder: (context, index) {
                          final doc = visibleDocs[index];
                          final data = doc.data() as Map<String, dynamic>;
                          final isMe = data['senderId'] == widget.currentUserId;
                          final timestamp = data['timestamp'] as Timestamp?;
                          final time = timestamp != null
                              ? DateFormat('HH:mm').format(timestamp.toDate())
                              : '';

                          final rawText = data['text'] as String? ?? '';
                          final displayText =
                              rawText.startsWith('social.chat.msg.')
                              ? rawText.tr()
                              : rawText;

                          return Align(
                            alignment: isMe
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                              constraints: BoxConstraints(
                                maxWidth:
                                    MediaQuery.of(context).size.width * 0.75,
                              ),
                              decoration: BoxDecoration(
                                color: isMe
                                    ? Colors.purpleAccent
                                    : Colors.deepPurple.shade900.withValues(
                                        alpha: 0.8,
                                      ),
                                borderRadius: BorderRadius.only(
                                  topLeft: const Radius.circular(16),
                                  topRight: const Radius.circular(16),
                                  bottomLeft: isMe
                                      ? const Radius.circular(16)
                                      : const Radius.circular(0),
                                  bottomRight: isMe
                                      ? const Radius.circular(0)
                                      : const Radius.circular(16),
                                ),
                              ),
                              child: GestureDetector(
                                onLongPress: () =>
                                    _deleteMessage(docs[index].id),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      displayText,
                                      style: GoogleFonts.poppins(
                                        color: Colors.white,
                                        fontSize: 15,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      time,
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
            /*
            SafeArea(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.deepPurple.shade900,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 4,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: _showQuickChatSheet,
                    icon: const Icon(
                      Icons.chat_bubble_outline,
                      color: Colors.black,
                    ),
                    label: Text(
                      'social.chat.quick_message'.tr(),
                      style: GoogleFonts.poppins(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE5B80B), // Gold color
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                      elevation: 4,
                    ),
                  ),
                ),
              ),
            ),
            */
          ],
        ),
      ),
    );
  }
}

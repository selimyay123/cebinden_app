import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../services/chat_service.dart';
import '../../services/localization_service.dart';

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
  final TextEditingController _messageController = TextEditingController();
  final ChatService _chatService = ChatService();
  final ScrollController _scrollController = ScrollController();

  void _sendMessage() {
    if (_messageController.text.trim().isEmpty) return;

    _chatService.sendMessage(
      widget.chatId,
      _messageController.text.trim(),
      widget.currentUserId,
      [widget.currentUserId, widget.otherUserId],
    );

    _messageController.clear();
    // Scroll to bottom
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0, // Reverse list
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _deleteMessage(String messageId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: Text('drawer.social.deleteMessage'.tr(), style: const TextStyle(color: Colors.white)),
        content: Text('drawer.social.deleteMessageConfirm'.tr(), style: const TextStyle(color: Colors.white70)),
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
      await _chatService.deleteMessage(widget.chatId, messageId, widget.currentUserId);
    }
  }

  Future<void> _clearChat() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: Text('drawer.social.clearChat'.tr(), style: const TextStyle(color: Colors.white)),
        content: Text('drawer.social.clearChatConfirm'.tr(), style: const TextStyle(color: Colors.white70)),
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
      await _chatService.clearChat(widget.chatId, widget.currentUserId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('drawer.social.chatCleared'.tr()),
            backgroundColor: Colors.green.withOpacity(0.8),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 8,
          ),
        );
      }
    }
  }

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
                      : NetworkImage(widget.otherUserImage!)) as ImageProvider
                  : null,
              child: widget.otherUserImage == null
                  ? Text(widget.otherUserName.isNotEmpty ? widget.otherUserName[0].toUpperCase() : '?')
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
                    Text('drawer.social.clearChat'.tr(), style: const TextStyle(color: Colors.white)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/social_bg.jpeg'),
            fit: BoxFit.cover,
          ),
        ),
        child: Column(
          children: [
          Expanded(
            child: StreamBuilder<DocumentSnapshot>(
              stream: _chatService.getChat(widget.chatId),
              builder: (context, chatSnapshot) {
                Timestamp? clearedAt;
                if (chatSnapshot.hasData && chatSnapshot.data!.exists) {
                  final data = chatSnapshot.data!.data() as Map<String, dynamic>;
                  final clearedAtMap = data['clearedAt'] as Map<String, dynamic>?;
                  if (clearedAtMap != null) {
                    clearedAt = clearedAtMap[widget.currentUserId] as Timestamp?;
                  }
                }

                return StreamBuilder<QuerySnapshot>(
                  stream: _chatService.getMessages(widget.chatId, after: clearedAt),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator(color: Color(0xFFE5B80B)));
                    }

                    final docs = snapshot.data!.docs;
                    
                    // Filter deleted messages
                    final visibleDocs = docs.where((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final deletedBy = List<String>.from(data['deletedBy'] ?? []);
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

                    return Align(
                      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                        decoration: BoxDecoration(
                          color: isMe ? Colors.purpleAccent : Colors.deepPurple.shade900.withOpacity(0.8),
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(16),
                            topRight: const Radius.circular(16),
                            bottomLeft: isMe ? const Radius.circular(16) : const Radius.circular(0),
                            bottomRight: isMe ? const Radius.circular(0) : const Radius.circular(16),
                          ),
                        ),
                        child: GestureDetector(
                          onLongPress: () => _deleteMessage(docs[index].id),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                data['text'] ?? '',
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
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.deepPurple.shade900,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'drawer.social.sendMessage'.tr(),
                      hintStyle: TextStyle(color: Colors.grey[600]),
                      filled: true,
                      fillColor: Colors.deepPurple.shade800,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: Colors.purpleAccent,
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white),
                    onPressed: _sendMessage,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
    );
  }
}

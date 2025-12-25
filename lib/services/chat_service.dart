import 'package:cloud_firestore/cloud_firestore.dart';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get Chat ID (Deterministic)
  String getChatId(String userId1, String userId2) {
    final List<String> ids = [userId1, userId2];
    ids.sort(); // Sort to ensure same ID regardless of who starts
    return ids.join('_');
  }

  // Send Message
  Future<void> sendMessage(String chatId, String text, String senderId, List<String> participants) async {
    final batch = _firestore.batch();

    // 1. Add message
    final messageRef = _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .doc();
    
    batch.set(messageRef, {
      'senderId': senderId,
      'text': text,
      'timestamp': FieldValue.serverTimestamp(),
      'type': 'text',
    });

    // 2. Update chat metadata
    final chatRef = _firestore.collection('chats').doc(chatId);
    
    // Use set with merge to create if not exists
    batch.set(chatRef, {
      'participants': participants,
      'lastMessage': text,
      'lastMessageTime': FieldValue.serverTimestamp(),
      // We could add unread counts here with FieldValue.increment
    }, SetOptions(merge: true));

    await batch.commit();
  }



  // Delete Message (Soft Delete)
  Future<void> deleteMessage(String chatId, String messageId, String userId) async {
    await _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .doc(messageId)
        .update({
      'deletedBy': FieldValue.arrayUnion([userId]),
    });
  }

  // Clear Chat (Soft Clear)
  Future<void> clearChat(String chatId, String userId) async {
    await _firestore.collection('chats').doc(chatId).set({
      'clearedAt': {
        userId: FieldValue.serverTimestamp(),
      }
    }, SetOptions(merge: true));
  }

  // Get Chat Stream
  Stream<DocumentSnapshot> getChat(String chatId) {
    return _firestore.collection('chats').doc(chatId).snapshots();
  }

  // Get Messages Stream
  Stream<QuerySnapshot> getMessages(String chatId, {Timestamp? after}) {
    Query query = _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: true);

    if (after != null) {
      query = query.endBefore([after]); // descending olduğu için endBefore kullanıyoruz (daha yeni mesajlar)
    }

    return query.limit(50).snapshots();
  }

  // Get User Chats Stream
  Stream<QuerySnapshot> getUserChats(String userId) {
    return _firestore
        .collection('chats')
        .where('participants', arrayContains: userId)
        .orderBy('lastMessageTime', descending: true)
        .snapshots();
  }
}

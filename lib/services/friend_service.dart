import 'package:cloud_firestore/cloud_firestore.dart';

class SocialUser {
  final String id;
  final String username;
  final String? profileImageUrl;
  final int level;
  final bool isVip;

  SocialUser({
    required this.id,
    required this.username,
    this.profileImageUrl,
    required this.level,
    this.isVip = false,
  });

  factory SocialUser.fromMap(Map<String, dynamic> map, String id) {
    return SocialUser(
      id: id,
      username: map['username'] ?? '',
      profileImageUrl: map['profileImageUrl'],
      level: map['level'] ?? 1,
      isVip: map['isVip'] ?? false,
    );
  }
}

class FriendService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Send Friend Request
  Future<void> sendFriendRequest(String currentUserId, String toUserId) async {
    // Check if request already exists
    final existingRequest = await _firestore
        .collection('friend_requests')
        .where('fromId', isEqualTo: currentUserId)
        .where('toId', isEqualTo: toUserId)
        .where('status', isEqualTo: 'pending')
        .get();

    if (existingRequest.docs.isNotEmpty) {
      throw Exception('Request already sent');
    }

    // Check if already friends
    final friendDoc = await _firestore
        .collection('users')
        .doc(currentUserId)
        .collection('friends')
        .doc(toUserId)
        .get();

    if (friendDoc.exists) {
      throw Exception('Already friends');
    }

    await _firestore.collection('friend_requests').add({
      'fromId': currentUserId,
      'toId': toUserId,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // Accept Friend Request
  Future<void> acceptFriendRequest(
    String requestId,
    String fromUserId,
    String currentUserId,
    String currentUsername,
    String? currentUserImage,
    String fromUsername,
    String? fromUserImage,
  ) async {
    final batch = _firestore.batch();

    // 1. Update request status
    final requestRef = _firestore.collection('friend_requests').doc(requestId);
    batch.update(requestRef, {'status': 'accepted'});

    // 2. Add to current user's friends
    final currentUserFriendRef = _firestore
        .collection('users')
        .doc(currentUserId)
        .collection('friends')
        .doc(fromUserId);

    batch.set(currentUserFriendRef, {
      'username': fromUsername,
      'profileImageUrl': fromUserImage,
      'since': FieldValue.serverTimestamp(),
    });

    // 3. Add to sender's friends
    final senderFriendRef = _firestore
        .collection('users')
        .doc(fromUserId)
        .collection('friends')
        .doc(currentUserId);

    batch.set(senderFriendRef, {
      'username': currentUsername,
      'profileImageUrl': currentUserImage,
      'since': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  // Reject Friend Request
  Future<void> rejectFriendRequest(String requestId) async {
    await _firestore.collection('friend_requests').doc(requestId).update({
      'status': 'rejected',
    });
  }

  // Remove Friend
  Future<void> removeFriend(String currentUserId, String friendId) async {
    final batch = _firestore.batch();

    // 1. Remove from current user's friends
    final currentUserFriendRef = _firestore
        .collection('users')
        .doc(currentUserId)
        .collection('friends')
        .doc(friendId);

    batch.delete(currentUserFriendRef);

    // 2. Remove from friend's friends
    final otherUserFriendRef = _firestore
        .collection('users')
        .doc(friendId)
        .collection('friends')
        .doc(currentUserId);

    batch.delete(otherUserFriendRef);

    await batch.commit();
  }

  // Stream of Incoming Requests
  Stream<QuerySnapshot> getIncomingRequests(String currentUserId) {
    return _firestore
        .collection('friend_requests')
        .where('toId', isEqualTo: currentUserId)
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  // Stream of Friends
  Stream<QuerySnapshot> getFriends(String currentUserId) {
    return _firestore
        .collection('users')
        .doc(currentUserId)
        .collection('friends')
        .orderBy('username')
        .snapshots();
  }

  // Search Users
  Future<List<SocialUser>> searchUsers(
    String query, {
    String? currentUserId,
  }) async {
    if (query.isEmpty) return [];

    // Search in leaderboard collection
    final snapshot = await _firestore
        .collection('leaderboard')
        .where('username', isGreaterThanOrEqualTo: query)
        .where('username', isLessThan: '${query}z')
        .limit(20)
        .get();

    final users = snapshot.docs.map((doc) {
      return SocialUser.fromMap(doc.data(), doc.id);
    }).toList();

    if (currentUserId != null) {
      // Filter blocked users
      final blockedDocs = await _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('blocked')
          .get();

      final blockedIds = blockedDocs.docs.map((d) => d.id).toSet();

      // Also filter users who blocked me (if possible, but usually we can't see that without a lookup)
      // For now, just filter users I blocked

      return users.where((user) => !blockedIds.contains(user.id)).toList();
    }

    return users;
  }

  // Get User Details (for request display)
  Future<SocialUser?> getSocialUser(String userId) async {
    final doc = await _firestore.collection('leaderboard').doc(userId).get();
    if (doc.exists) {
      return SocialUser.fromMap(doc.data()!, doc.id);
    }
    return null;
  }
}

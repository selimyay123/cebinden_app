import 'package:cloud_firestore/cloud_firestore.dart';

class InteractionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Send "Respect" (Like) to a user
  // Returns true if successful, false if already liked (one time only)
  Future<bool> sendRespect(String fromUserId, String toUserId) async {
    // Unique ID for one-time interaction: from_to
    final interactionId = '${fromUserId}_$toUserId';

    final interactionRef = _firestore
        .collection('interactions')
        .doc(interactionId);

    // Check if interaction already exists using a transaction or just get
    final doc = await interactionRef.get();
    if (doc.exists) {
      return false; // Already liked
    }

    final batch = _firestore.batch();

    // 1. Create unique interaction record
    batch.set(interactionRef, {
      'fromId': fromUserId,
      'toId': toUserId,
      'type': 'respect',
      'timestamp': FieldValue.serverTimestamp(),
    });

    // 2. Increment receiver's respect count (in Leaderboard or User profile)
    // We update the 'leaderboard' collection as it's often used for public profiles
    final leaderboardRef = _firestore.collection('leaderboard').doc(toUserId);
    batch.set(leaderboardRef, {
      'respectCount': FieldValue.increment(1),
    }, SetOptions(merge: true));

    // Also update users collection just in case
    final userRef = _firestore.collection('users').doc(toUserId);
    batch.set(userRef, {
      'respectCount': FieldValue.increment(1),
    }, SetOptions(merge: true));

    await batch.commit();
    return true;
  }

  // Get Respect Count
  Future<int> getRespectCount(String userId) async {
    final doc = await _firestore.collection('leaderboard').doc(userId).get();
    if (doc.exists && doc.data()!.containsKey('respectCount')) {
      return doc.data()!['respectCount'] as int;
    }
    return 0;
  }

  // Check if I liked this user already
  Future<bool> hasLiked(String fromUserId, String toUserId) async {
    final interactionId = '${fromUserId}_$toUserId';
    final doc = await _firestore
        .collection('interactions')
        .doc(interactionId)
        .get();
    return doc.exists;
  }

  // Block a user
  Future<void> blockUser(String currentUserId, String blockedUserId) async {
    final batch = _firestore.batch();

    // 1. Add to blocked collection
    final blockedRef = _firestore
        .collection('users')
        .doc(currentUserId)
        .collection('blocked')
        .doc(blockedUserId);
    batch.set(blockedRef, {'blockedAt': FieldValue.serverTimestamp()});

    // 2. Remove from friends (both sides)
    final myFriendRef = _firestore
        .collection('users')
        .doc(currentUserId)
        .collection('friends')
        .doc(blockedUserId);
    batch.delete(myFriendRef);

    final theirFriendRef = _firestore
        .collection('users')
        .doc(blockedUserId)
        .collection('friends')
        .doc(currentUserId);
    batch.delete(theirFriendRef);

    // 3. Remove any pending friend requests (both directions)
    // We can't easily query inside a batch for delete without reading first.
    // For now, we'll do separate deletes for requests or query first.
    // Given the requirement for "Auto remove", the friend removal is invalidating the friend list.
    // Let's execute the batch for block+friend remove first.

    await batch.commit();

    // 4. Clean up requests (asynchronous, doesn't need to block UI)
    _removeFriendRequests(currentUserId, blockedUserId);
  }

  Future<void> _removeFriendRequests(String userId1, String userId2) async {
    // Delete requests where userId1 -> userId2
    final query1 = await _firestore
        .collection('friend_requests')
        .where('fromId', isEqualTo: userId1)
        .where('toId', isEqualTo: userId2)
        .get();

    // Delete requests where userId2 -> userId1
    final query2 = await _firestore
        .collection('friend_requests')
        .where('fromId', isEqualTo: userId2)
        .where('toId', isEqualTo: userId1)
        .get();

    final batch = _firestore.batch();
    for (var doc in query1.docs) {
      batch.delete(doc.reference);
    }
    for (var doc in query2.docs) {
      batch.delete(doc.reference);
    }

    if (query1.docs.isNotEmpty || query2.docs.isNotEmpty) {
      await batch.commit();
    }
  }

  // Unblock a user
  Future<void> unblockUser(String currentUserId, String blockedUserId) async {
    await _firestore
        .collection('users')
        .doc(currentUserId)
        .collection('blocked')
        .doc(blockedUserId)
        .delete();
  }

  // Check if specific user is blocked
  Future<bool> isBlocked(String currentUserId, String targetUserId) async {
    final doc = await _firestore
        .collection('users')
        .doc(currentUserId)
        .collection('blocked')
        .doc(targetUserId)
        .get();
    return doc.exists;
  }

  // Get list of blocked user IDs
  Future<List<String>> getBlockedUserIds(String currentUserId) async {
    final snapshot = await _firestore
        .collection('users')
        .doc(currentUserId)
        .collection('blocked')
        .get();

    return snapshot.docs.map((doc) => doc.id).toList();
  }

  // Report a user
  Future<void> reportUser(
    String reporterId,
    String reportedId,
    String reason,
    String description,
  ) async {
    await _firestore.collection('reports').add({
      'reporterId': reporterId,
      'reportedId': reportedId,
      'reason': reason,
      'description': description,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}

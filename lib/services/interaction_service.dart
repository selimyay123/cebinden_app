import 'package:cloud_firestore/cloud_firestore.dart';

class InteractionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Send "Respect" (Like) to a user
  // Returns true if successful, false if already liked today
  Future<bool> sendRespect(String fromUserId, String toUserId) async {
    final today = DateTime.now().toIso8601String().split('T')[0]; // YYYY-MM-DD
    final interactionId = '${fromUserId}_${toUserId}_$today';

    final interactionRef = _firestore
        .collection('interactions')
        .doc(interactionId);

    // Check if interaction already exists using a transaction or just get
    final doc = await interactionRef.get();
    if (doc.exists) {
      return false; // Already liked today
    }

    final batch = _firestore.batch();

    // 1. Create unique interaction record for today
    batch.set(interactionRef, {
      'fromId': fromUserId,
      'toId': toUserId,
      'type': 'respect',
      'timestamp': FieldValue.serverTimestamp(),
      'date': today,
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

  // Check if I liked this user today
  Future<bool> hasLikedToday(String fromUserId, String toUserId) async {
    final today = DateTime.now().toIso8601String().split('T')[0];
    final interactionId = '${fromUserId}_${toUserId}_$today';
    final doc = await _firestore
        .collection('interactions')
        .doc(interactionId)
        .get();
    return doc.exists;
  }
}

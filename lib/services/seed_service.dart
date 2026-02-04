import 'package:cloud_firestore/cloud_firestore.dart';
import '../data/mock_data.dart';
import '../utils/time_utils.dart';

class SeedService {
  SeedService._();
  static final instance = SeedService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> seedIfNeeded() async {
    final metaRef = _firestore.collection('meta').doc('seed');
    final metaDoc = await metaRef.get();
    if (metaDoc.exists) return;

    await _seedAll();
    await metaRef.set({
      'seededAt': TimeUtils.nowEt().toIso8601String(),
      'version': 1,
    });
  }

  Future<void> _seedAll() async {
    final batch = _firestore.batch();

    // Users (caregivers)
    for (final user in MockData.caregivers) {
      final ref = _firestore.collection('users').doc(user.uid);
      batch.set(ref, user.toJson());
    }

    // Group
    final groupRef = _firestore
        .collection('groups')
        .doc(MockData.group.groupId);
    batch.set(groupRef, MockData.group.toJson());

    // Care receiver
    final receiverRef = _firestore
        .collection('receivers')
        .doc(MockData.careReceiver.receiverId);
    batch.set(receiverRef, MockData.careReceiver.toJson());

    // Residence stats (subcollection)
    for (final entry in MockData.residenceStatsById.entries) {
      final stats = entry.value;
      final statsRef = receiverRef
          .collection('residence_stats')
          .doc(stats.residenceId);
      batch.set(statsRef, stats.toJson());
    }

    // Calls
    for (final call in MockData.allCalls) {
      final callRef = _firestore.collection('calls').doc(call.callId);
      batch.set(callRef, call.toJson());
    }

    await batch.commit();
  }
}

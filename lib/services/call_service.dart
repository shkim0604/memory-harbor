import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/call.dart';

class CallService {
  CallService._();
  static final instance = CallService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _callsCollection =>
      _firestore.collection('calls');

  Stream<List<Call>> streamCallsByGroup(String groupId) {
    return _callsCollection
        .where('groupId', isEqualTo: groupId)
        .snapshots()
        .map((snapshot) {
      final calls = snapshot.docs.map((doc) {
        final data = doc.data();
        return Call.fromJson({...data, 'callId': doc.id});
      }).toList();
      calls.sort((a, b) => b.startedAt.compareTo(a.startedAt));
      return calls;
    });
  }

  Stream<List<Call>> streamCallsByReceiver(String receiverId) {
    return _callsCollection
        .where('receiverId', isEqualTo: receiverId)
        .snapshots()
        .map((snapshot) {
      final calls = snapshot.docs.map((doc) {
        final data = doc.data();
        return Call.fromJson({...data, 'callId': doc.id});
      }).toList();
      calls.sort((a, b) => b.startedAt.compareTo(a.startedAt));
      return calls;
    });
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> streamCallDoc(String callId) {
    return _callsCollection.doc(callId).snapshots();
  }

  Future<void> createCall({
    required String callId,
    required String channelName,
    required String groupId,
    required String receiverId,
    required String caregiverUserId,
    required String groupNameSnapshot,
    required String giverNameSnapshot,
    required String receiverNameSnapshot,
    required DateTime startedAt,
    required DateTime endedAt,
    required int durationSec,
    required bool isConfirmed,
    String status = 'completed',
  }) async {
    final doc = _callsCollection.doc(callId);
    await doc.set({
      'callId': callId,
      'channelId': channelName,
      'channelName': channelName,
      'groupId': groupId,
      'receiverId': receiverId,
      'caregiverUserId': caregiverUserId,
      'groupNameSnapshot': groupNameSnapshot,
      'giverNameSnapshot': giverNameSnapshot,
      'receiverNameSnapshot': receiverNameSnapshot,
      'startedAt': startedAt,
      'endedAt': endedAt,
      'durationSec': durationSec,
      'status': status,
      'reviewCount': 0,
      'lastReviewAt': null,
      'isConfirmed': isConfirmed,
    });
  }
}

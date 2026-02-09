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

  Future<Map<String, dynamic>?> getCallDoc(String callId) async {
    final doc = await _callsCollection.doc(callId).get();
    return doc.data();
  }
}

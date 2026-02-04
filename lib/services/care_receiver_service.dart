import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/care_receiver.dart';
import '../models/residence.dart';

class CareReceiverService {
  CareReceiverService._();
  static final instance = CareReceiverService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _receiversCollection =>
      _firestore.collection('receivers');

  Stream<CareReceiver?> streamReceiver(String receiverId) {
    return _receiversCollection.doc(receiverId).snapshots().map((doc) {
      if (!doc.exists) return null;
      final data = doc.data();
      if (data == null) return null;
      return CareReceiver.fromJson({...data, 'receiverId': doc.id});
    });
  }

  Future<CareReceiver?> getReceiver(String receiverId) async {
    final doc = await _receiversCollection.doc(receiverId).get();
    if (!doc.exists) return null;
    final data = doc.data();
    if (data == null) return null;
    return CareReceiver.fromJson({...data, 'receiverId': doc.id});
  }

  Stream<List<ResidenceStats>> streamResidenceStats(String receiverId) {
    return _receiversCollection
        .doc(receiverId)
        .collection('residence_stats')
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            final data = doc.data();
            return ResidenceStats.fromJson({...data, 'residenceId': doc.id});
          }).toList();
        });
  }
}

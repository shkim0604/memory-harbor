import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/group.dart';

class GroupService {
  GroupService._();
  static final instance = GroupService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _groupsCollection =>
      _firestore.collection('groups');

  Stream<Group?> streamGroup(String groupId) {
    return _groupsCollection.doc(groupId).snapshots().map((doc) {
      if (!doc.exists) return null;
      final data = doc.data();
      if (data == null) return null;
      return Group.fromJson({...data, 'groupId': doc.id});
    });
  }

  Stream<Group?> streamAnyGroup() {
    return _groupsCollection.limit(1).snapshots().map((snapshot) {
      if (snapshot.docs.isEmpty) return null;
      final doc = snapshot.docs.first;
      final data = doc.data();
      return Group.fromJson({...data, 'groupId': doc.id});
    });
  }

  Future<Group?> getGroup(String groupId) async {
    final doc = await _groupsCollection.doc(groupId).get();
    if (!doc.exists) return null;
    final data = doc.data();
    if (data == null) return null;
    return Group.fromJson({...data, 'groupId': doc.id});
  }
}

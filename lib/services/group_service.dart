import 'package:cloud_firestore/cloud_firestore.dart';
import '../config/agora_config.dart';
import '../models/group.dart';
import 'api_client.dart';

class GroupService {
  GroupService._();
  static final instance = GroupService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ApiClient _api = ApiClient.instance;

  String get _apiBaseUrl => AgoraConfig.apiBaseUrl;

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

  Stream<Group?> streamGroupByReceiverId(String receiverId) {
    if (receiverId.isEmpty) {
      return const Stream<Group?>.empty();
    }
    return _groupsCollection
        .where('receiverId', isEqualTo: receiverId)
        .limit(1)
        .snapshots()
        .map((snapshot) {
      if (snapshot.docs.isEmpty) return null;
      final doc = snapshot.docs.first;
      final data = doc.data();
      return Group.fromJson({...data, 'groupId': doc.id});
    });
  }

  Future<bool> assignReceiverIfEmpty({
    required String groupId,
    required String receiverId,
  }) async {
    if (groupId.isEmpty || receiverId.isEmpty) return false;
    if (_apiBaseUrl.trim().isEmpty) return false;
    final url = '$_apiBaseUrl/api/group/assign-receiver';
    final result = await _api.postJson(url, {
      'groupId': groupId,
      'receiverId': receiverId,
    });
    if (result == null) return false;
    final assigned = result['assigned'];
    if (assigned is bool) return assigned;
    return true;
  }

  Future<List<Group>> listGroups() async {
    final snapshot = await _groupsCollection.get();
    return snapshot.docs
        .map((doc) => Group.fromJson({...doc.data(), 'groupId': doc.id}))
        .toList();
  }

  Future<Group?> getGroup(String groupId) async {
    final doc = await _groupsCollection.doc(groupId).get();
    if (!doc.exists) return null;
    final data = doc.data();
    if (data == null) return null;
    return Group.fromJson({...data, 'groupId': doc.id});
  }

  Future<Group?> getGroupByReceiverId(String receiverId) async {
    if (receiverId.isEmpty) return null;
    final snapshot = await _groupsCollection
        .where('receiverId', isEqualTo: receiverId)
        .limit(1)
        .get();
    if (snapshot.docs.isEmpty) return null;
    final doc = snapshot.docs.first;
    final data = doc.data();
    return Group.fromJson({...data, 'groupId': doc.id});
  }
}

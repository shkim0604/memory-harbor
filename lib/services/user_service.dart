import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../config/agora_config.dart';
import '../models/user.dart';
import '../services/api_client.dart';
import '../utils/time_utils.dart';

class UserService {
  UserService._();
  static final instance = UserService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ApiClient _api = ApiClient.instance;

  String get _apiBaseUrl => AgoraConfig.apiBaseUrl;

  CollectionReference<Map<String, dynamic>> get _usersCollection =>
      _firestore.collection('users');

  // Helper for push token registration.
  String? currentUid() => FirebaseAuth.instance.currentUser?.uid;

  // ============================================================================
  // Check if user exists in Firestore
  // ============================================================================
  Future<bool> userExists(String uid) async {
    if (_apiBaseUrl.trim().isEmpty) {
      throw Exception('API base URL is missing');
    }
    final url = '$_apiBaseUrl/api/user/exists';
    final result = await _api.postJson(url, {'uid': uid});
    if (result == null) {
      throw Exception('Failed to check user existence');
    }
    final exists = result['exists'];
    if (exists is bool) return exists;
    return false;
  }

  // ============================================================================
  // Get user by UID
  // ============================================================================
  Future<AppUser?> getUser(String uid) async {
    final doc = await _usersCollection.doc(uid).get();
    if (!doc.exists) return null;

    final data = doc.data();
    if (data == null) return null;

    return AppUser.fromJson({...data, 'uid': doc.id});
  }

  // ============================================================================
  // Get current user from Firestore
  // ============================================================================
  Future<AppUser?> getCurrentUser() async {
    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser == null) return null;
    return getUser(firebaseUser.uid);
  }

  // ============================================================================
  // Create new user
  // ============================================================================
  Future<AppUser> createUser({
    required String uid,
    required String name,
    required String email,
    String? profileImage,
    required String introMessage,
    required List<String> groupIds,
  }) async {
    if (_apiBaseUrl.trim().isEmpty) {
      throw Exception('API base URL is missing');
    }
    final url = '$_apiBaseUrl/api/user/create';
    final result = await _api.postJson(url, {
      'name': name,
      'email': email,
      if (profileImage != null) 'profileImage': profileImage,
      'introMessage': introMessage,
      'groupIds': groupIds,
    });
    if (result == null) {
      throw Exception('Failed to create user');
    }

    final fetched = await getUser(uid);
    if (fetched != null) return fetched;

    final now = TimeUtils.nowEt();
    return AppUser(
      uid: uid,
      name: name,
      email: email,
      profileImage: profileImage ?? '',
      introMessage: introMessage,
      groupIds: groupIds,
      createdAt: now,
      lastActivityAt: now,
    );
  }

  // ============================================================================
  // Update user
  // ============================================================================
  Future<void> updateUser(String uid, Map<String, dynamic> data) async {
    if (_apiBaseUrl.trim().isEmpty) {
      throw Exception('API base URL is missing');
    }
    final url = '$_apiBaseUrl/api/user/update';
    final ok = await _api.postJsonOk(url, {'uid': uid, ...data});
    if (!ok) {
      throw Exception('Failed to update user');
    }
  }

  // ============================================================================
  // Update user name
  // ============================================================================
  Future<void> updateUserName(String uid, String name) async {
    await updateUser(uid, {'name': name});
  }

  // ============================================================================
  // Update user profile image
  // ============================================================================
  Future<void> updateUserProfileImage(String uid, String profileImage) async {
    await updateUser(uid, {'profileImage': profileImage});
  }

  // ============================================================================
  // Update user intro message
  // ============================================================================
  Future<void> updateUserIntroMessage(String uid, String introMessage) async {
    await updateUser(uid, {'introMessage': introMessage});
  }

  // ============================================================================
  // Update user email
  // ============================================================================
  Future<void> updateUserEmail(String uid, String email) async {
    await updateUser(uid, {'email': email});
  }

  // ============================================================================
  // Delete user
  // ============================================================================
  Future<void> deleteUser(String uid) async {
    if (_apiBaseUrl.trim().isEmpty) {
      throw Exception('API base URL is missing');
    }
    final url = '$_apiBaseUrl/api/user/delete';
    final ok = await _api.postJsonOk(url, {'uid': uid});
    if (!ok) {
      throw Exception('Failed to delete user');
    }
  }

  // ============================================================================
  // Push token registration (server-side)
  // ============================================================================
  Future<void> updatePushTokens({
    String? fcmToken,
    String? apnsToken,
    String? voipToken,
    String? platform,
  }) async {
    if (_apiBaseUrl.trim().isEmpty) {
      throw Exception('API base URL is missing');
    }
    final url = '$_apiBaseUrl/api/user/push-tokens';
    final payload = <String, dynamic>{
      if (fcmToken != null && fcmToken.isNotEmpty) 'fcmToken': fcmToken,
      if (apnsToken != null && apnsToken.isNotEmpty) 'apnsToken': apnsToken,
      if (voipToken != null && voipToken.isNotEmpty) 'voipToken': voipToken,
      if (platform != null && platform.isNotEmpty) 'platform': platform,
    };
    if (payload.isEmpty) return;
    final ok = await _api.postJsonOk(url, payload);
    if (!ok) {
      throw Exception('Failed to update push tokens');
    }
  }

  // ============================================================================
  // Stream user changes
  // ============================================================================
  Stream<AppUser?> streamUser(String uid) {
    return _usersCollection.doc(uid).snapshots().map((doc) {
      if (!doc.exists) return null;
      final data = doc.data();
      if (data == null) return null;
      return AppUser.fromJson({...data, 'uid': doc.id});
    });
  }
}

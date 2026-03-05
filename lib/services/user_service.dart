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

  /// Check if the user has completed onboarding by reading Firestore directly.
  /// Unlike [userExists], this avoids backend API calls that may create
  /// the user document as a side effect.
  Future<bool> isUserOnboarded(String uid) async {
    try {
      final doc = await _usersCollection.doc(uid).get();
      if (!doc.exists) return false;
      final data = doc.data();
      if (data == null) return false;
      final groupIds = data['groupIds'];
      return groupIds is List && groupIds.isNotEmpty;
    } catch (_) {
      return false;
    }
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
    final payload = <String, dynamic>{
      'name': name,
      'email': email,
      'profileImage': profileImage,
      'introMessage': introMessage,
      'groupIds': groupIds,
    }..removeWhere((_, value) => value == null);
    final result = await _api.postJson(url, payload);
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
    final cleaned = profileImage.trim();
    if (cleaned.isEmpty) {
      throw Exception('profileImage URL is empty');
    }

    // Source of truth for client reads is Firestore users/{uid}.
    await _usersCollection.doc(uid).set({
      'profileImage': cleaned,
      'lastActivityAt': TimeUtils.nowEt().toIso8601String(),
    }, SetOptions(merge: true));

    // Keep backend in sync as best-effort without blocking UX.
    try {
      await updateUser(uid, {'profileImage': cleaned});
    } catch (_) {}
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
  // Request account deletion (30-day grace period)
  // ============================================================================
  Future<void> requestAccountDeletion({
    required String uid,
    required String email,
  }) async {
    final requestedAt = TimeUtils.nowEt();
    final scheduledDeleteAt = requestedAt.add(const Duration(days: 30));
    const notifyEmail = 'd.house0827@gmail.com';

    await _usersCollection.doc(uid).set({
      'deletionStatus': 'requested',
      'deletionRequestedAt': requestedAt.toIso8601String(),
      'scheduledDeletionAt': scheduledDeleteAt.toIso8601String(),
      'lastActivityAt': requestedAt.toIso8601String(),
    }, SetOptions(merge: true));

    await _firestore.collection('userDeletionRequests').doc(uid).set({
      'uid': uid,
      'email': email,
      'status': 'requested',
      'requestedAt': requestedAt.toIso8601String(),
      'scheduledDeleteAt': scheduledDeleteAt.toIso8601String(),
      'notifyEmail': notifyEmail,
    }, SetOptions(merge: true));

    if (_apiBaseUrl.trim().isEmpty) {
      throw Exception('API base URL is missing');
    }

    final payload = <String, dynamic>{
      'uid': uid,
      'email': email,
      'notifyEmail': notifyEmail,
      'requestedAt': requestedAt.toIso8601String(),
      'scheduledDeleteAt': scheduledDeleteAt.toIso8601String(),
    };

    final primaryUrl = '$_apiBaseUrl/api/user/delete-request';
    final secondaryUrl = '$_apiBaseUrl/api/user/deletion-request';
    final sentPrimary = await _api.postJsonOk(primaryUrl, payload);
    final sentSecondary = sentPrimary
        ? true
        : await _api.postJsonOk(secondaryUrl, payload);
    if (!sentSecondary) {
      throw Exception('Failed to send account deletion request email');
    }

    await _firestore.collection('userDeletionRequests').doc(uid).set({
      'emailSent': true,
      'emailSentAt': TimeUtils.nowEt().toIso8601String(),
    }, SetOptions(merge: true));
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

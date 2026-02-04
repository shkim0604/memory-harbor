import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user.dart';

class UserService {
  UserService._();
  static final instance = UserService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _usersCollection =>
      _firestore.collection('users');

  // Helper for push token registration.
  String? currentUid() => FirebaseAuth.instance.currentUser?.uid;

  // ============================================================================
  // Check if user exists in Firestore
  // ============================================================================
  Future<bool> userExists(String uid) async {
    final doc = await _usersCollection.doc(uid).get();
    return doc.exists;
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
  }) async {
    final now = DateTime.now();
    final user = AppUser(
      uid: uid,
      name: name,
      email: email,
      profileImage: profileImage ?? '',
      groupIds: [],
      createdAt: now,
      lastActivityAt: now,
    );

    await _usersCollection.doc(uid).set(user.toJson());
    return user;
  }

  // ============================================================================
  // Update user
  // ============================================================================
  Future<void> updateUser(String uid, Map<String, dynamic> data) async {
    await _usersCollection.doc(uid).update({
      ...data,
      'lastActivityAt': DateTime.now().toIso8601String(),
    });
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
  // Update user email
  // ============================================================================
  Future<void> updateUserEmail(String uid, String email) async {
    await updateUser(uid, {'email': email});
  }

  // ============================================================================
  // Delete user
  // ============================================================================
  Future<void> deleteUser(String uid) async {
    await _usersCollection.doc(uid).delete();
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

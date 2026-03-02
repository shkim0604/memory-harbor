import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/models.dart';
import '../services/user_service.dart';

class ReviewsViewModel {
  static const int pageSize = 10;
  final List<Review> reviews = [];
  DocumentSnapshot<Map<String, dynamic>>? _lastCallDoc;
  String? _groupId;
  bool isLoading = false;
  bool hasMore = true;
  String? errorMessage;

  Future<void> refresh() async {
    reviews.clear();
    _lastCallDoc = null;
    hasMore = true;
    errorMessage = null;
    await loadMore();
  }

  Future<void> loadMore() async {
    if (isLoading || !hasMore) return;
    isLoading = true;
    errorMessage = null;
    debugPrint('[REVIEWS] loadMore start lastCallDoc=${_lastCallDoc?.id} hasMore=$hasMore');

    try {
      if (_groupId == null) {
        _groupId = await _resolveGroupId();
      }
      if (_groupId == null || _groupId!.isEmpty) {
        hasMore = false;
        errorMessage = '그룹 정보를 찾을 수 없습니다';
        debugPrint('[REVIEWS] loadMore failed: groupId not found');
        return;
      }

      final List<Review> batchReviews = [];

      Query<Map<String, dynamic>> callQuery = FirebaseFirestore.instance
          .collection('calls')
          .where('groupId', isEqualTo: _groupId)
          .where('reviewCount', isGreaterThan: 0)
          .orderBy('reviewCount', descending: true)
          .orderBy('createdAt', descending: true)
          .limit(pageSize);

      if (_lastCallDoc != null) {
        callQuery = callQuery.startAfterDocument(_lastCallDoc!);
      }

      final callSnapshot = await callQuery.get();
      final callDocs = callSnapshot.docs;
      if (callDocs.isEmpty) {
        hasMore = false;
        debugPrint('[REVIEWS] loadMore empty calls');
        return;
      }

      for (final callDoc in callDocs) {
        final callId = callDoc.id;
        final reviewsSnap = await callDoc.reference
            .collection('reviews')
            .orderBy('createdAt', descending: true)
            .get();
        if (reviewsSnap.docs.isEmpty) continue;
        for (final doc in reviewsSnap.docs) {
          final data = Map<String, dynamic>.from(doc.data());
          data['reviewId'] = doc.id;
          data['callId'] = data['callId'] ?? callId;
          final mentioned = data['mentionedResidences'];
          if (mentioned is List &&
              mentioned.isNotEmpty &&
              mentioned.first is String) {
            data['mentionedResidences'] = const [];
          }
          batchReviews.add(Review.fromJson(data));
        }
      }

      batchReviews.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      reviews.addAll(batchReviews);
      _lastCallDoc = callDocs.last;
      hasMore = callDocs.length == pageSize;

      debugPrint(
        '[REVIEWS] loadMore success calls=${callDocs.length} reviews=${batchReviews.length} hasMore=$hasMore',
      );
    } catch (e) {
      errorMessage = '리뷰를 불러올 수 없습니다';
      hasMore = false;
      debugPrint('[REVIEWS] loadMore failed: $e');
    } finally {
      isLoading = false;
      debugPrint('[REVIEWS] loadMore done isLoading=$isLoading');
    }
  }

  Future<String?> _resolveGroupId() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;
    try {
      final user = await UserService.instance.getUser(uid);
      if (user == null || user.groupIds.isEmpty) return null;
      return user.groupIds.first;
    } catch (_) {
      return null;
    }
  }
}

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/models.dart';
import '../services/review_service.dart';
import '../services/user_service.dart';

class ReviewsViewModel {
  static const int pageSize = 10;
  final List<Review> reviews = [];
  String? _nextCursor;
  String? _groupId;
  bool isLoading = false;
  bool hasMore = true;
  String? errorMessage;

  Future<void> refresh() async {
    reviews.clear();
    _nextCursor = null;
    hasMore = true;
    errorMessage = null;
    await loadMore();
  }

  Future<void> loadMore() async {
    if (isLoading || !hasMore) return;
    isLoading = true;
    errorMessage = null;
    debugPrint('[REVIEWS] loadMore start cursor=$_nextCursor hasMore=$hasMore');

    try {
      _groupId ??= await _resolveGroupId();
      if (_groupId == null || _groupId!.isEmpty) {
        hasMore = false;
        errorMessage = '그룹 정보를 찾을 수 없습니다';
        debugPrint('[REVIEWS] loadMore failed: groupId not found');
        return;
      }

      final page = await ReviewService.instance.fetchFeed(
        groupId: _groupId!,
        limit: pageSize,
        cursor: _nextCursor,
      );

      reviews.addAll(page.items);
      _nextCursor = page.nextCursor;
      hasMore = page.hasMore;

      debugPrint(
        '[REVIEWS] loadMore success reviews=${page.items.length} nextCursor=$_nextCursor hasMore=$hasMore',
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

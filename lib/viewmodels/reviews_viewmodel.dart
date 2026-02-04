import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/models.dart';

class ReviewsViewModel {
  static const int pageSize = 10;
  final List<Review> reviews = [];
  DocumentSnapshot<Map<String, dynamic>>? _lastDoc;
  bool isLoading = false;
  bool hasMore = true;

  Future<void> refresh() async {
    reviews.clear();
    _lastDoc = null;
    hasMore = true;
    await loadMore();
  }

  Future<void> loadMore() async {
    if (isLoading || !hasMore) return;
    isLoading = true;

    Query<Map<String, dynamic>> query = FirebaseFirestore.instance
        .collectionGroup('reviews')
        .orderBy('createdAt', descending: true)
        .limit(pageSize);

    if (_lastDoc != null) {
      query = query.startAfterDocument(_lastDoc!);
    }

    final snapshot = await query.get();
    final docs = snapshot.docs;
    if (docs.isEmpty) {
      hasMore = false;
      isLoading = false;
      return;
    }

    final newReviews = docs.map((doc) {
      final data = Map<String, dynamic>.from(doc.data());
      data['reviewId'] = doc.id;
      final mentioned = data['mentionedResidences'];
      if (mentioned is List && mentioned.isNotEmpty && mentioned.first is String) {
        data['mentionedResidences'] = const [];
      }
      return Review.fromJson(data);
    }).toList();

    reviews.addAll(newReviews);
    _lastDoc = docs.last;
    hasMore = docs.length == pageSize;
    isLoading = false;
  }
}

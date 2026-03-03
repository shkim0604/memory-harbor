import 'package:flutter/foundation.dart';

import '../config/agora_config.dart';
import '../models/models.dart';
import 'api_client.dart';

const String _tag = '[RVS]'; // ReviewService log prefix

class ReviewFeedPage {
  final List<Review> items;
  final String? nextCursor;
  final bool hasMore;

  const ReviewFeedPage({
    required this.items,
    required this.nextCursor,
    required this.hasMore,
  });
}

class ReviewTopicOptionData {
  final String topicType; // residence | meaning
  final String topicId;
  final String label;
  final String question;
  final Map<String, dynamic>? residencePayload;

  const ReviewTopicOptionData({
    required this.topicType,
    required this.topicId,
    required this.label,
    required this.question,
    this.residencePayload,
  });

  String get value => '$topicType::$topicId';
}

class ReviewContextData {
  final String humanNotes;
  final String? selectedTopicType;
  final String? selectedTopicId;
  final String? selectedResidenceId;
  final String? selectedMeaningId;
  final List<ReviewTopicOptionData> topicOptions;

  const ReviewContextData({
    required this.humanNotes,
    required this.topicOptions,
    this.selectedTopicType,
    this.selectedTopicId,
    this.selectedResidenceId,
    this.selectedMeaningId,
  });
}

class ExistingMyReviewData {
  final String reviewId;
  final int? listeningScore;
  final String notFullyHeardMoment;
  final String nextSessionTry;
  final String emotionWord;
  final String emotionSource;
  final String smallReset;
  final String? selectedTopicType;
  final String? selectedTopicId;
  final String? selectedResidenceId;
  final String? selectedMeaningId;
  final List<Map<String, dynamic>> mentionedResidences;

  const ExistingMyReviewData({
    required this.reviewId,
    required this.notFullyHeardMoment,
    required this.nextSessionTry,
    required this.emotionWord,
    required this.emotionSource,
    required this.smallReset,
    required this.mentionedResidences,
    this.listeningScore,
    this.selectedTopicType,
    this.selectedTopicId,
    this.selectedResidenceId,
    this.selectedMeaningId,
  });
}

class ReviewUpsertRequest {
  final String callId;
  final String? existingMyReviewDocId;
  final int listeningScore;
  final String notFullyHeardMoment;
  final String nextSessionTry;
  final String emotionWord;
  final String emotionSource;
  final String smallReset;
  final String callMemo;
  final String? selectedTopicType;
  final String? selectedTopicId;
  final String? selectedTopicLabel;
  final String? selectedTopicQuestion;
  final String? selectedResidenceId;
  final String? selectedMeaningId;
  final List<Map<String, dynamic>> mentionedResidences;
  final DateTime requiredStepOpenedAt;
  final int requiredDurationSec;

  const ReviewUpsertRequest({
    required this.callId,
    required this.listeningScore,
    required this.notFullyHeardMoment,
    required this.nextSessionTry,
    required this.emotionWord,
    required this.emotionSource,
    required this.smallReset,
    required this.callMemo,
    required this.mentionedResidences,
    required this.requiredStepOpenedAt,
    required this.requiredDurationSec,
    this.existingMyReviewDocId,
    this.selectedTopicType,
    this.selectedTopicId,
    this.selectedTopicLabel,
    this.selectedTopicQuestion,
    this.selectedResidenceId,
    this.selectedMeaningId,
  });
}

/// Reviews API 전용 Service.
///
/// 서버 API 실패 시 fallback 없이 즉시 실패를 반환한다.
class ReviewService {
  ReviewService._();
  static final ReviewService instance = ReviewService._();

  String get _baseUrl => AgoraConfig.apiBaseUrl.trim();

  Future<ReviewFeedPage> fetchFeed({
    required String groupId,
    int limit = 10,
    String? cursor,
  }) async {
    final apiPage = await _fetchFeedFromApi(
      groupId: groupId,
      limit: limit,
      cursor: cursor,
    );
    if (apiPage != null) {
      return apiPage;
    }
    throw StateError('reviews feed api failed');
  }

  Future<ReviewFeedPage?> _fetchFeedFromApi({
    required String groupId,
    required int limit,
    String? cursor,
  }) async {
    if (_baseUrl.isEmpty) return null;
    try {
      final uri = Uri.parse('$_baseUrl/api/reviews/feed').replace(
        queryParameters: <String, String>{
          'group_id': groupId,
          'limit': '$limit',
          if (cursor != null && cursor.trim().isNotEmpty)
            'cursor': cursor.trim(),
        },
      );
      final json = await ApiClient.instance.getJson(uri.toString());
      if (json == null) return null;
      final rawItems = json['items'];
      if (rawItems is! List) return null;

      final items = <Review>[];
      for (final raw in rawItems) {
        if (raw is! Map) continue;
        final data = Map<String, dynamic>.from(raw);
        final mentioned = data['mentionedResidences'];
        if (mentioned is List && mentioned.isNotEmpty && mentioned.first is String) {
          data['mentionedResidences'] = const [];
        }
        items.add(Review.fromJson(data));
      }

      final nextCursor = (json['nextCursor'] ?? '').toString().trim();
      final hasMore =
          json['hasMore'] is bool
              ? json['hasMore'] as bool
              : nextCursor.isNotEmpty;
      debugPrint(
        '$_tag fetchFeed api success group=$groupId items=${items.length} hasMore=$hasMore',
      );
      return ReviewFeedPage(
        items: items,
        nextCursor: nextCursor.isNotEmpty ? nextCursor : null,
        hasMore: hasMore,
      );
    } catch (e) {
      debugPrint('$_tag fetchFeed api failed: $e');
      return null;
    }
  }

  Future<ReviewContextData?> fetchContext({required String callId}) async {
    if (_baseUrl.isEmpty) return null;
    try {
      final uri = Uri.parse('$_baseUrl/api/reviews/context').replace(
        queryParameters: <String, String>{'call_id': callId},
      );
      final json = await ApiClient.instance.getJson(uri.toString());
      if (json == null) return null;

      final humanNotes = (json['humanNotes'] ?? '').toString();
      final selectedTopicType = (json['selectedTopicType'] ?? '').toString().trim();
      final selectedTopicId = (json['selectedTopicId'] ?? '').toString().trim();
      final selectedResidenceId =
          (json['selectedResidenceId'] ?? '').toString().trim();
      final selectedMeaningId = (json['selectedMeaningId'] ?? '').toString().trim();
      final topicOptions = _parseTopicOptions(json['topicOptions']);
      if (topicOptions.isEmpty) {
        debugPrint('$_tag fetchContext api failed: empty topicOptions');
        return null;
      }

      return ReviewContextData(
        humanNotes: humanNotes,
        topicOptions: topicOptions,
        selectedTopicType: selectedTopicType.isNotEmpty ? selectedTopicType : null,
        selectedTopicId: selectedTopicId.isNotEmpty ? selectedTopicId : null,
        selectedResidenceId:
            selectedResidenceId.isNotEmpty ? selectedResidenceId : null,
        selectedMeaningId: selectedMeaningId.isNotEmpty ? selectedMeaningId : null,
      );
    } catch (e) {
      debugPrint('$_tag fetchContext api failed: $e');
      return null;
    }
  }

  Future<ExistingMyReviewData?> fetchMyReview({required String callId}) async {
    if (_baseUrl.isEmpty) return null;
    try {
      final uri = Uri.parse('$_baseUrl/api/reviews/my').replace(
        queryParameters: <String, String>{'call_id': callId},
      );
      final json = await ApiClient.instance.getJson(uri.toString());
      if (json == null) return null;
      final raw = json['review'] ?? json['item'] ?? json;
      if (raw is! Map) return null;
      return _parseExistingMyReview(Map<String, dynamic>.from(raw));
    } catch (e) {
      debugPrint('$_tag fetchMyReview api failed: $e');
      return null;
    }
  }

  Future<bool> upsertReview(ReviewUpsertRequest request) async {
    if (_baseUrl.isEmpty) return false;
    final json = await ApiClient.instance.postJson(
      '$_baseUrl/api/reviews/upsert',
      <String, dynamic>{
        'callId': request.callId,
        if (request.existingMyReviewDocId != null)
          'existingReviewId': request.existingMyReviewDocId,
        'listeningScore': request.listeningScore,
        'notFullyHeardMoment': request.notFullyHeardMoment,
        'nextSessionTry': request.nextSessionTry,
        'emotionWord': request.emotionWord,
        'emotionSource': request.emotionSource,
        'smallReset': request.smallReset,
        'callMemo': request.callMemo,
        'selectedTopicType': request.selectedTopicType,
        'selectedTopicId': request.selectedTopicId,
        'selectedTopicLabel': request.selectedTopicLabel,
        'selectedTopicQuestion': request.selectedTopicQuestion,
        'selectedResidenceId': request.selectedResidenceId,
        'selectedMeaningId': request.selectedMeaningId,
        'mentionedResidences': request.mentionedResidences,
        'requiredQuestionDurationSec': request.requiredDurationSec,
        'requiredStepOpenedAt': request.requiredStepOpenedAt.toIso8601String(),
      },
    );
    final ok = json != null;
    if (ok) {
      debugPrint('$_tag upsertReview api success callId=${request.callId}');
    } else {
      debugPrint('$_tag upsertReview api failed callId=${request.callId}');
    }
    return ok;
  }

  List<ReviewTopicOptionData> _parseTopicOptions(dynamic rawTopicOptions) {
    if (rawTopicOptions is! List) return const [];
    final options = <ReviewTopicOptionData>[];
    for (final raw in rawTopicOptions) {
      if (raw is! Map) continue;
      final data = Map<String, dynamic>.from(raw);
      final topicType = (data['topicType'] ?? data['type'] ?? '').toString().trim();
      final topicId = (data['topicId'] ?? data['id'] ?? '').toString().trim();
      if (topicType.isEmpty || topicId.isEmpty) continue;
      options.add(
        ReviewTopicOptionData(
          topicType: topicType,
          topicId: topicId,
          label: (data['label'] ?? '').toString(),
          question: (data['question'] ?? '').toString(),
          residencePayload: data['residencePayload'] is Map
              ? Map<String, dynamic>.from(data['residencePayload'] as Map)
              : null,
        ),
      );
    }
    return options;
  }

  ExistingMyReviewData _parseExistingMyReview(Map<String, dynamic> data) {
    return ExistingMyReviewData(
      reviewId: (data['reviewId'] ?? data['id'] ?? '').toString(),
      listeningScore: data['listeningScore'] is int
          ? data['listeningScore'] as int
          : (data['listeningScore'] is num)
              ? (data['listeningScore'] as num).toInt()
              : null,
      notFullyHeardMoment: (data['notFullyHeardMoment'] ?? '').toString(),
      nextSessionTry: (data['nextSessionTry'] ?? '').toString(),
      emotionWord: (data['emotionWord'] ?? data['mood'] ?? '').toString(),
      emotionSource: (data['emotionSource'] ?? '').toString(),
      smallReset: (data['smallReset'] ?? '').toString(),
      selectedTopicType: _nullableString(data['selectedTopicType']),
      selectedTopicId: _nullableString(data['selectedTopicId']),
      selectedResidenceId: _nullableString(data['selectedResidenceId']),
      selectedMeaningId: _nullableString(data['selectedMeaningId']),
      mentionedResidences: _normalizeMentionedResidences(
        data['mentionedResidences'],
      ),
    );
  }

  String? _nullableString(dynamic value) {
    final s = (value ?? '').toString().trim();
    return s.isEmpty ? null : s;
  }

  List<Map<String, dynamic>> _normalizeMentionedResidences(dynamic raw) {
    if (raw is! List) return const [];
    final result = <Map<String, dynamic>>[];
    for (final item in raw) {
      if (item is! Map) continue;
      result.add(Map<String, dynamic>.from(item));
    }
    return result;
  }
}

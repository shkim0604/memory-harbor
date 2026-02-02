import 'model_helpers.dart';
import 'residence.dart';

class Review {
  final String reviewId;
  final String callId;
  final String writerUserId;
  final String writerNameSnapshot;
  final List<Residence> mentionedResidences;
  final String humanSummary;
  final List<String> humanKeywords;
  final String mood;
  final String comment;
  final DateTime createdAt;

  const Review({
    required this.reviewId,
    required this.callId,
    required this.writerUserId,
    required this.writerNameSnapshot,
    this.mentionedResidences = const [],
    this.humanSummary = '',
    this.humanKeywords = const [],
    this.mood = '',
    this.comment = '',
    required this.createdAt,
  });

  factory Review.fromJson(Map<String, dynamic> json) => Review(
        reviewId: (json['reviewId'] ?? '') as String,
        callId: (json['callId'] ?? '') as String,
        writerUserId: (json['writerUserId'] ?? '') as String,
        writerNameSnapshot: (json['writerNameSnapshot'] ?? '') as String,
        mentionedResidences: (json['mentionedResidences'] is List)
            ? (json['mentionedResidences'] as List)
                .map((e) => Residence.fromJson(Map<String, dynamic>.from(e)))
                .toList()
            : const [],
        humanSummary: (json['humanSummary'] ?? '') as String,
        humanKeywords: List<String>.from(json['humanKeywords'] ?? const []),
        mood: (json['mood'] ?? '') as String,
        comment: (json['comment'] ?? '') as String,
        createdAt: parseDateTime(json['createdAt']) ?? DateTime.fromMillisecondsSinceEpoch(0),
      );

  Map<String, dynamic> toJson() => {
        'reviewId': reviewId,
        'callId': callId,
        'writerUserId': writerUserId,
        'writerNameSnapshot': writerNameSnapshot,
        'mentionedResidences': mentionedResidences.map((e) => e.toJson()).toList(),
        'humanSummary': humanSummary,
        'humanKeywords': humanKeywords,
        'mood': mood,
        'comment': comment,
        'createdAt': createdAt.toIso8601String(),
      };
}

import 'model_helpers.dart';
import 'residence.dart';
import 'review.dart';

class Call {
  final String callId;
  final String groupId;
  final String receiverId;
  final String caregiverUserId;
  final String groupNameSnapshot;
  final String giverNameSnapshot;
  final String receiverNameSnapshot;
  final DateTime startedAt;
  final DateTime? endedAt;
  final int? durationSec;
  final CallStatus status;
  final String? recordingUrl;
  final List<Residence> mentionedResidences;
  final List<String> humanKeywords;
  final String humanSummary;
  final String humanNotes;
  final String aiSummary;
  final int reviewCount;
  final DateTime? lastReviewAt;
  final List<Review>? reviews;

  const Call({
    required this.callId,
    required this.groupId,
    required this.receiverId,
    required this.caregiverUserId,
    required this.groupNameSnapshot,
    required this.giverNameSnapshot,
    required this.receiverNameSnapshot,
    required this.startedAt,
    this.endedAt,
    this.durationSec,
    this.status = CallStatus.completed,
    this.recordingUrl,
    this.mentionedResidences = const [],
    this.humanKeywords = const [],
    this.humanSummary = '',
    this.humanNotes = '',
    this.aiSummary = '',
    this.reviewCount = 0,
    this.lastReviewAt,
    this.reviews,
  });

  factory Call.fromJson(Map<String, dynamic> json) => Call(
        callId: (json['callId'] ?? '') as String,
        groupId: (json['groupId'] ?? '') as String,
        receiverId: (json['receiverId'] ?? '') as String,
        caregiverUserId: (json['caregiverUserId'] ?? '') as String,
        groupNameSnapshot: (json['groupNameSnapshot'] ?? '') as String,
        giverNameSnapshot: (json['giverNameSnapshot'] ?? '') as String,
        receiverNameSnapshot: (json['receiverNameSnapshot'] ?? '') as String,
        startedAt: parseDateTime(json['startedAt']) ?? DateTime.fromMillisecondsSinceEpoch(0),
        endedAt: parseDateTime(json['endedAt']),
        durationSec: json['durationSec'] as int?,
        status: callStatusFromString((json['status'] ?? 'failed') as String),
        recordingUrl: json['recordingUrl'] as String?,
        mentionedResidences: (json['mentionedResidences'] is List)
            ? (json['mentionedResidences'] as List)
                .map((e) => Residence.fromJson(Map<String, dynamic>.from(e)))
                .toList()
            : const [],
        humanKeywords: List<String>.from(json['humanKeywords'] ?? const []),
        humanSummary: (json['humanSummary'] ?? '') as String,
        humanNotes: (json['humanNotes'] ?? '') as String,
        aiSummary: (json['aiSummary'] ?? '') as String,
        reviewCount: (json['reviewCount'] ?? 0) as int,
        lastReviewAt: parseDateTime(json['lastReviewAt']),
        reviews: (json['reviews'] is List)
            ? (json['reviews'] as List)
                .map((e) => Review.fromJson(Map<String, dynamic>.from(e)))
                .toList()
            : null,
      );

  Map<String, dynamic> toJson() => {
        'callId': callId,
        'groupId': groupId,
        'receiverId': receiverId,
        'caregiverUserId': caregiverUserId,
        'groupNameSnapshot': groupNameSnapshot,
        'giverNameSnapshot': giverNameSnapshot,
        'receiverNameSnapshot': receiverNameSnapshot,
        'startedAt': startedAt.toIso8601String(),
        'endedAt': endedAt?.toIso8601String(),
        'durationSec': durationSec,
        'status': callStatusToString(status),
        'recordingUrl': recordingUrl,
        'mentionedResidences': mentionedResidences.map((e) => e.toJson()).toList(),
        'humanKeywords': humanKeywords,
        'humanSummary': humanSummary,
        'humanNotes': humanNotes,
        'aiSummary': aiSummary,
        'reviewCount': reviewCount,
        'lastReviewAt': lastReviewAt?.toIso8601String(),
      };

  Call copyWith({
    DateTime? endedAt,
    int? durationSec,
    CallStatus? status,
    String? recordingUrl,
    List<Residence>? mentionedResidences,
    List<String>? humanKeywords,
    String? humanSummary,
    String? humanNotes,
    String? aiSummary,
    int? reviewCount,
    DateTime? lastReviewAt,
    List<Review>? reviews,
  }) {
    return Call(
      callId: callId,
      groupId: groupId,
      receiverId: receiverId,
      caregiverUserId: caregiverUserId,
      groupNameSnapshot: groupNameSnapshot,
      giverNameSnapshot: giverNameSnapshot,
      receiverNameSnapshot: receiverNameSnapshot,
      startedAt: startedAt,
      endedAt: endedAt ?? this.endedAt,
      durationSec: durationSec ?? this.durationSec,
      status: status ?? this.status,
      recordingUrl: recordingUrl ?? this.recordingUrl,
      mentionedResidences: mentionedResidences ?? this.mentionedResidences,
      humanKeywords: humanKeywords ?? this.humanKeywords,
      humanSummary: humanSummary ?? this.humanSummary,
      humanNotes: humanNotes ?? this.humanNotes,
      aiSummary: aiSummary ?? this.aiSummary,
      reviewCount: reviewCount ?? this.reviewCount,
      lastReviewAt: lastReviewAt ?? this.lastReviewAt,
      reviews: reviews ?? this.reviews,
    );
  }
}

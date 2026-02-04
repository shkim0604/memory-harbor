import 'model_helpers.dart';

class Residence {
  final String residenceId;
  final String era;
  final String location;
  final String detail;

  const Residence({
    required this.residenceId,
    required this.era,
    required this.location,
    this.detail = '',
  });

  factory Residence.fromJson(Map<String, dynamic> json) => Residence(
        residenceId: (json['residenceId'] ?? json['rid'] ?? '') as String,
        era: (json['era'] ?? '') as String,
        location: (json['location'] ?? '') as String,
        detail: (json['detail'] ?? '') as String,
      );

  Map<String, dynamic> toJson() => {
        'residenceId': residenceId,
        'era': era,
        'location': location,
        'detail': detail,
      };
}

class ResidenceStats {
  final String groupId;
  final String receiverId;
  final String residenceId;
  final String era;
  final String location;
  final String detail;
  final List<String> keywords;
  final int totalCalls;
  final DateTime? lastCallAt;
  final String aiSummary;
  final List<String> humanComments;

  const ResidenceStats({
    required this.groupId,
    required this.receiverId,
    required this.residenceId,
    this.era = '',
    this.location = '',
    this.detail = '',
    this.keywords = const [],
    this.totalCalls = 0,
    this.lastCallAt,
    this.aiSummary = '',
    this.humanComments = const [],
  });

  factory ResidenceStats.fromJson(Map<String, dynamic> json) => ResidenceStats(
        groupId: (json['groupId'] ?? '') as String,
        receiverId: (json['receiverId'] ?? '') as String,
        residenceId: (json['residenceId'] ?? '') as String,
        era: (json['era'] ?? '') as String,
        location: (json['location'] ?? '') as String,
        detail: (json['detail'] ?? '') as String,
        keywords: List<String>.from(json['keywords'] ?? const []),
        totalCalls: (json['totalCalls'] ?? 0) as int,
        lastCallAt: parseDateTime(json['lastCallAt']),
        aiSummary: (json['aiSummary'] ?? '') as String,
        humanComments: List<String>.from(json['humanComments'] ?? const []),
      );

  Map<String, dynamic> toJson() => {
        'groupId': groupId,
        'receiverId': receiverId,
        'residenceId': residenceId,
        'era': era,
        'location': location,
        'detail': detail,
        'keywords': keywords,
        'totalCalls': totalCalls,
        'lastCallAt': lastCallAt?.toIso8601String(),
        'aiSummary': aiSummary,
        'humanComments': humanComments,
      };
}

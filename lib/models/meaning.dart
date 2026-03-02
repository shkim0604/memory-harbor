import 'model_helpers.dart';

class InterviewGuideStep {
  final int step;
  final String key;
  final String label;
  final List<String> prompts;

  const InterviewGuideStep({
    required this.step,
    required this.key,
    required this.label,
    this.prompts = const [],
  });

  factory InterviewGuideStep.fromJson(Map<String, dynamic> json) =>
      InterviewGuideStep(
        step: (json['step'] ?? 0) as int,
        key: (json['key'] ?? '') as String,
        label: (json['label'] ?? '') as String,
        prompts: List<String>.from(json['prompts'] ?? const []),
      );
}

class MeaningStats {
  final String groupId;
  final String receiverId;
  final String meaningId;
  final String topicType;
  final bool isFixedQuestion;
  final bool active;
  final int order;
  final String title;
  final String question;
  final List<String> keywords;
  final int totalCalls;
  final int totalReviews;
  final DateTime? lastCallAt;
  final DateTime? lastReviewAt;
  final String aiSummary;
  final List<String> humanComments;
  final int version;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final List<InterviewGuideStep> interviewGuide;
  final List<String> exampleQuestions;

  const MeaningStats({
    required this.groupId,
    required this.receiverId,
    required this.meaningId,
    this.topicType = 'meaning',
    this.isFixedQuestion = true,
    this.active = true,
    this.order = 0,
    this.title = '',
    this.question = '',
    this.keywords = const [],
    this.totalCalls = 0,
    this.totalReviews = 0,
    this.lastCallAt,
    this.lastReviewAt,
    this.aiSummary = '',
    this.humanComments = const [],
    this.version = 1,
    this.createdAt,
    this.updatedAt,
    this.interviewGuide = const [],
    this.exampleQuestions = const [],
  });

  factory MeaningStats.fromJson(Map<String, dynamic> json) => MeaningStats(
        groupId: (json['groupId'] ?? '') as String,
        receiverId: (json['receiverId'] ?? '') as String,
        meaningId: (json['meaningId'] ?? '') as String,
        topicType: (json['topicType'] ?? 'meaning') as String,
        isFixedQuestion: (json['isFixedQuestion'] ?? true) as bool,
        active: (json['active'] ?? true) as bool,
        order: (json['order'] ?? 0) as int,
        title: (json['title'] ?? '') as String,
        question: (json['question'] ?? '') as String,
        keywords: List<String>.from(json['keywords'] ?? const []),
        totalCalls: (json['totalCalls'] ?? 0) as int,
        totalReviews: (json['totalReviews'] ?? 0) as int,
        lastCallAt: parseDateTime(json['lastCallAt']),
        lastReviewAt: parseDateTime(json['lastReviewAt']),
        aiSummary: (json['aiSummary'] ?? '') as String,
        humanComments: List<String>.from(json['humanComments'] ?? const []),
        version: (json['version'] ?? 1) as int,
        createdAt: parseDateTime(json['createdAt']),
        updatedAt: parseDateTime(json['updatedAt']),
        interviewGuide: (json['interviewGuide'] is List)
            ? (json['interviewGuide'] as List)
                .map(
                  (e) =>
                      InterviewGuideStep.fromJson(Map<String, dynamic>.from(e)),
                )
                .toList()
            : const [],
        exampleQuestions: List<String>.from(json['exampleQuestions'] ?? const []),
      );
}

import 'model_helpers.dart';

class GroupStats {
  final int totalCalls;
  final DateTime? lastCallAt;
  final String? lastCallId;

  const GroupStats({
    this.totalCalls = 0,
    this.lastCallAt,
    this.lastCallId,
  });

  factory GroupStats.fromJson(Map<String, dynamic> json) => GroupStats(
        totalCalls: (json['totalCalls'] ?? 0) as int,
        lastCallAt: parseDateTime(json['lastCallAt']),
        lastCallId: json['lastCallId'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'totalCalls': totalCalls,
        'lastCallAt': lastCallAt?.toIso8601String(),
        'lastCallId': lastCallId,
      };
}

class Group {
  final String groupId;
  final String name;
  final List<String> careGiverUserIds;
  final String receiverId;
  final GroupStats stats;

  const Group({
    required this.groupId,
    required this.name,
    required this.careGiverUserIds,
    required this.receiverId,
    this.stats = const GroupStats(),
  });

  factory Group.fromJson(Map<String, dynamic> json) => Group(
        groupId: (json['groupId'] ?? '') as String,
        name: (json['name'] ?? '') as String,
        careGiverUserIds: List<String>.from(json['careGiverUserIds'] ?? const []),
        receiverId: (json['receiverId'] ?? '') as String,
        stats: GroupStats.fromJson(
          Map<String, dynamic>.from(json['stats'] ?? const {}),
        ),
      );

  Map<String, dynamic> toJson() => {
        'groupId': groupId,
        'name': name,
        'careGiverUserIds': careGiverUserIds,
        'receiverId': receiverId,
        'stats': stats.toJson(),
      };
}

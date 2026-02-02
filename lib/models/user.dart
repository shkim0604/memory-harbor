import 'model_helpers.dart';

class AppUser {
  final String uid;
  final String name;
  final String email;
  final String profileImage;
  final List<String> groupIds;
  final DateTime createdAt;
  final DateTime? lastActivityAt;

  const AppUser({
    required this.uid,
    required this.name,
    required this.email,
    required this.profileImage,
    required this.groupIds,
    required this.createdAt,
    this.lastActivityAt,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      uid: (json['uid'] ?? '') as String,
      name: (json['name'] ?? '') as String,
      email: (json['email'] ?? '') as String,
      profileImage: (json['profileImage'] ?? '') as String,
      groupIds: List<String>.from(json['groupIds'] ?? const []),
      createdAt: parseDateTime(json['createdAt']) ?? DateTime.fromMillisecondsSinceEpoch(0),
      lastActivityAt: parseDateTime(json['lastActivityAt']),
    );
  }

  Map<String, dynamic> toJson() => {
        'uid': uid,
        'name': name,
        'email': email,
        'profileImage': profileImage,
        'groupIds': groupIds,
        'createdAt': createdAt.toIso8601String(),
        'lastActivityAt': lastActivityAt?.toIso8601String(),
      };

  AppUser copyWith({
    String? uid,
    String? name,
    String? email,
    String? profileImage,
    List<String>? groupIds,
    DateTime? createdAt,
    DateTime? lastActivityAt,
  }) {
    return AppUser(
      uid: uid ?? this.uid,
      name: name ?? this.name,
      email: email ?? this.email,
      profileImage: profileImage ?? this.profileImage,
      groupIds: groupIds ?? this.groupIds,
      createdAt: createdAt ?? this.createdAt,
      lastActivityAt: lastActivityAt ?? this.lastActivityAt,
    );
  }
}

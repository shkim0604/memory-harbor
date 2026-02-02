import 'residence.dart';

class CareReceiver {
  final String receiverId;
  final String groupId;
  final String name;
  final String profileImage;
  final List<Residence> majorResidences;

  const CareReceiver({
    required this.receiverId,
    required this.groupId,
    required this.name,
    required this.profileImage,
    this.majorResidences = const [],
  });

  factory CareReceiver.fromJson(Map<String, dynamic> json) => CareReceiver(
        receiverId: (json['receiverId'] ?? '') as String,
        groupId: (json['groupId'] ?? '') as String,
        name: (json['name'] ?? '') as String,
        profileImage: (json['profileImage'] ?? '') as String,
        majorResidences: (json['majorResidences'] is List)
            ? (json['majorResidences'] as List)
                .map((e) => Residence.fromJson(Map<String, dynamic>.from(e)))
                .toList()
            : const [],
      );

  Map<String, dynamic> toJson() => {
        'receiverId': receiverId,
        'groupId': groupId,
        'name': name,
        'profileImage': profileImage,
        'majorResidences': majorResidences.map((e) => e.toJson()).toList(),
      };
}

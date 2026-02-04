import 'dart:convert';
import 'dart:io';

import '../config/agora_config.dart';

class CallInviteResult {
  final String callId;
  final String channelName;

  const CallInviteResult({
    required this.callId,
    required this.channelName,
  });
}

class CallInviteService {
  CallInviteService._();
  static final CallInviteService instance = CallInviteService._();

  Future<CallInviteResult?> inviteCall({
    required String groupId,
    required String callerId,
    required String receiverId,
    String? callerName,
    String? groupNameSnapshot,
    String? receiverNameSnapshot,
  }) async {
    if (AgoraConfig.apiBaseUrl.trim().isEmpty) return null;
    final uri = Uri.parse('${AgoraConfig.apiBaseUrl}/api/call/invite');

    try {
      final client = HttpClient();
      final request = await client.postUrl(uri);
      request.headers.contentType = ContentType.json;
      request.write(
        jsonEncode(<String, dynamic>{
          'group_id': groupId,
          'caller_id': callerId,
          'receiver_id': receiverId,
          if (callerName != null && callerName.trim().isNotEmpty)
            'caller_name': callerName.trim(),
          if (groupNameSnapshot != null && groupNameSnapshot.trim().isNotEmpty)
            'group_name_snapshot': groupNameSnapshot.trim(),
          if (receiverNameSnapshot != null &&
              receiverNameSnapshot.trim().isNotEmpty)
            'receiver_name_snapshot': receiverNameSnapshot.trim(),
        }),
      );
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      client.close();

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return null;
      }

      final json = jsonDecode(body);
      if (json is Map) {
        final callId = (json['callId'] ?? '') as String;
        final channelName = (json['channelName'] ?? '') as String;
        if (callId.isNotEmpty && channelName.isNotEmpty) {
          return CallInviteResult(callId: callId, channelName: channelName);
        }
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  Future<bool> answerCall({
    required String callId,
    required String action, // accept | decline
  }) async {
    return _postJson('/api/call/answer', {
      'call_id': callId,
      'action': action,
    });
  }

  Future<bool> cancelCall({required String callId}) async {
    return _postJson('/api/call/cancel', {'call_id': callId});
  }

  Future<bool> missedCall({required String callId}) async {
    return _postJson('/api/call/missed', {'call_id': callId});
  }

  Future<bool> _postJson(String path, Map<String, dynamic> body) async {
    if (AgoraConfig.apiBaseUrl.trim().isEmpty) return false;
    final uri = Uri.parse('${AgoraConfig.apiBaseUrl}$path');

    try {
      final client = HttpClient();
      final request = await client.postUrl(uri);
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode(body));
      final response = await request.close();
      await response.transform(utf8.decoder).join();
      client.close();
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (_) {
      return false;
    }
  }
}

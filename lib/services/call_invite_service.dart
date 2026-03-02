import '../config/agora_config.dart';
import 'package:flutter/foundation.dart';
import 'api_client.dart';

const String _tag = '[CIV]'; // CallInviteService log prefix

class CallInviteResult {
  final String callId;
  final String channelName;

  const CallInviteResult({required this.callId, required this.channelName});
}

class CallInviteService {
  CallInviteService._();
  static final CallInviteService instance = CallInviteService._();

  String get _baseUrl => AgoraConfig.apiBaseUrl.trim();

  Future<CallInviteResult?> inviteCall({
    required String groupId,
    required String callerId,
    required String receiverId,
    String? callerName,
    String? groupNameSnapshot,
    String? receiverNameSnapshot,
  }) async {
    debugPrint(
      '$_tag inviteCall request: caller=$callerId receiver=$receiverId group=$groupId',
    );
    if (_baseUrl.isEmpty) return null;
    final json = await ApiClient.instance
        .postJson('$_baseUrl/api/call/invite', <String, dynamic>{
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
        });
    if (json == null) return null;
    final callId = (json['callId'] ?? '') as String;
    final channelName = (json['channelName'] ?? '') as String;
    if (callId.isNotEmpty && channelName.isNotEmpty) {
      debugPrint('$_tag inviteCall success: callId=$callId channel=$channelName');
      return CallInviteResult(callId: callId, channelName: channelName);
    }
    debugPrint('$_tag inviteCall invalid response: $json');
    return null;
  }

  Future<bool> answerCall({
    required String callId,
    required String action, // accept | decline
  }) async {
    return _postOk('/api/call/answer', {'call_id': callId, 'action': action});
  }

  Future<bool> cancelCall({required String callId}) async {
    return _postOk('/api/call/cancel', {'call_id': callId});
  }

  Future<bool> missedCall({required String callId}) async {
    return _postOk('/api/call/missed', {'call_id': callId});
  }

  Future<bool> endCall({required String callId}) async {
    return _postOk('/api/call/end', {'call_id': callId});
  }

  Future<bool> _postOk(String path, Map<String, dynamic> body) async {
    if (_baseUrl.isEmpty) return false;
    final ok = await ApiClient.instance.postJsonOk('$_baseUrl$path', body);
    debugPrint('$_tag postOk path=$path ok=$ok body=$body');
    return ok;
  }
}

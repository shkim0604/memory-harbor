import 'dart:async';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'dart:io';
import '../config/agora_config.dart';
import '../services/agora_service.dart';
import '../services/call_service.dart';
import '../services/permission_service.dart';
import '../services/call_invite_service.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import '../services/call_notification_service.dart' show CallInvitePayload;
import '../widgets/call_status_indicator.dart';

class CallSessionViewModel {
  CallSessionViewModel._();
  static final CallSessionViewModel instance = CallSessionViewModel._();

  CallSessionState status = CallSessionState.ended;
  bool isMuted = false;
  bool isSpeaker = false;
  bool isRecording = false;
  int callDurationSeconds = 0;
  final Set<int> remoteUsers = {};

  final String _agoraAppId = AgoraConfig.appId;
  String? currentChannelName;
  String? currentGroupId;
  String? currentCallId;
  int? currentUid;
  String? currentCallerId;
  String? currentReceiverId;
  String? currentToken;

  Timer? _callTimer;
  bool _isEnding = false;
  final AudioPlayer _connectingPlayer = AudioPlayer();
  bool _connectingToneActive = false;
  final Set<VoidCallback> _listeners = {};
  final Set<void Function(String message)> _errorListeners = {};
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _callStatusSub;

  /// Fires when the server marks the call as cancelled/missed/declined
  /// while the client is still in connecting or ringing state.
  bool _remotelyCancelled = false;
  bool get remotelyCancelled => _remotelyCancelled;

  void addListener(VoidCallback listener) {
    _listeners.add(listener);
  }

  void removeListener(VoidCallback listener) {
    _listeners.remove(listener);
  }

  void addErrorListener(void Function(String message) listener) {
    _errorListeners.add(listener);
  }

  void removeErrorListener(void Function(String message) listener) {
    _errorListeners.remove(listener);
  }

  void init() {
    _setupAgoraCallbacks();
  }

  void dispose() {
    _callTimer?.cancel();
    _stopWatchingCallStatus();
    AgoraService.instance.dispose();
    _connectingPlayer.dispose();
    _listeners.clear();
    _errorListeners.clear();
  }

  String get formattedDuration {
    final minutes = (callDurationSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (callDurationSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  Future<bool> startCall(
    BuildContext context, {
    String? groupId,
    String? channelName,
    String? callerUserId,
    String? peerUserId,
    String? callId,
    String? token,
    int? uid,
  }) async {
    final hasPermission = await PermissionService.instance
        .requestMicrophoneWithUI(context);
    return _startCallInternal(
      hasPermission: hasPermission,
      groupId: groupId,
      channelName: channelName,
      callerUserId: callerUserId,
      peerUserId: peerUserId,
      callId: callId,
      token: token,
      uid: uid,
    );
  }

  /// Start call without showing permission UI. Returns false if mic permission
  /// isn't already granted (e.g. when accepting from lock screen).
  Future<bool> startCallSilent({
    String? groupId,
    String? channelName,
    String? callerUserId,
    String? peerUserId,
    String? callId,
    String? token,
    int? uid,
  }) async {
    final hasPermission =
        await PermissionService.instance.hasMicrophonePermission();
    return _startCallInternal(
      hasPermission: hasPermission,
      groupId: groupId,
      channelName: channelName,
      callerUserId: callerUserId,
      peerUserId: peerUserId,
      callId: callId,
      token: token,
      uid: uid,
    );
  }

  Future<bool> _startCallInternal({
    required bool hasPermission,
    String? groupId,
    String? channelName,
    String? callerUserId,
    String? peerUserId,
    String? callId,
    String? token,
    int? uid,
  }) async {
    _isEnding = false;
    isRecording = false;
    _remotelyCancelled = false;
    remoteUsers.clear();
    if (!hasPermission) {
      _notifyError('마이크 권한이 필요합니다');
      return false;
    }

    status = CallSessionState.connecting;
    _syncConnectingTone();
    _notifyChanged();

    if (_agoraAppId.isEmpty) {
      _notifyError('Agora App ID가 비어있습니다. 설정을 확인하세요.');
      status = CallSessionState.ended;
      _syncConnectingTone();
      _notifyChanged();
      return false;
    }

    final agora = AgoraService.instance;
    if (!agora.isInitialized) {
      final initialized = await agora.initialize(_agoraAppId);
      if (!initialized) {
        status = CallSessionState.ended;
        _syncConnectingTone();
        _notifyChanged();
        return false;
      }
    }
    // Default to earpiece (not speaker) at call start.
    isSpeaker = false;
    await agora.setSpeakerOn(false);

    // Generate channel name: {groupId}_{user1}_{user2} or use provided channelName
    final String nextChannelName;
    if (channelName != null && channelName.isNotEmpty) {
      nextChannelName = channelName;
    } else if (groupId != null && groupId.isNotEmpty) {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      nextChannelName = '${groupId}_$timestamp';
    } else {
      nextChannelName = 'test_channel';
    }

    final nextUid = uid ?? AgoraConfig.defaultUid;
    currentChannelName = nextChannelName;
    currentGroupId = groupId;
    currentCallId = callId;
    currentUid = nextUid;
    currentCallerId = callerUserId;
    currentReceiverId = peerUserId;
    String nextToken = token ?? '';

    if (nextToken.isEmpty && AgoraConfig.apiBaseUrl.isNotEmpty) {
      final fetchedToken = await agora.fetchToken(
        apiBaseUrl: AgoraConfig.apiBaseUrl,
        channelName: nextChannelName,
        uid: nextUid,
      );
      nextToken = fetchedToken ?? '';
    }
    currentToken = nextToken;

    final joined = await agora.joinChannel(
      channelName: nextChannelName,
      token: nextToken,
      uid: nextUid,
    );

    if (!joined) {
      status = CallSessionState.ended;
      isRecording = false;
      _syncConnectingTone();
      _notifyChanged();
      return false;
    }
    // Update iOS CallKit UI to "in-call" once we've joined the channel.
    if (Platform.isIOS && callId != null && callId.isNotEmpty) {
      try {
        await FlutterCallkitIncoming.setCallConnected(callId);
      } catch (_) {
        // Ignore CallKit update failures.
      }
    }
    return true;
  }

  /// Invite a peer and start the outgoing call in one step.
  /// Returns `true` if the invite succeeded and the Agora channel was joined.
  Future<bool> startCallWithInvite(
    BuildContext context, {
    required String groupId,
    required String callerId,
    required String receiverId,
    String? callerName,
    String? groupNameSnapshot,
    String? receiverNameSnapshot,
  }) async {
    final invite = await CallInviteService.instance.inviteCall(
      groupId: groupId,
      callerId: callerId,
      receiverId: receiverId,
      callerName: callerName,
      groupNameSnapshot: groupNameSnapshot,
      receiverNameSnapshot: receiverNameSnapshot,
    );
    if (invite == null) {
      _notifyError('통화 요청 실패: 서버에 연결할 수 없습니다');
      return false;
    }
    final channelName = invite.channelName.isNotEmpty
        ? invite.channelName
        : invite.callId;
    watchCallStatus(invite.callId);
    final started = await startCall(
      context,
      groupId: groupId,
      channelName: channelName,
      callerUserId: callerId,
      peerUserId: receiverId,
      callId: invite.callId,
    );
    return started;
  }

  /// Accept an incoming call (receiver side).
  /// Calls the server API, then joins the Agora channel.
  Future<bool> acceptIncoming(
    BuildContext context, {
    required CallInvitePayload payload,
  }) async {
    if (payload.callId.isEmpty) return false;
    final success = await CallInviteService.instance.answerCall(
      callId: payload.callId,
      action: 'accept',
    );
    if (!success) {
      _notifyError('수락 실패: 서버에 연결할 수 없습니다');
      return false;
    }
    final channelName = payload.channelName.isNotEmpty
        ? payload.channelName
        : payload.callId;
    final started = await startCall(
      context,
      groupId: payload.groupId,
      channelName: channelName,
      callerUserId: payload.callerId,
      peerUserId: payload.receiverId,
      callId: payload.callId,
    );
    return started;
  }

  /// Accept an incoming call without showing permission UI (lock screen).
  Future<bool> acceptIncomingSilent({
    required CallInvitePayload payload,
  }) async {
    if (payload.callId.isEmpty) return false;
    final success = await CallInviteService.instance.answerCall(
      callId: payload.callId,
      action: 'accept',
    );
    if (!success) {
      _notifyError('수락 실패: 서버에 연결할 수 없습니다');
      return false;
    }
    final channelName = payload.channelName.isNotEmpty
        ? payload.channelName
        : payload.callId;
    final started = await startCallSilent(
      groupId: payload.groupId,
      channelName: channelName,
      callerUserId: payload.callerId,
      peerUserId: payload.receiverId,
      callId: payload.callId,
    );
    return started;
  }

  /// Decline an incoming call (receiver side).
  Future<bool> declineIncoming({required String callId}) async {
    if (callId.isEmpty) return false;
    return await CallInviteService.instance.answerCall(
      callId: callId,
      action: 'decline',
    );
  }

  /// User-initiated hang-up. Notifies the server so the remote side's
  /// Firestore watcher picks up the status change immediately.
  Future<void> endCall() => _doEndCall(notifyServer: true);

  Future<void> toggleMute() async {
    isMuted = !isMuted;
    await AgoraService.instance.setMuted(isMuted);
    _notifyChanged();
  }

  Future<void> toggleSpeaker() async {
    isSpeaker = !isSpeaker;
    await AgoraService.instance.setSpeakerOn(isSpeaker);
    _notifyChanged();
  }

  Future<void> toggleRecording() async {
    if (status != CallSessionState.onCall) {
      _notifyError('통화 연결 후에 녹음을 사용할 수 있습니다');
      return;
    }
    if (isRecording) {
      await _stopServerRecording();
      isRecording = false;
    } else {
      final started = await _startServerRecording();
      isRecording = started;
    }
    _notifyChanged();
  }

  /// Watch Firestore `calls/{callId}` for server-side status changes.
  /// If the call is marked missed/declined/cancelled while we're still
  /// connecting, automatically end the call and set [remotelyCancelled].
  void watchCallStatus(String callId) {
    if (callId.isEmpty) return;
    _stopWatchingCallStatus();
    _remotelyCancelled = false;

    const cancelStatuses = {'missed', 'declined', 'cancelled'};
    const endStatuses = {'completed', 'ended'};

    _callStatusSub = CallService.instance.streamCallDoc(callId).listen((
      snapshot,
    ) async {
      final data = snapshot.data();
      if (data == null) return;
      if (_isEnding || status == CallSessionState.ended) return;
      final serverStatus = (data['status'] ?? '') as String;

      if (cancelStatuses.contains(serverStatus)) {
        // Remote cancellation before call connected.
        if (status == CallSessionState.onCall) return;
        _remotelyCancelled = true;
        _notifyChanged();
        await endCall();
      } else if (endStatuses.contains(serverStatus)) {
        // Remote end during active call – fallback when Agora
        // onUserOffline doesn't fire (e.g. iOS CallKit audio session).
        await _endCallFromRemote();
      }
    });
  }

  void _stopWatchingCallStatus() {
    _callStatusSub?.cancel();
    _callStatusSub = null;
  }

  void _setupAgoraCallbacks() {
    final agora = AgoraService.instance;

    agora.onJoinChannelSuccess = () {
      status = CallSessionState.connecting;
      _syncConnectingTone();
      _notifyChanged();
    };

    agora.onLeaveChannel = () {
      // When _isEnding is true, cleanup is handled by _doEndCall.
      // This callback only handles unexpected disconnects by the SDK.
      if (_isEnding || status == CallSessionState.ended) return;
      _resetCallState();
    };

    agora.onUserJoined = (int uid) {
      if (_isEnding || status == CallSessionState.ended) {
        return;
      }
      if (_isRecordingBot(uid)) {
        return;
      }
      remoteUsers.add(uid);
      if (status != CallSessionState.onCall) {
        status = CallSessionState.onCall;
        _startCallTimer();
        _syncConnectingTone();
      }
      _maybeStartRecording();
      _notifyChanged();
    };

    agora.onUserOffline = (int uid, UserOfflineReasonType reason) {
      if (_isEnding || status == CallSessionState.ended) {
        return;
      }
      if (_isRecordingBot(uid)) {
        return;
      }
      remoteUsers.remove(uid);
      if (remoteUsers.isEmpty) {
        unawaited(_endCallFromRemote());
      } else {
        _notifyChanged();
      }
    };

    agora.onError = (String message) {
      _notifyError(message);
    };
  }

  bool _isRecordingBot(int uid) => uid == AgoraConfig.recordingBotUid;

  void _startCallTimer() {
    callDurationSeconds = 0;
    _callTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      callDurationSeconds++;
      _notifyChanged();
    });
  }

  void _stopCallTimer() {
    _callTimer?.cancel();
    _callTimer = null;
  }

  void _maybeStartRecording() {
    if (isRecording) return;
    if (status != CallSessionState.onCall) return;
    if (remoteUsers.isEmpty) return;
    // Start server recording only when both sides are in the channel.
    unawaited(
      _startServerRecording().then((started) {
        if (started) {
          isRecording = true;
          _notifyChanged();
        }
      }),
    );
  }

  Future<bool> _startServerRecording() async {
    final channelName = currentChannelName;
    if (channelName == null || channelName.isEmpty) {
      _notifyError('녹음 시작 실패: 채널 정보가 없습니다');
      return false;
    }
    if (AgoraConfig.apiBaseUrl.isEmpty) {
      _notifyError('녹음 시작 실패: 서버 주소가 없습니다');
      return false;
    }
    return await AgoraService.instance.startServerRecording(
      apiBaseUrl: AgoraConfig.apiBaseUrl,
      channelName: channelName,
      token: currentToken,
      uid: AgoraConfig.recordingBotUid,
      groupId: currentGroupId,
      callerId: currentCallerId,
      receiverId: currentReceiverId,
    );
  }

  Future<void> _stopServerRecording() async {
    final channelName = currentChannelName;
    if (channelName == null || channelName.isEmpty) {
      _notifyError('녹음 중지 실패: 채널 정보가 없습니다');
      return;
    }
    if (AgoraConfig.apiBaseUrl.isEmpty) {
      _notifyError('녹음 중지 실패: 서버 주소가 없습니다');
      return;
    }
    await AgoraService.instance.stopServerRecording(
      apiBaseUrl: AgoraConfig.apiBaseUrl,
      channelName: channelName,
      uid: AgoraConfig.recordingBotUid,
    );
  }

  /// Remote-initiated end (Agora callback or Firestore fallback).
  Future<void> _endCallFromRemote() => _doEndCall(notifyServer: false);

  /// Shared implementation for both user-initiated and remote-initiated end.
  Future<void> _doEndCall({required bool notifyServer}) async {
    if (_isEnding) return;
    _isEnding = true;
    _stopWatchingCallStatus();
    final previousStatus = status;
    final callIdToEnd = currentCallId;

    // 1. Notify server FIRST (fire-and-forget) so Firestore is updated ASAP.
    Future<void>? serverNotify;
    if (notifyServer && callIdToEnd != null && callIdToEnd.isNotEmpty) {
      if (previousStatus == CallSessionState.onCall) {
        serverNotify =
            CallInviteService.instance.endCall(callId: callIdToEnd);
      } else if (previousStatus == CallSessionState.connecting) {
        serverNotify =
            CallInviteService.instance.cancelCall(callId: callIdToEnd);
      }
    }

    // 2. Stop recording & leave Agora channel.
    if (isRecording) {
      if (notifyServer) {
        unawaited(_stopServerRecording());
      } else {
        await _stopServerRecording();
      }
    }
    await AgoraService.instance.leaveChannel();

    // 3. Update local state & notify UI.
    _resetCallState();

    // 4. Dismiss iOS CallKit / Android notification UI.
    try {
      if (callIdToEnd != null && callIdToEnd.isNotEmpty) {
        await FlutterCallkitIncoming.endCall(callIdToEnd);
      } else {
        await FlutterCallkitIncoming.endAllCalls();
      }
    } catch (_) {
      // Ignore if CallKit is not active or unavailable.
    }

    // 5. Ensure server notification completes.
    if (serverNotify != null) {
      try {
        await serverNotify;
      } catch (_) {}
    }
    _isEnding = false;
  }

  /// Reset local call state. Called from [_doEndCall] and from the
  /// [onLeaveChannel] callback when an unexpected disconnect occurs.
  void _resetCallState() {
    status = CallSessionState.ended;
    isRecording = false;
    remoteUsers.clear();
    _stopCallTimer();
    _syncConnectingTone();
    _notifyChanged();
  }

  void _notifyChanged() {
    for (final listener in _listeners) {
      listener();
    }
  }

  void _notifyError(String message) {
    for (final listener in _errorListeners) {
      listener(message);
    }
  }

  Future<void> _syncConnectingTone() async {
    final shouldPlay = status == CallSessionState.connecting;
    if (shouldPlay && !_connectingToneActive) {
      _connectingToneActive = true;
      await _connectingPlayer.setReleaseMode(ReleaseMode.loop);
      await _connectingPlayer.play(
        AssetSource('sounds/connecting.wav'),
        volume: 0.6,
      );
      return;
    }
    if (!shouldPlay && _connectingToneActive) {
      _connectingToneActive = false;
      await _connectingPlayer.stop();
    }
  }
}

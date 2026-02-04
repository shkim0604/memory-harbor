import 'dart:async';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import '../config/agora_config.dart';
import '../services/agora_service.dart';
import '../services/permission_service.dart';
import '../services/call_invite_service.dart';
import '../widgets/call_status_indicator.dart';

class CallSessionViewModel {
  CallSessionViewModel._();
  static final CallSessionViewModel instance = CallSessionViewModel._();

  CallStatus status = CallStatus.ended;
  bool isMuted = false;
  bool isSpeaker = true;
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

  Future<void> startCall(
    BuildContext context, {
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
    remoteUsers.clear();
    final hasPermission = await PermissionService.instance
        .requestMicrophoneWithUI(context);
    if (!hasPermission) {
      _notifyError('마이크 권한이 필요합니다');
      return;
    }

    status = CallStatus.connecting;
    _syncConnectingTone();
    _notifyChanged();

    if (_agoraAppId.isEmpty) {
      _notifyError('Agora App ID가 비어있습니다. 설정을 확인하세요.');
      status = CallStatus.ended;
      _syncConnectingTone();
      _notifyChanged();
      return;
    }

    final agora = AgoraService.instance;
    if (!agora.isInitialized) {
      final initialized = await agora.initialize(_agoraAppId);
      if (!initialized) {
        status = CallStatus.ended;
        _syncConnectingTone();
        _notifyChanged();
        return;
      }
    }

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
      status = CallStatus.ended;
      isRecording = false;
      _syncConnectingTone();
      _notifyChanged();
      return;
    }
  }

  Future<void> endCall() async {
    if (_isEnding) return;
    _isEnding = true;
    final shouldNotifyEnd = status == CallStatus.onCall;
    final callIdToEnd = currentCallId;
    // User-initiated hangup -> stop recording immediately.
    if (isRecording) {
      await _stopServerRecording();
    }
    await AgoraService.instance.leaveChannel();
    status = CallStatus.ended;
    isRecording = false;
    remoteUsers.clear();
    _stopCallTimer();
    _syncConnectingTone();
    _notifyChanged();
    if (shouldNotifyEnd && callIdToEnd != null && callIdToEnd.isNotEmpty) {
      await CallInviteService.instance.endCall(callId: callIdToEnd);
    }
    _isEnding = false;
  }

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
    if (status != CallStatus.onCall) {
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

  void _setupAgoraCallbacks() {
    final agora = AgoraService.instance;

    agora.onJoinChannelSuccess = () {
      status = CallStatus.connecting;
      _syncConnectingTone();
      _notifyChanged();
    };

    agora.onLeaveChannel = () {
      status = CallStatus.ended;
      remoteUsers.clear();
      isRecording = false;
      _stopCallTimer();
      _syncConnectingTone();
      _notifyChanged();
    };

    agora.onUserJoined = (int uid) {
      if (_isEnding || status == CallStatus.ended) {
        return;
      }
      if (_isRecordingBot(uid)) {
        return;
      }
      remoteUsers.add(uid);
      if (status != CallStatus.onCall) {
        status = CallStatus.onCall;
        _startCallTimer();
        _syncConnectingTone();
      }
      _maybeStartRecording();
      _notifyChanged();
    };

    agora.onUserOffline = (int uid, UserOfflineReasonType reason) {
      if (_isEnding || status == CallStatus.ended) {
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
    if (status != CallStatus.onCall) return;
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
    final stopped = await AgoraService.instance.stopServerRecording(
      apiBaseUrl: AgoraConfig.apiBaseUrl,
      channelName: channelName,
      uid: AgoraConfig.recordingBotUid,
    );
    if (stopped) {
      _notifyError('녹음이 중지되었습니다');
    }
  }

  Future<void> _endCallFromRemote() async {
    if (_isEnding) return;
    _isEnding = true;
    if (isRecording) {
      await _stopServerRecording();
    }
    await AgoraService.instance.leaveChannel();
    status = CallStatus.ended;
    isRecording = false;
    remoteUsers.clear();
    _stopCallTimer();
    _syncConnectingTone();
    _notifyChanged();
    _isEnding = false;
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
    final shouldPlay = status == CallStatus.connecting;
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

import 'dart:async';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_callkit_incoming/entities/entities.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'call_invite_service.dart';
import 'user_service.dart';
import 'call_service.dart';

const String _tag = '[CNS]'; // CallNotificationService log prefix

/// Emitted when the user should be navigated to a call screen.
class IncomingCallEvent {
  final CallInvitePayload payload;
  final bool autoStart;
  const IncomingCallEvent({required this.payload, this.autoStart = false});
}

class CallNotificationService {
  CallNotificationService._();
  static final CallNotificationService instance = CallNotificationService._();

  bool _initialized = false;
  StreamSubscription? _callkitSub;
  StreamSubscription<User?>? _authSub;
  final Map<String, Timer> _missedTimers = {};
  final Map<String, StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>>
  _incomingCallSubs = {};
  final Map<String, DateTime> _callkitShownAt = {};
  final Map<String, DateTime> _incomingEmittedAt = {};
  final Set<String> _acceptHandled = {};
  final Set<String> _endHandled = {};

  final StreamController<IncomingCallEvent> _incomingCallController =
      StreamController<IncomingCallEvent>.broadcast();

  /// Stream that fires when the app should show a call screen.
  /// Subscribe in main.dart to handle navigation.
  Stream<IncomingCallEvent> get incomingCallStream =>
      _incomingCallController.stream;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    debugPrint('$_tag init() start');

    // Permissions and token registration must run once on app start.
    await _requestPermission();
    await _registerTokens();
    _listenAuthChanges();

    FirebaseMessaging.onMessage.listen(handleIncomingMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);

    final initial = await FirebaseMessaging.instance.getInitialMessage();
    if (initial != null) {
      debugPrint('$_tag init: initial message found — type=${initial.data['type']}');
      _handleMessageOpenedApp(initial);
    }

    _listenCallkitEvents();
    debugPrint('$_tag init() done');
  }

  Future<void> _requestPermission() async {
    // Android 13+ requires runtime notification permission.
    if (Platform.isAndroid) {
      final status = await Permission.notification.status;
      if (!status.isGranted) {
        await Permission.notification.request();
      }
    }
    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );
  }

  Future<void> registerTokens() => _registerTokens();

  Future<void> _registerTokens() async {
    final uid = UserService.instance.currentUid();
    if (uid == null) {
      debugPrint('$_tag _registerTokens: uid is null — skipping');
      return;
    }
    try {
      final onboarded = await UserService.instance.isUserOnboarded(uid);
      if (!onboarded) {
        debugPrint('$_tag _registerTokens: user not onboarded yet — skipping');
        return;
      }
    } catch (e) {
      debugPrint('$_tag _registerTokens: onboarding check failed — $e');
      return;
    }
    final platform = Platform.isIOS
        ? 'ios'
        : (Platform.isAndroid ? 'android' : '');
    debugPrint('$_tag _registerTokens: uid=$uid, platform=$platform');

    // iOS APNs token (for debugging/verification).
    if (Platform.isIOS) {
      try {
        final apnsToken = await FirebaseMessaging.instance.getAPNSToken();
        debugPrint('$_tag APNs token: ${apnsToken != null ? '${apnsToken.substring(0, 8)}...' : 'null'}');
        if (apnsToken != null && apnsToken.isNotEmpty) {
          await UserService.instance.updatePushTokens(
            apnsToken: apnsToken,
            platform: platform,
          );
        }
      } catch (e) {
        debugPrint('$_tag APNs token lookup failed: $e');
      }
    }

    // FCM token -> store under users/{uid}
    try {
      final token = await FirebaseMessaging.instance.getToken();
      debugPrint('$_tag FCM token: ${token != null ? '${token.substring(0, 12)}...' : 'null'}');
      if (token != null && token.isNotEmpty) {
        await UserService.instance.updatePushTokens(
          fcmToken: token,
          platform: platform,
        );
      }
    } catch (e) {
      debugPrint('$_tag FCM token lookup failed: $e');
    }

    // Token rotation -> keep server up-to-date.
    FirebaseMessaging.instance.onTokenRefresh.listen((nextToken) async {
      debugPrint('$_tag FCM token refreshed: ${nextToken.substring(0, 12)}...');
      final currentUid = UserService.instance.currentUid();
      if (currentUid == null || nextToken.isEmpty) return;
      try {
        await UserService.instance.updatePushTokens(
          fcmToken: nextToken,
          platform: platform,
        );
      } catch (e) {
        debugPrint('$_tag FCM token refresh save failed: $e');
      }
    });

    // iOS VoIP token (CallKit).
    // PKPushRegistry may not have delivered the token yet at app start,
    // so retry a few times with delay. Once registered, the callkit event
    // listener (_handleVoipTokenUpdate) handles subsequent rotations.
    if (Platform.isIOS) {
      await _registerVoipTokenWithRetry(uid, platform);
    }
  }

  // Re-register tokens after login (auth state becomes available).
  void _listenAuthChanges() {
    _authSub?.cancel();
    _authSub = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user == null) return;
      _registerTokens();
    });
  }

  Future<void> handleIncomingMessage(RemoteMessage message) async {
    final type = (message.data['type'] ?? '') as String;
    debugPrint('$_tag handleIncomingMessage: type=$type, data=${message.data}');
    if (type == 'call_cancelled') {
      final callId =
          (message.data['callId'] ??
                  message.data['call_id'] ??
                  message.data['id'] ??
                  '')
              as String;
      debugPrint('$_tag call_cancelled received — callId=$callId');
      if (callId.isNotEmpty) {
        _cancelMissedTimeout(callId);
        _stopWatchingIncoming(callId);
        _markCallkitHandled(callId);
        try {
          await FlutterCallkitIncoming.endCall(callId);
          debugPrint('$_tag CallKit dismissed for cancelled callId=$callId');
        } catch (e) {
          debugPrint('$_tag endCall failed for cancelled: $e');
        }
      }
      return;
    }
    final payload = CallInvitePayload.fromMessage(message);
    if (payload == null) {
      debugPrint('$_tag handleIncomingMessage: payload is null — ignoring');
      return;
    }
    debugPrint('$_tag incoming_call — callId=${payload.callId}, caller=${payload.callerName}');

    // Always ensure watcher & timer are active for this call, even if
    // CallKit was already shown by a VoIP push (iOS). Without this the
    // Firestore listener never starts and cancellations go undetected.
    _scheduleMissedTimeout(payload.callId);
    _watchIncomingCallStatus(payload.callId);

    final shouldShow = _shouldShowCallkit(payload.callId);
    if (!shouldShow) {
      debugPrint('$_tag shouldShowCallkit=false — CallKit already shown, skipping');
      return;
    }
    debugPrint('$_tag showing CallKit UI for callId=${payload.callId}');
    await _showIncomingCall(payload);
  }

  void _handleMessageOpenedApp(RemoteMessage message) {
    debugPrint('$_tag _handleMessageOpenedApp: data=${message.data}');
    final payload = CallInvitePayload.fromMessage(message);
    if (payload == null) return;
    debugPrint('$_tag user tapped notification — callId=${payload.callId}');
    _emitIncomingCall(payload, autoStart: false);
  }

  /// Build a unified [CallKitParams] from a [CallInvitePayload].
  static CallKitParams _buildCallKitParams(CallInvitePayload payload) {
    return CallKitParams(
      id: payload.callId,
      nameCaller: payload.callerName.isNotEmpty
          ? payload.callerName
          : 'Incoming call',
      appName: 'MemHarbor',
      handle: payload.callerName.isNotEmpty ? payload.callerName : 'Caller',
      type: 0,
      duration: 60000,
      textAccept: '수락',
      textDecline: '거절',
      extra: payload.extra,
      android: const AndroidParams(
        isCustomNotification: false,
        isShowFullLockedScreen: true,
        ringtonePath: 'system_ringtone_default',
      ),
      ios: const IOSParams(
        supportsVideo: false,
        supportsDTMF: false,
        supportsHolding: false,
        supportsGrouping: false,
        supportsUngrouping: false,
      ),
    );
  }

  Future<void> _showIncomingCall(CallInvitePayload payload) async {
    if (await _isCallActive(payload.callId)) {
      debugPrint('$_tag _showIncomingCall: callId=${payload.callId} already active — skip');
      return;
    }
    final params = _buildCallKitParams(payload);
    try {
      await FlutterCallkitIncoming.endAllCalls();
      await FlutterCallkitIncoming.showCallkitIncoming(params);
      debugPrint('$_tag _showIncomingCall: CallKit shown for callId=${payload.callId}');
    } catch (e) {
      debugPrint('$_tag _showIncomingCall: failed — $e');
    }
  }

  static Future<void> handleBackgroundMessage(RemoteMessage message) async {
    final type = (message.data['type'] ?? '') as String;
    debugPrint('$_tag [BG] handleBackgroundMessage: type=$type, data=${message.data}');

    // Handle call cancellation in background — dismiss CallKit / notification.
    if (type == 'call_cancelled') {
      final callId =
          (message.data['callId'] ??
                  message.data['call_id'] ??
                  message.data['id'] ??
                  '')
              as String;
      debugPrint('$_tag [BG] call_cancelled — callId=$callId');
      if (callId.isNotEmpty) {
        try {
          await FlutterCallkitIncoming.endCall(callId);
          debugPrint('$_tag [BG] CallKit dismissed for callId=$callId');
        } catch (e) {
          debugPrint('$_tag [BG] endCall failed: $e');
        }
      }
      return;
    }

    final payload = CallInvitePayload.fromMessage(message);
    if (payload == null) {
      debugPrint('$_tag [BG] payload is null — ignoring');
      return;
    }
    if (await _isCallActive(payload.callId)) {
      debugPrint('$_tag [BG] callId=${payload.callId} already active — skip');
      return;
    }

    debugPrint('$_tag [BG] showing CallKit for callId=${payload.callId}');
    final params = _buildCallKitParams(payload);
    try {
      await FlutterCallkitIncoming.endAllCalls();
      await FlutterCallkitIncoming.showCallkitIncoming(params);
      debugPrint('$_tag [BG] CallKit shown');
    } catch (e) {
      debugPrint('$_tag [BG] showCallkitIncoming failed: $e');
    }
  }

  void _listenCallkitEvents() {
    if (_callkitSub != null) {
      debugPrint('$_tag _listenCallkitEvents: already subscribed');
      return;
    }
    debugPrint('$_tag _listenCallkitEvents: subscribing');
    _callkitSub = FlutterCallkitIncoming.onEvent.listen((event) async {
      final name = (event?.event ?? '').toString();
      final body = event?.body ?? const <String, dynamic>{};
      final callId = (body['id'] ?? body['callId'] ?? '') as String;
      final payload = CallInvitePayload.fromEventBody(body);

      debugPrint('$_tag CallKit event: $name, callId=$callId');

      final isAccept =
          name == 'ACTION_CALL_ACCEPT' ||
          name == 'CALL_ACCEPT' ||
          name.contains('actionCallAccept');
      final isDecline =
          name == 'ACTION_CALL_DECLINE' ||
          name == 'CALL_DECLINE' ||
          name.contains('actionCallDecline');
      final isTimeout =
          name == 'ACTION_CALL_TIMEOUT' ||
          name == 'CALL_TIMEOUT' ||
          name.contains('actionCallTimeout');
      final isEnd =
          name == 'ACTION_CALL_ENDED' ||
          name == 'CALL_ENDED' ||
          name.contains('actionCallEnded') ||
          name.contains('actionCallEnd');
      final isIncoming =
          name == 'ACTION_CALL_INCOMING' ||
          name.contains('actionCallIncoming');
      final isVoipTokenUpdate =
          name.contains('DID_UPDATE_DEVICE_PUSH_TOKEN_VOIP') ||
          name.contains('actionDidUpdateDevicePushTokenVoip');

      // When CallKit / notification displays an incoming call (any trigger
      // path, including iOS VoIP push from AppDelegate), ensure the
      // Firestore watcher and missed timer are running so we can detect
      // caller cancellation immediately.
      if (isIncoming && callId.isNotEmpty) {
        debugPrint('$_tag ACTION_CALL_INCOMING — starting watcher & timer for callId=$callId');
        _scheduleMissedTimeout(callId);
        _watchIncomingCallStatus(callId);
      }

      // Accept -> open CallScreen (API accept is handled by
      // CallSessionViewModel.acceptIncoming to avoid double-call).
      if (isAccept) {
        debugPrint('$_tag ACCEPT — callId=$callId, payload=${payload != null}');
        if (callId.isNotEmpty && _acceptHandled.contains(callId)) {
          debugPrint('$_tag ACCEPT ignored (duplicate) — callId=$callId');
          return;
        }
        if (callId.isNotEmpty) {
          _acceptHandled.add(callId);
          _cancelMissedTimeout(callId);
          _stopWatchingIncoming(callId);
          _markCallkitHandled(callId);
        }
        _emitIncomingCallWithFallback(payload, callId);
      }

      if (isDecline) {
        debugPrint('$_tag DECLINE — callId=$callId');
        if (callId.isNotEmpty) {
          _cancelMissedTimeout(callId);
          _stopWatchingIncoming(callId);
          _markCallkitHandled(callId);
          CallInviteService.instance.answerCall(
            callId: callId,
            action: 'decline',
          );
        }
      }

      if (isTimeout) {
        debugPrint('$_tag TIMEOUT — callId=$callId');
        if (callId.isNotEmpty) {
          _cancelMissedTimeout(callId);
          _stopWatchingIncoming(callId);
          _markCallkitHandled(callId);
          CallInviteService.instance.missedCall(callId: callId);
        }
      }

      // End from native CallKit (e.g. iOS lock screen hang-up) may bypass
      // in-app CallSessionViewModel.endCall(). Reflect it to server so the
      // caller side watcher can terminate immediately.
      if (isEnd) {
        debugPrint('$_tag END — callId=$callId');
        if (callId.isNotEmpty) {
          if (_endHandled.contains(callId)) {
            debugPrint('$_tag END ignored (duplicate) — callId=$callId');
            return;
          }
          _endHandled.add(callId);
          _cancelMissedTimeout(callId);
          _stopWatchingIncoming(callId);
          _markCallkitHandled(callId);
          final accepted = _acceptHandled.contains(callId);
          if (accepted) {
            await CallInviteService.instance.endCall(callId: callId);
          } else {
            await CallInviteService.instance.answerCall(
              callId: callId,
              action: 'decline',
            );
          }
        }
      }

      // VoIP token delivered or rotated by PKPushRegistry.
      if (isVoipTokenUpdate) {
        debugPrint('$_tag VoIP token update event received');
        _handleVoipTokenUpdate(body);
      }
    });
  }

  /// Try to fetch and register VoIP token, retrying up to [maxAttempts] times
  /// with exponential backoff if the token isn't available yet.
  Future<void> _registerVoipTokenWithRetry(
    String uid,
    String platform, {
    int maxAttempts = 3,
  }) async {
    debugPrint('$_tag _registerVoipTokenWithRetry: uid=$uid, platform=$platform');
    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      try {
        final voipToken = await FlutterCallkitIncoming.getDevicePushTokenVoIP();
        debugPrint('$_tag VoIP token attempt ${attempt + 1}/$maxAttempts: ${voipToken != null ? '${voipToken.substring(0, 8)}...' : 'null'}');
        if (voipToken != null && voipToken.isNotEmpty) {
          await UserService.instance.updatePushTokens(
            voipToken: voipToken,
            platform: platform,
          );
          debugPrint('$_tag VoIP token registered successfully');
          return; // Success — no more retries needed.
        }
      } catch (e) {
        debugPrint('$_tag VoIP token attempt ${attempt + 1} failed: $e');
      }
      // Wait before next attempt (2s, 4s, 8s).
      if (attempt < maxAttempts - 1) {
        final delay = 2 << attempt;
        debugPrint('$_tag VoIP token retry in ${delay}s...');
        await Future<void>.delayed(Duration(seconds: delay));
      }
    }
    debugPrint('$_tag VoIP token exhausted all attempts — waiting for callkit event');
  }

  Future<void> _handleVoipTokenUpdate(Map<String, dynamic> body) async {
    final token = (body['deviceTokenVoIP'] ?? body['token'] ?? '') as String;
    debugPrint('$_tag _handleVoipTokenUpdate: token=${token.isNotEmpty ? '${token.substring(0, 8)}...' : 'empty'}');
    if (token.isEmpty) return;
    final uid = UserService.instance.currentUid();
    if (uid == null) return;
    final platform = Platform.isIOS
        ? 'ios'
        : (Platform.isAndroid ? 'android' : '');
    try {
      await UserService.instance.updatePushTokens(
        voipToken: token,
        platform: platform,
      );
      debugPrint('$_tag VoIP token updated via event');
    } catch (e) {
      debugPrint('$_tag VoIP token event save failed: $e');
    }
  }

  void _emitIncomingCall(CallInvitePayload payload, {bool autoStart = false}) {
    final now = DateTime.now();
    final last = _incomingEmittedAt[payload.callId];
    if (last != null && now.difference(last).inSeconds < 30) {
      debugPrint('$_tag _emitIncomingCall suppressed (duplicate) — callId=${payload.callId}');
      return;
    }
    _incomingEmittedAt[payload.callId] = now;
    debugPrint('$_tag _emitIncomingCall: callId=${payload.callId}, autoStart=$autoStart');
    _incomingCallController.add(
      IncomingCallEvent(payload: payload, autoStart: autoStart),
    );
  }

  Future<void> _emitIncomingCallWithFallback(
    CallInvitePayload? payload,
    String callId,
  ) async {
    if (payload != null) {
      _emitIncomingCall(payload, autoStart: true);
      return;
    }
    if (callId.isEmpty) return;
    try {
      final data =
          await CallService.instance.getCallDoc(callId) ??
          const <String, dynamic>{};
      final channelName =
          (data['channelName'] ?? data['channelId'] ?? callId) as String;
      final groupId = (data['groupId'] ?? '') as String;
      final receiverId = (data['receiverId'] ?? '') as String;
      final callerId = (data['caregiverUserId'] ?? '') as String;
      final callerName = (data['giverNameSnapshot'] ?? '') as String;
      _emitIncomingCall(
        CallInvitePayload(
          callId: callId,
          channelName: channelName,
          groupId: groupId,
          receiverId: receiverId,
          callerId: callerId,
          callerName: callerName,
        ),
        autoStart: true,
      );
    } catch (_) {
      _emitIncomingCall(CallInvitePayload(callId: callId), autoStart: true);
    }
  }

  void dispose() {
    _callkitSub?.cancel();
    _callkitSub = null;
    _authSub?.cancel();
    _authSub = null;
    for (final timer in _missedTimers.values) {
      timer.cancel();
    }
    _missedTimers.clear();
    for (final sub in _incomingCallSubs.values) {
      sub.cancel();
    }
    _incomingCallSubs.clear();
    _callkitShownAt.clear();
    _incomingCallController.close();
    _initialized = false;
  }

  void _scheduleMissedTimeout(String callId) {
    if (callId.isEmpty) return;
    if (_missedTimers.containsKey(callId)) {
      debugPrint('$_tag _scheduleMissedTimeout: already scheduled for callId=$callId — skip');
      return;
    }
    debugPrint('$_tag _scheduleMissedTimeout: 60s timer started for callId=$callId');
    _missedTimers[callId] = Timer(const Duration(seconds: 60), () {
      debugPrint('$_tag missed timeout fired for callId=$callId');
      _missedTimers.remove(callId);
      CallInviteService.instance.missedCall(callId: callId);
    });
  }

  void _cancelMissedTimeout(String callId) {
    final timer = _missedTimers.remove(callId);
    if (timer != null) {
      debugPrint('$_tag _cancelMissedTimeout: cancelled for callId=$callId');
      timer.cancel();
    }
  }

  void _watchIncomingCallStatus(String callId) {
    if (callId.isEmpty) return;
    if (_incomingCallSubs.containsKey(callId)) {
      debugPrint('$_tag _watchIncomingCallStatus: already watching callId=$callId — skip');
      return;
    }
    debugPrint('$_tag _watchIncomingCallStatus: start watching callId=$callId');
    _incomingCallSubs[callId] = CallService.instance
        .streamCallDoc(callId)
        .listen((snapshot) async {
          final data = snapshot.data();
          if (data == null) {
            debugPrint('$_tag watcher: callId=$callId — doc data is null');
            return;
          }
          final status = (data['status'] ?? '') as String;
          debugPrint('$_tag watcher: callId=$callId, status=$status');
          if (status == 'missed' ||
              status == 'declined' ||
              status == 'cancelled') {
            debugPrint('$_tag watcher: terminal status=$status — dismissing CallKit for callId=$callId');
            _cancelMissedTimeout(callId);
            _stopWatchingIncoming(callId);
            _markCallkitHandled(callId);
            try {
              await FlutterCallkitIncoming.endCall(callId);
              debugPrint('$_tag watcher: CallKit dismissed for callId=$callId');
            } catch (e) {
              debugPrint('$_tag watcher: endCall failed — $e');
            }
          }
        });
  }

  void _stopWatchingIncoming(String callId) {
    final sub = _incomingCallSubs.remove(callId);
    if (sub != null) {
      debugPrint('$_tag _stopWatchingIncoming: stopped for callId=$callId');
      sub.cancel();
    }
  }

  bool _shouldShowCallkit(String callId) {
    if (callId.isEmpty) return false;
    final lastShown = _callkitShownAt[callId];
    if (lastShown == null) {
      _callkitShownAt[callId] = DateTime.now();
      debugPrint('$_tag _shouldShowCallkit: callId=$callId — first time, show=true');
      return true;
    }
    // Suppress duplicate show within 2 minutes for the same callId.
    final elapsed = DateTime.now().difference(lastShown);
    if (elapsed.inMinutes >= 2) {
      _callkitShownAt[callId] = DateTime.now();
      debugPrint('$_tag _shouldShowCallkit: callId=$callId — expired, show=true');
      return true;
    }
    debugPrint('$_tag _shouldShowCallkit: callId=$callId — suppressed (${elapsed.inSeconds}s ago)');
    return false;
  }

  void _markCallkitHandled(String callId) {
    _callkitShownAt.remove(callId);
  }

  /// Check whether a call with the given [callId] is already showing in
  /// CallKit / the notification layer. Usable from both instance and static
  /// contexts (e.g. [handleBackgroundMessage]).
  static Future<bool> _isCallActive(String callId) async {
    if (callId.isEmpty) return false;
    try {
      final active = await FlutterCallkitIncoming.activeCalls();
      if (active is List) {
        for (final entry in active) {
          if (entry is Map) {
            final id = (entry['id'] ?? '') as String;
            if (id == callId) {
              debugPrint('$_tag _isCallActive: callId=$callId — YES');
              return true;
            }
          }
        }
      }
    } catch (e) {
      debugPrint('$_tag _isCallActive failed: $e');
    }
    return false;
  }
}

class CallInvitePayload {
  final String callId;
  final String channelName;
  final String callerName;
  final String callerId;
  final String groupId;
  final String receiverId;

  const CallInvitePayload({
    required this.callId,
    this.channelName = '',
    this.callerName = '',
    this.callerId = '',
    this.groupId = '',
    this.receiverId = '',
  });

  Map<String, dynamic> get extra => {
    'callId': callId,
    if (channelName.isNotEmpty) 'channelName': channelName,
    if (callerName.isNotEmpty) 'callerName': callerName,
    if (callerId.isNotEmpty) 'callerId': callerId,
    if (groupId.isNotEmpty) 'groupId': groupId,
    if (receiverId.isNotEmpty) 'receiverId': receiverId,
  };

  static CallInvitePayload? fromMessage(RemoteMessage message) {
    final data = message.data;
    if (data.isEmpty) return null;
    if (data['type'] != 'incoming_call') return null;

    return CallInvitePayload(
      callId: (data['callId'] ?? data['call_id'] ?? data['id'] ?? '') as String,
      channelName:
          (data['channelName'] ?? data['channel_name'] ?? '') as String,
      callerName: (data['callerName'] ?? data['caller_name'] ?? '') as String,
      callerId: (data['callerId'] ?? data['caller_id'] ?? '') as String,
      groupId: (data['groupId'] ?? data['group_id'] ?? '') as String,
      receiverId: (data['receiverId'] ?? data['receiver_id'] ?? '') as String,
    );
  }

  static CallInvitePayload? fromEventBody(Map<String, dynamic> body) {
    if (body.isEmpty) return null;
    final extra = body['extra'];
    if (extra is Map) {
      final map = Map<String, dynamic>.from(extra);
      return CallInvitePayload(
        callId: (map['callId'] ?? map['call_id'] ?? body['id'] ?? '') as String,
        channelName:
            (map['channelName'] ?? map['channel_name'] ?? '') as String,
        callerName: (map['callerName'] ?? map['caller_name'] ?? '') as String,
        callerId: (map['callerId'] ?? map['caller_id'] ?? '') as String,
        groupId: (map['groupId'] ?? map['group_id'] ?? '') as String,
        receiverId: (map['receiverId'] ?? map['receiver_id'] ?? '') as String,
      );
    }
    return null;
  }
}

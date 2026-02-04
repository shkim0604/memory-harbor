import 'dart:async';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_callkit_incoming/entities/entities.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import '../screens/call/receiver_call_screen.dart';
import 'call_invite_service.dart';
import 'user_service.dart';
import '../utils/time_utils.dart';
import 'call_service.dart';

class CallNotificationService {
  CallNotificationService._();
  static final CallNotificationService instance = CallNotificationService._();

  // Used to navigate to CallScreen from push/callkit events.
  GlobalKey<NavigatorState>? _navigatorKey;
  bool _initialized = false;
  StreamSubscription? _callkitSub;
  StreamSubscription<User?>? _authSub;
  final Map<String, Timer> _missedTimers = {};
  final Map<String, StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>>
      _incomingCallSubs = {};
  final Map<String, DateTime> _callkitShownAt = {};

  Future<void> init({required GlobalKey<NavigatorState> navigatorKey}) async {
    if (_initialized) return;
    _initialized = true;
    _navigatorKey = navigatorKey;

    // Permissions and token registration must run once on app start.
    await _requestPermission();
    await _registerTokens();
    _listenAuthChanges();

    FirebaseMessaging.onMessage.listen(handleIncomingMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);

    final initial = await FirebaseMessaging.instance.getInitialMessage();
    if (initial != null) {
      _handleMessageOpenedApp(initial);
    }

    _listenCallkitEvents();
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

  Future<void> _registerTokens() async {
    final uid = UserService.instance.currentUid();
    if (uid == null) return;
    final platform = Platform.isIOS ? 'ios' : (Platform.isAndroid ? 'android' : '');

    // FCM token -> store under users/{uid}
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null && token.isNotEmpty) {
        await UserService.instance.updateUser(uid, {
          'fcmToken': token,
          'fcmTokenUpdatedAt': TimeUtils.nowEt().toIso8601String(),
          if (platform.isNotEmpty) 'platform': platform,
        });
      }
    } catch (_) {
      // TODO: iOS APNS setup not completed yet. Safe to ignore for now.
      // We should retry token registration after APNS token is available.
    }

    // Token rotation -> keep server up-to-date.
    FirebaseMessaging.instance.onTokenRefresh.listen((nextToken) async {
      final currentUid = UserService.instance.currentUid();
      if (currentUid == null || nextToken.isEmpty) return;
      try {
        await UserService.instance.updateUser(currentUid, {
          'fcmToken': nextToken,
          'fcmTokenUpdatedAt': TimeUtils.nowEt().toIso8601String(),
          if (platform.isNotEmpty) 'platform': platform,
        });
      } catch (_) {
        // TODO: iOS APNS setup not completed yet. Safe to ignore for now.
      }
    });

    // iOS VoIP token (CallKit)
    try {
      final voipToken = await FlutterCallkitIncoming.getDevicePushTokenVoIP();
      if (voipToken != null && voipToken.isNotEmpty) {
        await UserService.instance.updateUser(uid, {
          'voipToken': voipToken,
          'voipTokenUpdatedAt': TimeUtils.nowEt().toIso8601String(),
          if (platform.isNotEmpty) 'platform': platform,
        });
      }
    } catch (_) {
      // Ignore if platform doesn't support or token isn't available yet.
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
    if (type == 'call_cancelled') {
      final callId = (message.data['callId'] ??
              message.data['call_id'] ??
              message.data['id'] ??
              '') as String;
      if (callId.isNotEmpty) {
        _cancelMissedTimeout(callId);
        _stopWatchingIncoming(callId);
        _markCallkitHandled(callId);
        try {
          await FlutterCallkitIncoming.endCall(callId);
        } catch (_) {}
      }
      return;
    }
    final payload = CallInvitePayload.fromMessage(message);
    if (payload == null) return;
    final shouldShow = _shouldShowCallkit(payload.callId);
    if (!shouldShow) return;
    // Show system incoming call UI.
    await _showIncomingCall(payload);
    _scheduleMissedTimeout(payload.callId);
    _watchIncomingCallStatus(payload.callId);
  }

  void _handleMessageOpenedApp(RemoteMessage message) {
    final payload = CallInvitePayload.fromMessage(message);
    if (payload == null) return;
    // User tapped notification -> open incoming UI.
    _openCallScreen(payload, autoStart: false);
  }

  Future<void> _showIncomingCall(CallInvitePayload payload) async {
    // Unified CallKit/Full-screen UI (iOS + Android).
    if (await _callkitAlreadyActive(payload.callId)) {
      return;
    }
    final params = CallKitParams(
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
        // Avoid heads-up banner; rely on full-screen incoming UI only.
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

    try {
      // Ensure only one incoming call UI is visible at a time.
      await FlutterCallkitIncoming.endAllCalls();
      await FlutterCallkitIncoming.showCallkitIncoming(params);
    } catch (_) {
      // Ignore callkit failures; notification layer may be missing.
    }
  }

  static Future<void> handleBackgroundMessage(RemoteMessage message) async {
    final payload = CallInvitePayload.fromMessage(message);
    if (payload == null) return;
    try {
      final active = await FlutterCallkitIncoming.activeCalls();
      if (active is List) {
        final exists = active.any((entry) {
          if (entry is Map) {
            final id = (entry['id'] ?? '') as String;
            return id == payload.callId;
          }
          return false;
        });
        if (exists) return;
      }
    } catch (_) {
      // Ignore if activeCalls is unavailable.
    }

    // Background isolate: show incoming call UI without navigation.
    final params = CallKitParams(
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
        // Avoid heads-up banner; rely on full-screen incoming UI only.
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

    try {
      // Ensure only one incoming call UI is visible at a time.
      await FlutterCallkitIncoming.endAllCalls();
      await FlutterCallkitIncoming.showCallkitIncoming(params);
    } catch (_) {
      // Ignore callkit failures; notification layer may be missing.
    }
  }

  void _listenCallkitEvents() {
    _callkitSub = FlutterCallkitIncoming.onEvent.listen((event) {
      final name = (event?.event ?? '').toString();
      final body = event?.body ?? const <String, dynamic>{};
      final callId = (body['id'] ?? body['callId'] ?? '') as String;
      final payload = CallInvitePayload.fromEventBody(body);

      final isAccept = name == 'ACTION_CALL_ACCEPT' ||
          name == 'CALL_ACCEPT' ||
          name.contains('actionCallAccept');
      final isDecline = name == 'ACTION_CALL_DECLINE' ||
          name == 'CALL_DECLINE' ||
          name.contains('actionCallDecline');
      final isTimeout = name == 'ACTION_CALL_TIMEOUT' ||
          name == 'CALL_TIMEOUT' ||
          name.contains('actionCallTimeout');

      // Accept -> notify server + open CallScreen.
      if (isAccept) {
        if (callId.isNotEmpty) {
          _cancelMissedTimeout(callId);
          _stopWatchingIncoming(callId);
          _markCallkitHandled(callId);
          CallInviteService.instance
              .answerCall(callId: callId, action: 'accept');
        }
        _openCallScreenWithFallback(payload, callId);
      }

      if (isDecline) {
        if (callId.isNotEmpty) {
          _cancelMissedTimeout(callId);
          _stopWatchingIncoming(callId);
          _markCallkitHandled(callId);
          CallInviteService.instance
              .answerCall(callId: callId, action: 'decline');
        }
      }

      if (isTimeout) {
        if (callId.isNotEmpty) {
          _cancelMissedTimeout(callId);
          _stopWatchingIncoming(callId);
          _markCallkitHandled(callId);
          CallInviteService.instance.missedCall(callId: callId);
        }
      }
    });
  }

  void _openCallScreen(CallInvitePayload payload, {required bool autoStart}) {
    final nav = _navigatorKey?.currentState;
    if (nav == null) return;

    nav.push(
      MaterialPageRoute(
        builder: (_) => ReceiverCallScreen(
          payload: payload,
          autoStart: autoStart,
        ),
      ),
    );
  }

  Future<void> _openCallScreenWithFallback(
    CallInvitePayload? payload,
    String callId,
  ) async {
    if (payload != null) {
      _openCallScreen(payload, autoStart: true);
      return;
    }
    if (callId.isEmpty) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('calls')
          .doc(callId)
          .get();
      final data = doc.data() ?? const <String, dynamic>{};
      final channelName =
          (data['channelName'] ?? data['channelId'] ?? callId) as String;
      final groupId = (data['groupId'] ?? '') as String;
      final receiverId = (data['receiverId'] ?? '') as String;
      final callerId = (data['caregiverUserId'] ?? '') as String;
      final callerName = (data['giverNameSnapshot'] ?? '') as String;
      _openCallScreen(
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
      _openCallScreen(CallInvitePayload(callId: callId), autoStart: true);
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
    _navigatorKey = null;
    _initialized = false;
  }

  void _scheduleMissedTimeout(String callId) {
    if (callId.isEmpty) return;
    _cancelMissedTimeout(callId);
    _missedTimers[callId] = Timer(const Duration(seconds: 60), () {
      _missedTimers.remove(callId);
      CallInviteService.instance.missedCall(callId: callId);
    });
  }

  void _cancelMissedTimeout(String callId) {
    final timer = _missedTimers.remove(callId);
    timer?.cancel();
  }

  void _watchIncomingCallStatus(String callId) {
    if (callId.isEmpty) return;
    _stopWatchingIncoming(callId);
    _incomingCallSubs[callId] =
        CallService.instance.streamCallDoc(callId).listen((snapshot) async {
      final data = snapshot.data();
      if (data == null) return;
      final status = (data['status'] ?? '') as String;
      if (status == 'missed' || status == 'declined' || status == 'cancelled') {
        _cancelMissedTimeout(callId);
        _stopWatchingIncoming(callId);
        _markCallkitHandled(callId);
        try {
          await FlutterCallkitIncoming.endCall(callId);
        } catch (_) {
          // Ignore if callkit isn't active.
        }
      }
    });
  }

  void _stopWatchingIncoming(String callId) {
    final sub = _incomingCallSubs.remove(callId);
    sub?.cancel();
  }

  bool _shouldShowCallkit(String callId) {
    if (callId.isEmpty) return false;
    final lastShown = _callkitShownAt[callId];
    if (lastShown == null) {
      _callkitShownAt[callId] = DateTime.now();
      return true;
    }
    // Suppress duplicate show within 2 minutes for the same callId.
    final elapsed = DateTime.now().difference(lastShown);
    if (elapsed.inMinutes >= 2) {
      _callkitShownAt[callId] = DateTime.now();
      return true;
    }
    return false;
  }

  void _markCallkitHandled(String callId) {
    _callkitShownAt.remove(callId);
  }

  Future<bool> _callkitAlreadyActive(String callId) async {
    if (callId.isEmpty) return false;
    try {
      final active = await FlutterCallkitIncoming.activeCalls();
      if (active is List) {
        for (final entry in active) {
          if (entry is Map) {
            final id = (entry['id'] ?? '') as String;
            if (id == callId) return true;
          }
        }
      }
    } catch (_) {
      // Ignore if activeCalls is unavailable.
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
      channelName: (data['channelName'] ?? data['channel_name'] ?? '') as String,
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
        channelName: (map['channelName'] ?? map['channel_name'] ?? '') as String,
        callerName: (map['callerName'] ?? map['caller_name'] ?? '') as String,
        callerId: (map['callerId'] ?? map['caller_id'] ?? '') as String,
        groupId: (map['groupId'] ?? map['group_id'] ?? '') as String,
        receiverId: (map['receiverId'] ?? map['receiver_id'] ?? '') as String,
      );
    }
    return null;
  }
}

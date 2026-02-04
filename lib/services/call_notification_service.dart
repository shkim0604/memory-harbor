import 'dart:async';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_callkit_incoming/entities/entities.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:permission_handler/permission_handler.dart';

import '../screens/call/call_screen.dart';
import 'call_invite_service.dart';
import 'user_service.dart';

class CallNotificationService {
  CallNotificationService._();
  static final CallNotificationService instance = CallNotificationService._();

  // Used to navigate to CallScreen from push/callkit events.
  GlobalKey<NavigatorState>? _navigatorKey;
  bool _initialized = false;
  StreamSubscription? _callkitSub;
  StreamSubscription<User?>? _authSub;
  final Map<String, Timer> _missedTimers = {};

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
    final token = await FirebaseMessaging.instance.getToken();
    if (token != null && token.isNotEmpty) {
      await UserService.instance.updateUser(uid, {
        'fcmToken': token,
        'fcmTokenUpdatedAt': DateTime.now().toIso8601String(),
        if (platform.isNotEmpty) 'platform': platform,
      });
    }

    // Token rotation -> keep server up-to-date.
    FirebaseMessaging.instance.onTokenRefresh.listen((nextToken) async {
      final currentUid = UserService.instance.currentUid();
      if (currentUid == null || nextToken.isEmpty) return;
      await UserService.instance.updateUser(currentUid, {
        'fcmToken': nextToken,
        'fcmTokenUpdatedAt': DateTime.now().toIso8601String(),
        if (platform.isNotEmpty) 'platform': platform,
      });
    });

    // iOS VoIP token (CallKit)
    try {
      final voipToken = await FlutterCallkitIncoming.getDevicePushTokenVoIP();
      if (voipToken != null && voipToken.isNotEmpty) {
        await UserService.instance.updateUser(uid, {
          'voipToken': voipToken,
          'voipTokenUpdatedAt': DateTime.now().toIso8601String(),
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
    final payload = CallInvitePayload.fromMessage(message);
    if (payload == null) return;
    // Show system incoming call UI.
    await _showIncomingCall(payload);
    _scheduleMissedTimeout(payload.callId);
  }

  void _handleMessageOpenedApp(RemoteMessage message) {
    final payload = CallInvitePayload.fromMessage(message);
    if (payload == null) return;
    // User tapped notification -> open call screen.
    _openCallScreen(payload);
  }

  Future<void> _showIncomingCall(CallInvitePayload payload) async {
    // Unified CallKit/Full-screen UI (iOS + Android).
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
        isCustomNotification: true,
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
      await FlutterCallkitIncoming.showCallkitIncoming(params);
    } catch (_) {
      // Ignore callkit failures; notification layer may be missing.
    }
  }

  static Future<void> handleBackgroundMessage(RemoteMessage message) async {
    final payload = CallInvitePayload.fromMessage(message);
    if (payload == null) return;

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
        isCustomNotification: true,
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
      await FlutterCallkitIncoming.showCallkitIncoming(params);
    } catch (_) {
      // Ignore callkit failures; notification layer may be missing.
    }
  }

  void _listenCallkitEvents() {
    _callkitSub = FlutterCallkitIncoming.onEvent.listen((event) {
      final name = event?.event ?? '';
      final body = event?.body ?? const <String, dynamic>{};
      final callId = (body['id'] ?? body['callId'] ?? '') as String;
      final payload = CallInvitePayload.fromEventBody(body);

      // Accept -> notify server + open CallScreen.
      if (name == 'ACTION_CALL_ACCEPT' || name == 'CALL_ACCEPT') {
        if (callId.isNotEmpty) {
          _cancelMissedTimeout(callId);
          CallInviteService.instance
              .answerCall(callId: callId, action: 'accept');
        }
        if (payload != null) {
          _openCallScreen(payload);
        } else if (callId.isNotEmpty) {
          _openCallScreen(CallInvitePayload(callId: callId));
        }
      }

      if (name == 'ACTION_CALL_DECLINE' || name == 'CALL_DECLINE') {
        if (callId.isNotEmpty) {
          _cancelMissedTimeout(callId);
          CallInviteService.instance
              .answerCall(callId: callId, action: 'decline');
        }
      }

      if (name == 'ACTION_CALL_TIMEOUT' || name == 'CALL_TIMEOUT') {
        if (callId.isNotEmpty) {
          _cancelMissedTimeout(callId);
          CallInviteService.instance.missedCall(callId: callId);
        }
      }
    });
  }

  void _openCallScreen(CallInvitePayload payload) {
    final nav = _navigatorKey?.currentState;
    if (nav == null) return;

    // Receiver UI not ready yet -> reuse CallScreen directly.
    nav.push(
      MaterialPageRoute(
        builder: (_) => CallScreen(
          startConnecting: true,
          channelName: payload.channelName,
          callId: payload.callId,
        ),
      ),
    );
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
}

class CallInvitePayload {
  final String callId;
  final String channelName;
  final String callerName;
  final String groupId;
  final String receiverId;

  const CallInvitePayload({
    required this.callId,
    this.channelName = '',
    this.callerName = '',
    this.groupId = '',
    this.receiverId = '',
  });

  Map<String, dynamic> get extra => {
    'callId': callId,
    if (channelName.isNotEmpty) 'channelName': channelName,
    if (callerName.isNotEmpty) 'callerName': callerName,
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
        groupId: (map['groupId'] ?? map['group_id'] ?? '') as String,
        receiverId: (map['receiverId'] ?? map['receiver_id'] ?? '') as String,
      );
    }
    return null;
  }
}

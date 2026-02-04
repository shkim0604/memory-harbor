import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Agora Voice Call Service
///
/// 사용법:
/// 1. AgoraService.instance.initialize(appId) 호출
/// 2. joinChannel()로 통화 시작
/// 3. leaveChannel()로 통화 종료
class AgoraService {
  AgoraService._();
  static final instance = AgoraService._();

  RtcEngine? _engine;
  bool _isInitialized = false;
  bool _isInChannel = false;
  bool _isMuted = false;
  bool _isSpeakerOn = true;
  String? _currentChannelName;
  Future<bool>? _initializeFuture;
  String? _logFilePath;

  // Callbacks
  Function(int uid)? onUserJoined;
  Function(int uid, UserOfflineReasonType reason)? onUserOffline;
  Function(String message)? onError;
  Function()? onJoinChannelSuccess;
  Function()? onLeaveChannel;
  Function(RtcConnection connection, RtcStats stats)? onRtcStats;

  // Getters
  bool get isInitialized => _isInitialized;
  bool get isInChannel => _isInChannel;
  bool get isMuted => _isMuted;
  bool get isSpeakerOn => _isSpeakerOn;
  String? get logFilePath => _logFilePath;

  // ============================================================================
  // Initialize
  // ============================================================================
  Future<bool> initialize(String appId) async {
    if (_isInitialized) return true;
    if (_initializeFuture != null) return _initializeFuture!;

    final next = _initializeInternal(appId);
    _initializeFuture = next;
    return next;
  }

  Future<bool> _initializeInternal(String appId) async {
    try {
      final trimmedAppId = appId.trim();
      if (trimmedAppId.isEmpty) {
        onError?.call('Agora App ID가 비어있습니다. 설정을 확인하세요.');
        return false;
      }

      final logFilePath = await _resolveAgoraLogFilePath();
      _logFilePath = logFilePath;
      if (logFilePath != null) {
        debugPrint('Agora: Log file path: $logFilePath');
      }

      final prefix = trimmedAppId.length >= 8
          ? trimmedAppId.substring(0, 8)
          : trimmedAppId;
      debugPrint('Agora: Starting initialization with appId: $prefix...');

      // If there is a stale engine instance (failed init / partial init), release it.
      if (_engine != null) {
        try {
          await _engine!.release();
        } catch (_) {
          // Ignore release failures; we are best-effort resetting state.
        }
        _engine = null;
      }

      _engine = createAgoraRtcEngine();

      await _engine!.initialize(
        RtcEngineContext(
          appId: trimmedAppId,
          areaCode: AreaCode.areaCodeGlob.value(),
          channelProfile: ChannelProfileType.channelProfileCommunication,
          logConfig: LogConfig(
            level: LogLevel.logLevelInfo,
            filePath: logFilePath,
          ),
        ),
      );

      await _engine!.enableAudio();

      _engine!.registerEventHandler(
        RtcEngineEventHandler(
          onJoinChannelSuccess: (connection, elapsed) {
            debugPrint('Agora: Joined channel ${connection.channelId}');
            _isInChannel = true;
            onJoinChannelSuccess?.call();
          },
          onLeaveChannel: (connection, stats) {
            debugPrint('Agora: Left channel');
            _isInChannel = false;
            onLeaveChannel?.call();
          },
          onUserJoined: (connection, remoteUid, elapsed) {
            debugPrint('Agora: User $remoteUid joined');
            onUserJoined?.call(remoteUid);
          },
          onUserOffline: (connection, remoteUid, reason) {
            debugPrint('Agora: User $remoteUid offline');
            onUserOffline?.call(remoteUid, reason);
          },
          onError: (err, msg) {
            debugPrint('Agora Error: $err - $msg');
            final merged = msg.trim().isEmpty ? '$err' : '$err - $msg';
            onError?.call(merged);
          },
          onRtcStats: (connection, stats) {
            onRtcStats?.call(connection, stats);
          },
        ),
      );

      await _engine!.setAudioProfile(
        profile: AudioProfileType.audioProfileSpeechStandard,
        scenario: AudioScenarioType.audioScenarioChatroom,
      );

      // iOS simulator can fail this with AgoraRtcException(-3, null).
      // Treat it as non-fatal so the rest of the RTC engine can still work.
      try {
        await _engine!.setEnableSpeakerphone(true);
        _isSpeakerOn = true;
      } on AgoraRtcException catch (e) {
        _isSpeakerOn = false;
        debugPrint(
          'Agora: setEnableSpeakerphone failed (code=${e.code}, message=${e.message}); continuing initialization',
        );
      } catch (e) {
        _isSpeakerOn = false;
        debugPrint(
          'Agora: setEnableSpeakerphone failed ($e); continuing initialization',
        );
      }

      _isInitialized = true;
      debugPrint('Agora: Initialized successfully');
      return true;
    } on AgoraRtcException catch (e) {
      debugPrint(
        'Agora: Initialization failed - AgoraRtcException(code=${e.code}, message=${e.message})',
      );
      onError?.call(
        '초기화 실패: AgoraRtcException(code=${e.code}, message=${e.message ?? 'null'})',
      );
      await _debugDumpAgoraLogTail(_logFilePath);
      await _resetAfterInitFailure();
      return false;
    } catch (e) {
      debugPrint('Agora: Initialization failed - $e');
      onError?.call('초기화 실패: $e');
      await _debugDumpAgoraLogTail(_logFilePath);
      await _resetAfterInitFailure();
      return false;
    } finally {
      _initializeFuture = null;
    }
  }

  Future<void> _resetAfterInitFailure() async {
    _isInitialized = false;
    _isInChannel = false;
    _currentChannelName = null;
    if (_engine != null) {
      try {
        await _engine!.release();
      } catch (_) {}
      _engine = null;
    }
  }

  Future<void> _debugDumpAgoraLogTail(
    String? path, {
    int maxBytes = 8192,
  }) async {
    if (path == null || path.trim().isEmpty) return;
    try {
      final type = await FileSystemEntity.type(path, followLinks: false);
      if (type == FileSystemEntityType.notFound) {
        debugPrint('Agora: Log path not found yet at: $path');
        return;
      }

      if (type == FileSystemEntityType.directory) {
        final dir = Directory(path);
        final candidates = <File>[];
        await for (final entity in dir.list(followLinks: false)) {
          if (entity is! File) continue;
          final name = entity.path.split(Platform.pathSeparator).last;
          if (!name.endsWith('.log')) continue;
          candidates.add(entity);
        }

        if (candidates.isEmpty) {
          debugPrint('Agora: No .log files found under: $path');
          return;
        }

        candidates.sort((a, b) {
          int rank(File f) {
            final name = f.path.split(Platform.pathSeparator).last;
            if (name == 'agorasdk.log') return 0;
            if (name.startsWith('agorasdk.')) return 1;
            if (name == 'agoraapi.log') return 2;
            if (name.startsWith('agoraapi.')) return 3;
            return 10;
          }

          final ra = rank(a);
          final rb = rank(b);
          if (ra != rb) return ra.compareTo(rb);
          return a.path.compareTo(b.path);
        });

        for (final file in candidates.take(2)) {
          await _debugDumpFileTail(file, maxBytes: maxBytes);
        }
        return;
      }

      await _debugDumpFileTail(File(path), maxBytes: maxBytes);
    } catch (e) {
      debugPrint('Agora: Failed to read agora log: $e');
    }
  }

  Future<void> _debugDumpFileTail(File file, {required int maxBytes}) async {
    if (!await file.exists()) return;
    final raf = await file.open(mode: FileMode.read);
    try {
      final length = await raf.length();
      final start = length > maxBytes ? length - maxBytes : 0;
      await raf.setPosition(start);
      final bytes = await raf.read(length - start);
      final tail = utf8.decode(bytes, allowMalformed: true).trim();
      if (tail.isEmpty) return;

      final name = file.path.split(Platform.pathSeparator).last;
      debugPrint('Agora: ===== $name (tail) =====');
      const chunkSize = 800;
      for (var i = 0; i < tail.length; i += chunkSize) {
        final end = (i + chunkSize) < tail.length
            ? (i + chunkSize)
            : tail.length;
        debugPrint(tail.substring(i, end));
      }
      debugPrint('Agora: ===== $name (end) =====');
    } finally {
      await raf.close();
    }
  }

  Future<String?> _resolveAgoraLogFilePath() async {
    try {
      final dir = await getTemporaryDirectory();
      // Agora writes `agorasdk.log`, `agoraapi.log`, etc. under this directory.
      // The directory must exist and be writable.
      return dir.path;
    } catch (_) {
      return null;
    }
  }

  // ============================================================================
  // Join Channel
  // ============================================================================
  Future<bool> joinChannel({
    required String channelName,
    required String token, // Use empty string for testing without token
    required int uid,
  }) async {
    if (!_isInitialized || _engine == null) {
      onError?.call('Agora가 초기화되지 않았습니다');
      return false;
    }

    if (_isInChannel) {
      debugPrint('Agora: Already in a channel');
      return true;
    }

    try {
      _currentChannelName = channelName;

      // Join channel
      await _engine!.joinChannel(
        token: token,
        channelId: channelName,
        uid: uid,
        options: const ChannelMediaOptions(
          clientRoleType: ClientRoleType.clientRoleBroadcaster,
          channelProfile: ChannelProfileType.channelProfileCommunication,
          autoSubscribeAudio: true,
        ),
      );

      return true;
    } catch (e) {
      debugPrint('Agora: Join channel failed - $e');
      onError?.call('채널 참가 실패: $e');
      _currentChannelName = null;
      return false;
    }
  }

  // ============================================================================
  // Token Fetch (optional)
  // ============================================================================
  Future<String?> fetchToken({
    required String apiBaseUrl,
    required String channelName,
    required int uid,
    String? userAccount,
    String role = 'publisher',
    int? expireSeconds,
  }) async {
    try {
      final uri = Uri.parse('$apiBaseUrl/api/token');
      final requestBody = jsonEncode(<String, dynamic>{
        'channel': channelName,
        'uid': uid,
        if (userAccount != null && userAccount.isNotEmpty)
          'user_account': userAccount,
        'role': role,
        if (expireSeconds != null) 'expire': expireSeconds,
      });

      debugPrint('=== fetchToken START ===');
      debugPrint('URL: $uri');
      debugPrint('Method: POST');
      debugPrint('Request Body: $requestBody');

      final client = HttpClient();
      final request = await client.postUrl(uri);
      request.headers.contentType = ContentType.json;
      request.write(requestBody);

      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      client.close();

      debugPrint('Response Status: ${response.statusCode}');
      debugPrint('Response Body: $body');
      debugPrint('=== fetchToken END ===');

      if (response.statusCode < 200 || response.statusCode >= 300) {
        onError?.call('토큰 서버 오류: ${response.statusCode}');
        return null;
      }

      final json = jsonDecode(body);
      if (json is Map) {
        if (json['token'] is String) {
          debugPrint('Token fetched successfully!');
          return json['token'] as String;
        }
        if (json['rtcToken'] is String) {
          debugPrint('Token (rtcToken) fetched successfully!');
          return json['rtcToken'] as String;
        }
      }

      onError?.call('토큰 응답 형식 오류');
      return null;
    } catch (e) {
      onError?.call('토큰 요청 실패: $e');
      return null;
    }
  }

  // ============================================================================
  // Server Recording (Start/Stop)
  // ============================================================================
  Future<bool> startServerRecording({
    required String apiBaseUrl,
    required String channelName,
    required int uid,
    String? token,
    String? groupId,
    String? callerId,
    String? receiverId,
  }) async {
    try {
      final uri = Uri.parse('$apiBaseUrl/api/recording/start');
      final client = HttpClient();
      final request = await client.postUrl(uri);
      request.headers.contentType = ContentType.json;
      request.write(
        jsonEncode(<String, dynamic>{
          'channel': channelName,
          if (token != null && token.isNotEmpty) 'token': token,
          'uid': uid,
          if (groupId != null && groupId.isNotEmpty) 'group_id': groupId,
          if (callerId != null && callerId.isNotEmpty) 'caller_id': callerId,
          if (receiverId != null && receiverId.isNotEmpty)
            'receiver_id': receiverId,
        }),
      );
      final response = await request.close();
      await response.transform(utf8.decoder).join();
      client.close();

      if (response.statusCode < 200 || response.statusCode >= 300) {
        onError?.call('레코딩 start 실패: ${response.statusCode}');
        return false;
      }
      return true;
    } catch (e) {
      onError?.call('레코딩 start 요청 실패: $e');
      return false;
    }
  }

  Future<bool> stopServerRecording({
    required String apiBaseUrl,
    required String channelName,
    required int uid,
  }) async {
    try {
      final uri = Uri.parse('$apiBaseUrl/api/recording/stop');
      final client = HttpClient();
      final request = await client.postUrl(uri);
      request.headers.contentType = ContentType.json;
      request.write(
        jsonEncode(<String, dynamic>{'channel': channelName, 'uid': uid}),
      );
      final response = await request.close();
      await response.transform(utf8.decoder).join();
      client.close();

      if (response.statusCode < 200 || response.statusCode >= 300) {
        onError?.call('레코딩 stop 실패: ${response.statusCode}');
        return false;
      }
      return true;
    } catch (e) {
      onError?.call('레코딩 stop 요청 실패: $e');
      return false;
    }
  }

  // ============================================================================
  // Leave Channel
  // ============================================================================
  Future<void> leaveChannel() async {
    if (!_isInChannel || _engine == null) return;

    try {
      await _engine!.leaveChannel();
      _isInChannel = false;
      _currentChannelName = null;
    } catch (e) {
      debugPrint('Agora: Leave channel failed - $e');
    }
  }

  // ============================================================================
  // Mute/Unmute
  // ============================================================================
  Future<void> toggleMute() async {
    if (_engine == null) return;

    _isMuted = !_isMuted;
    await _engine!.muteLocalAudioStream(_isMuted);
  }

  Future<void> setMuted(bool muted) async {
    if (_engine == null) return;

    _isMuted = muted;
    await _engine!.muteLocalAudioStream(_isMuted);
  }

  Future<void> muteLocalAudio(bool muted) async {
    await setMuted(muted);
  }

  // ============================================================================
  // Speaker On/Off
  // ============================================================================
  Future<void> toggleSpeaker() async {
    if (_engine == null) return;

    _isSpeakerOn = !_isSpeakerOn;
    await _engine!.setEnableSpeakerphone(_isSpeakerOn);
  }

  Future<void> setSpeakerOn(bool speakerOn) async {
    if (_engine == null) return;

    _isSpeakerOn = speakerOn;
    await _engine!.setEnableSpeakerphone(_isSpeakerOn);
  }

  Future<void> setSpeakerphoneOn(bool speakerOn) async {
    await setSpeakerOn(speakerOn);
  }

  // ============================================================================
  // Dispose
  // ============================================================================
  Future<void> dispose() async {
    if (_isInChannel) {
      await leaveChannel();
    }

    if (_engine != null) {
      await _engine!.release();
      _engine = null;
    }

    _isInitialized = false;
    _currentChannelName = null;
    _initializeFuture = null;
    _logFilePath = null;
  }
}

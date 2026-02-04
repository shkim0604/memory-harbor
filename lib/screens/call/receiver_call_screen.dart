import 'dart:async';

import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../viewmodels/call_session_viewmodel.dart';
import '../../services/call_invite_service.dart';
import '../../services/call_notification_service.dart';
import '../../widgets/call_status_indicator.dart';
import '../../services/call_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ReceiverCallScreen extends StatefulWidget {
  final CallInvitePayload? payload;
  final bool autoStart;

  const ReceiverCallScreen({
    super.key,
    this.payload,
    this.autoStart = false,
  });

  @override
  State<ReceiverCallScreen> createState() => _ReceiverCallScreenState();
}

class _ReceiverCallScreenState extends State<ReceiverCallScreen> {
  final CallSessionViewModel _session = CallSessionViewModel.instance;
  late final VoidCallback _onSessionChanged;
  bool _accepted = false;
  bool _starting = false;
  bool _ending = false;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _callStatusSub;
  bool _actionLocked = false;

  @override
  void initState() {
    super.initState();
    _onSessionChanged = () {
      if (!mounted) return;
      if (_accepted && _session.status == CallStatus.ended) {
        Navigator.of(context).popUntil((route) => route.isFirst);
        return;
      }
      setState(() {});
    };
    _session.init();
    _session.addListener(_onSessionChanged);
    _accepted = widget.autoStart || _session.status != CallStatus.ended;
    if (widget.autoStart) {
      _startCall();
    }

    final callId = widget.payload?.callId ?? '';
    if (callId.isNotEmpty) {
      _attachCallStatusListener(callId);
    }
  }

  @override
  void dispose() {
    _callStatusSub?.cancel();
    _session.removeListener(_onSessionChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final callerName = widget.payload?.callerName.trim();
    final displayName = (callerName != null && callerName.isNotEmpty)
        ? callerName
        : '상대방';

    return Scaffold(
      backgroundColor: AppColors.secondary,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 24),
            _buildHeader(displayName),
            const Spacer(),
            _buildAvatar(displayName),
            const SizedBox(height: 24),
            _buildStatus(),
            const Spacer(),
            _accepted ? _buildInCallControls() : _buildIncomingControls(),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(String name) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close, color: Colors.white),
          ),
          const Spacer(),
          Text(
            name,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const Spacer(),
          const SizedBox(width: 40),
        ],
      ),
    );
  }

  Widget _buildAvatar(String name) {
    final initial = name.isNotEmpty ? name.characters.first : '?';
    return Container(
      width: 130,
      height: 130,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: 0.15),
        border: Border.all(color: Colors.white24, width: 2),
      ),
      child: Center(
        child: Text(
          initial,
          style: const TextStyle(
            fontSize: 46,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildStatus() {
    final statusText = switch (_session.status) {
      CallStatus.connecting => '연결 중...',
      CallStatus.onCall => '통화 중 · ${_session.formattedDuration}',
      CallStatus.ended => _accepted ? '통화 종료' : '수신 대기',
    };

    return Text(
      statusText,
      style: TextStyle(
        fontSize: 18,
        color: Colors.white.withValues(alpha: 0.85),
      ),
    );
  }

  Widget _buildIncomingControls() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 36),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildActionButton(
            color: Colors.red,
            icon: Icons.call_end,
            label: '거절',
            onPressed: _declineCall,
          ),
          _buildActionButton(
            color: AppColors.onCall,
            icon: Icons.call,
            label: '수락',
            onPressed: _acceptCall,
          ),
        ],
      ),
    );
  }

  Widget _buildInCallControls() {
    final isInCall = _session.status == CallStatus.onCall;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildMiniButton(
                icon: _session.isMuted ? Icons.mic_off : Icons.mic,
                label: _session.isMuted ? '음소거 해제' : '음소거',
                isActive: _session.isMuted,
                enabled: isInCall,
                onPressed: _session.toggleMute,
              ),
              _buildMiniButton(
                icon: _session.isSpeaker ? Icons.volume_up : Icons.volume_down,
                label: '스피커',
                isActive: _session.isSpeaker,
                enabled: isInCall,
                onPressed: _session.toggleSpeaker,
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildActionButton(
            color: Colors.red,
            icon: Icons.call_end,
            label: '통화 종료',
            onPressed: _endCall,
            size: 76,
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required Color color,
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    double size = 64,
  }) {
    return Column(
      children: [
        GestureDetector(
          onTap: _actionLocked ? null : onPressed,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: size * 0.45),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 16,
            color: Colors.white.withValues(alpha: 0.8),
          ),
        ),
      ],
    );
  }

  Widget _buildMiniButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    bool isActive = false,
    bool enabled = true,
  }) {
    final opacity = enabled ? 1.0 : 0.4;

    return GestureDetector(
      onTap: enabled ? onPressed : null,
      child: Opacity(
        opacity: opacity,
        child: Column(
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isActive
                    ? AppColors.primary
                    : Colors.white.withValues(alpha: 0.15),
              ),
              child: Icon(
                icon,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _acceptCall() async {
    if (_starting || _accepted || _actionLocked) return;
    final payload = widget.payload;
    if (payload == null || payload.callId.isEmpty) return;
    _starting = true;
    _actionLocked = true;
    try {
      await CallInviteService.instance
          .answerCall(callId: payload.callId, action: 'accept');
      _accepted = true;
      if (mounted) setState(() {});
      await _startCall();
    } finally {
      _starting = false;
      _actionLocked = false;
    }
  }

  Future<void> _declineCall() async {
    if (_ending || _actionLocked) return;
    _ending = true;
    _actionLocked = true;
    final payload = widget.payload;
    if (payload != null && payload.callId.isNotEmpty) {
      await CallInviteService.instance
          .answerCall(callId: payload.callId, action: 'decline');
    }
    if (mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
    _ending = false;
    _actionLocked = false;
  }

  Future<void> _startCall() async {
    final payload = widget.payload;
    if (payload == null) {
      _showError('채널 정보를 찾을 수 없습니다');
      return;
    }
    final channelName = payload.channelName.isNotEmpty
        ? payload.channelName
        : payload.callId;
    if (channelName.isEmpty) {
      _showError('채널 정보를 찾을 수 없습니다');
      return;
    }

    await _session.startCall(
      context,
      groupId: payload.groupId,
      channelName: channelName,
      callerUserId: payload.callerId,
      peerUserId: payload.receiverId,
      callId: payload.callId,
    );
  }

  Future<void> _endCall() async {
    if (_actionLocked) return;
    _actionLocked = true;
    try {
      await _session.endCall();
    } finally {
      _actionLocked = false;
    }
  }

  void _attachCallStatusListener(String callId) {
    _callStatusSub?.cancel();
    _callStatusSub =
        CallService.instance.streamCallDoc(callId).listen((snapshot) async {
      final data = snapshot.data();
      if (data == null) return;
      final status = (data['status'] ?? '') as String;
      if (status == 'missed' || status == 'declined' || status == 'cancelled') {
        await _session.endCall();
        if (mounted) {
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      }
    });
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red.shade400),
    );
  }
}

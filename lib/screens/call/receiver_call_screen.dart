import 'package:flutter/material.dart';
import 'dart:io';
import '../../theme/app_colors.dart';
import '../../viewmodels/call_session_viewmodel.dart';
import '../../services/call_notification_service.dart';
import '../../widgets/call_status_indicator.dart';
import '../../widgets/profile_avatar.dart';

class ReceiverCallScreen extends StatefulWidget {
  final CallInvitePayload? payload;
  final bool autoStart;

  const ReceiverCallScreen({super.key, this.payload, this.autoStart = false});

  @override
  State<ReceiverCallScreen> createState() => _ReceiverCallScreenState();
}

class _ReceiverCallScreenState extends State<ReceiverCallScreen> {
  final CallSessionViewModel _session = CallSessionViewModel.instance;
  late final VoidCallback _onSessionChanged;
  bool _accepted = false;
  bool _starting = false;
  bool _actionLocked = false;

  @override
  void initState() {
    super.initState();
    _onSessionChanged = () {
      if (!mounted) return;
      // Server cancelled the call while still ringing.
      if (_session.remotelyCancelled &&
          _session.status == CallSessionState.ended) {
        Navigator.of(context).popUntil((route) => route.isFirst);
        return;
      }
      if (_session.status == CallSessionState.ended) {
        Navigator.of(context).popUntil((route) => route.isFirst);
        return;
      }
      if (_session.status == CallSessionState.onCall && !_accepted) {
        _accepted = true;
      }
      setState(() {});
    };
    _session.init();
    _session.addListener(_onSessionChanged);
    _accepted = widget.autoStart || _session.status != CallSessionState.ended;
    if (widget.autoStart && widget.payload != null) {
      _autoStartCall();
    }

    final callId = widget.payload?.callId ?? '';
    if (callId.isNotEmpty) {
      _session.watchCallStatus(callId);
    }
  }

  @override
  void dispose() {
    _session.removeListener(_onSessionChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final callerName = widget.payload?.callerName.trim();
    final callerProfileImage =
        widget.payload?.callerProfileImage.trim() ?? '';
    final displayName = (callerName != null && callerName.isNotEmpty)
        ? callerName
        : '상대방';

    final showInCallControls =
        _accepted || _session.status == CallSessionState.onCall;
    final showAvatarFallback = callerProfileImage.isEmpty;

    return Scaffold(
      backgroundColor: AppColors.secondary,
      body: Stack(
        fit: StackFit.expand,
        children: [
          _buildBackground(callerProfileImage),
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 24),
                _buildHeader(displayName),
                const Spacer(),
                if (showAvatarFallback) ...[
                  _buildAvatar(
                    name: displayName,
                    imageUrl: callerProfileImage,
                  ),
                  const SizedBox(height: 24),
                ],
                _buildStatus(),
                const Spacer(),
                showInCallControls
                    ? _buildInCallControls()
                    : _buildIncomingControls(),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackground(String imageUrl) {
    if (imageUrl.isEmpty) {
      return DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.secondary, AppColors.primary],
          ),
        ),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        Image.network(
          imageUrl,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) {
            return const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [AppColors.secondary, AppColors.primary],
                ),
              ),
            );
          },
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.32),
                Colors.black.withValues(alpha: 0.62),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(String name) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: Icon(
              Icons.keyboard_arrow_down,
              color: Colors.white,
              size: Platform.isIOS ? 28 : 24,
            ),
            tooltip: '작게 보기',
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

  Widget _buildAvatar({required String name, required String imageUrl}) {
    return ProfileAvatar(
      imageUrl: imageUrl.isNotEmpty ? imageUrl : null,
      fallbackText: name,
      size: 130,
      borderColor: Colors.white24,
      borderWidth: 2,
      backgroundColor: Colors.white.withValues(alpha: 0.15),
    );
  }

  Widget _buildStatus() {
    final statusText = switch (_session.status) {
      CallSessionState.connecting => '연결 중...',
      CallSessionState.onCall => '통화 중 · ${_session.formattedDuration}',
      CallSessionState.ended => _accepted ? '통화 종료' : '수신 대기',
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
    final canControlAudio =
        _session.status == CallSessionState.connecting ||
        _session.status == CallSessionState.onCall;

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
                enabled: canControlAudio,
                onPressed: _session.toggleMute,
              ),
              _buildMiniButton(
                icon: _session.isSpeaker ? Icons.volume_up : Icons.volume_down,
                label: '스피커',
                isActive: _session.isSpeaker,
                enabled: canControlAudio,
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
              child: Icon(icon, color: Colors.white, size: 24),
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
      _accepted = true;
      if (mounted) setState(() {});
      final ok = await _session.acceptIncoming(context, payload: payload);
      if (!ok) {
        _accepted = false;
        if (mounted) setState(() {});
      }
    } finally {
      _starting = false;
      _actionLocked = false;
    }
  }

  Future<void> _declineCall() async {
    if (_actionLocked) return;
    _actionLocked = true;
    final payload = widget.payload;
    if (payload != null && payload.callId.isNotEmpty) {
      await _session.declineIncoming(callId: payload.callId);
    }
    if (mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
    _actionLocked = false;
  }

  Future<void> _autoStartCall() async {
    final payload = widget.payload;
    if (payload == null) return;
    final sameCallInProgress =
        _session.currentCallId == payload.callId &&
        (_session.status == CallSessionState.connecting ||
            _session.status == CallSessionState.onCall);
    if (sameCallInProgress) {
      _accepted = true;
      if (mounted) setState(() {});
      return;
    }
    if (_starting || _actionLocked) return;
    _starting = true;
    _actionLocked = true;
    try {
      final ok = await _session.acceptIncoming(context, payload: payload);
      if (!ok) {
        _accepted = false;
        if (mounted) setState(() {});
      }
    } finally {
      _starting = false;
      _actionLocked = false;
    }
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
}

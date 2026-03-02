import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../config/call_config.dart';
import '../../theme/app_colors.dart';
import '../../widgets/call_status_indicator.dart';
import '../../widgets/memo_bottom_sheet.dart';
import 'call_detail_screen.dart';
import '../reviews/review_write_screen.dart';
import '../../viewmodels/call_viewmodel.dart';
import '../../viewmodels/call_session_viewmodel.dart';

class CallScreen extends StatefulWidget {
  final bool startConnecting;
  final String? groupId;
  final String? channelName;
  final String? callId;
  final String? token;
  final int? uid;
  final VoidCallback? onCallEnded;

  const CallScreen({
    super.key,
    this.startConnecting = false,
    this.groupId,
    this.channelName,
    this.callId,
    this.token,
    this.uid,
    this.onCallEnded,
  });

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  final CallViewModel _viewModel = CallViewModel();
  final CallSessionViewModel _session = CallSessionViewModel.instance;
  int? _selectedResidenceIndex;
  late final VoidCallback _onSessionChanged;
  bool _autoStarted = false;
  bool _autoStartPending = false;
  CallSessionState _lastStatus = CallSessionState.ended;
  bool _reviewPromptShowing = false;
  String? _activeCallId;
  bool _callActionLocked = false;

  @override
  void initState() {
    super.initState();
    _onSessionChanged = () {
      if (_session.status == CallSessionState.ended) {
        _autoStarted = false;
        _autoStartPending = false;
      }
      // Server cancelled the call while still ringing.
      if (_session.remotelyCancelled &&
          _session.status == CallSessionState.ended) {
        if (mounted) {
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
        return;
      }
      if (_lastStatus == CallSessionState.onCall &&
          _session.status == CallSessionState.ended) {
        _handleCallEndedFromOnCall();
      }
      _lastStatus = _session.status;
      if (mounted) setState(() {});
    };
    _session.init();
    _session.addListener(_onSessionChanged);
    _session.addErrorListener(_showErrorSnackBar);
    _viewModel.init(
      onChanged: () {
        if (mounted) setState(() {});
        _maybeAutoStart();
      },
    );

    if (widget.callId != null && widget.callId!.isNotEmpty) {
      _session.watchCallStatus(widget.callId!);
    }

    if (widget.startConnecting) {
      if (widget.channelName != null && widget.channelName!.isNotEmpty) {
        _startCallWithContext();
      } else {
        _autoStartPending = true;
        _maybeAutoStart();
      }
    }
  }

  @override
  void dispose() {
    _session.removeListener(_onSessionChanged);
    _session.removeErrorListener(_showErrorSnackBar);
    _viewModel.dispose();
    super.dispose();
  }

  String get _formattedDuration => _session.formattedDuration;

  Future<void> _startCallWithContext() async {
    if (_autoStarted || _callActionLocked) return;
    _callActionLocked = true;
    _autoStarted = true;
    final groupId = widget.groupId ?? _viewModel.group?.groupId;
    final callerUserId = _viewModel.user?.uid;
    final peerUserId = _viewModel.receiver?.receiverId;
    String? channelName = widget.channelName;

    // If channel info was already provided (e.g. from an existing call),
    // join directly. Otherwise ask the ViewModel to invite + join.
    if ((channelName == null || channelName.isEmpty) &&
        groupId != null &&
        groupId.isNotEmpty &&
        callerUserId != null &&
        callerUserId.isNotEmpty &&
        peerUserId != null &&
        peerUserId.isNotEmpty) {
      final ok = await _session.startCallWithInvite(
        context,
        groupId: groupId,
        callerId: callerUserId,
        receiverId: peerUserId,
        callerName: _viewModel.user?.name,
        groupNameSnapshot: _viewModel.group?.name,
        receiverNameSnapshot: _viewModel.receiver?.name,
      );
      if (!ok) {
        _autoStarted = false;
      }
      _activeCallId = _session.currentCallId;
      _callActionLocked = false;
      return;
    }

    await _session.startCall(
      context,
      groupId: groupId,
      channelName: channelName,
      callerUserId: callerUserId,
      peerUserId: peerUserId,
      callId: _activeCallId ?? widget.callId,
      token: widget.token,
      uid: widget.uid,
    );
    _callActionLocked = false;
  }

  void _maybeAutoStart() {
    if (!_autoStartPending || _autoStarted) return;
    if (_viewModel.status != CallDataStatus.ready) return;
    _autoStartPending = false;
    _startCallWithContext();
  }

  Future<void> _endCall() async {
    if (_callActionLocked) return;
    _callActionLocked = true;
    final wasOnCall = _session.status == CallSessionState.onCall;
    await _session.endCall();
    _autoStarted = false;
    _autoStartPending = false;
    if (!wasOnCall) {
      widget.onCallEnded?.call();
      if (mounted) {
        Navigator.pop(context);
      }
    }
    _callActionLocked = false;
  }

  Future<void> _toggleMute() async {
    await _session.toggleMute();
  }

  Future<void> _toggleSpeaker() async {
    await _session.toggleSpeaker();
  }

  Future<void> _handleCallEndedFromOnCall() async {
    if (_reviewPromptShowing || !mounted) return;
    final durationSeconds = _session.callDurationSeconds;
    final navigator = Navigator.of(context);
    bool shouldShowReview = durationSeconds >= CallConfig.normalCallMinSeconds;

    if (!shouldShowReview) {
      _reviewPromptShowing = true;
      final isNormal = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('통화 종료'),
            content: const Text('정상적으로 통화가 종료되었나요?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('아니요'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('네'),
              ),
            ],
          );
        },
      );
      shouldShowReview = isNormal == true;
    }

    if (!mounted) return;
    _reviewPromptShowing = false;

    if (shouldShowReview) {
      navigator.popUntil((route) => route.isFirst);
      navigator.push(
        MaterialPageRoute(
          builder: (_) => ReviewWriteScreen(
            callId: _session.currentCallId ?? _activeCallId ?? widget.callId,
            onDone: () {
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
          ),
        ),
      );
    } else {
      navigator.popUntil((route) => route.isFirst);
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red.shade400),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_viewModel.status == CallDataStatus.unauthenticated) {
      return const Scaffold(
        backgroundColor: AppColors.secondary,
        body: Center(child: Text('로그인이 필요합니다')),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.secondary,
      body: SafeArea(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_viewModel.status == CallDataStatus.noGroup) {
      return const Center(child: Text('아직 그룹에 속해 있지 않습니다'));
    }

    if (_viewModel.status != CallDataStatus.ready) {
      return const Center(child: Text('데이터를 불러오는 중...'));
    }

    final receiver = _viewModel.receiver;
    if (receiver == null) {
      return const Center(child: Text('나레이터 정보를 불러오는 중...'));
    }

    return Column(
      children: [
        _buildStatusSection(receiver),
        Expanded(child: _buildResidenceSection(receiver, _viewModel.statsList)),
        _buildControlSection(),
      ],
    );
  }

  // ============================================================
  // 상단: Status 섹션
  // ============================================================
  Widget _buildStatusSection(CareReceiver receiver) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
        children: [
          Column(
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: _buildPipButton(),
                  ),
                  Text(
                    receiver.name,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: _buildStatusCard(),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (_session.remoteUsers.isNotEmpty)
                Text(
                  '참여자: ${_session.remoteUsers.length + 1}명',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================================
  // 중단: 시대별 거주지 리스트
  // ============================================================
  Widget _buildResidenceSection(
    CareReceiver receiver,
    List<ResidenceStats> statsList,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.location_on, color: AppColors.primary, size: 22),
              const SizedBox(width: 8),
              const Text(
                '시대별 거주지',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              Text(
                '대화 주제를 선택하세요',
                style: TextStyle(fontSize: 12, color: AppColors.textHint),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.separated(
              itemCount: statsList.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final stats = statsList[index];
                final isSelected = _selectedResidenceIndex == index;
                return _buildResidenceCard(
                  era: stats.era,
                  location: stats.location,
                  detail: stats.detail,
                  isSelected: isSelected,
                  onTap: () {
                    setState(() {
                      _selectedResidenceIndex = isSelected ? null : index;
                    });
                    if (!isSelected) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => CallDetailScreen(
                            residenceId: stats.residenceId,
                            era: stats.era,
                            location: stats.location,
                            detail: stats.detail,
                            receiverId: receiver.receiverId,
                          ),
                        ),
                      );
                    }
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResidenceCard({
    required String era,
    required String location,
    required String detail,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primaryLight.withValues(alpha: 0.3)
              : AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.transparent,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primary
                    : AppColors.secondary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                era,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? Colors.white : AppColors.secondary,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    location,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? AppColors.primaryDark
                          : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    detail,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: isSelected ? AppColors.primary : AppColors.textHint,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // 하단: 통화 관련 아이콘들
  // ============================================================
  Widget _buildControlSection() {
    final isInCall = _session.status == CallSessionState.onCall;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildControlButton(
            icon: _session.isMuted ? Icons.mic_off : Icons.mic,
            label: _session.isMuted ? '음소거 해제' : '음소거',
            isActive: _session.isMuted,
            enabled: isInCall,
            onPressed: _toggleMute,
          ),
          _buildControlButton(
            icon: _session.isSpeaker ? Icons.volume_up : Icons.volume_down,
            label: '스피커',
            isActive: _session.isSpeaker,
            enabled: isInCall,
            onPressed: _toggleSpeaker,
          ),
          _buildEndCallButton(),
          _buildControlButton(
            icon: Icons.edit_note,
            label: '메모',
            onPressed: _showMemoBottomSheet,
          ),
        ],
      ),
    );
  }

  Widget _buildPipButton() {
    return IconButton(
      onPressed: () => Navigator.pop(context),
      icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
      tooltip: '뒤로가기',
    );
  }

  Widget _buildStatusCard() {
    final statusText = switch (_session.status) {
      CallSessionState.connecting => '연결 중',
      CallSessionState.onCall => '통화 중',
      CallSessionState.ended => '종료됨',
    };
    final statusColor = _getStatusColor();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: statusColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            statusText,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
          if (_session.status == CallSessionState.onCall) ...[
            const SizedBox(width: 8),
            Text(
              _formattedDuration,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    bool isActive = false,
    bool enabled = true,
    Color? activeColor,
  }) {
    final effectiveActiveColor = activeColor ?? AppColors.accent;
    final opacity = enabled ? 1.0 : 0.4;

    return GestureDetector(
      onTap: enabled ? onPressed : null,
      child: Opacity(
        opacity: opacity,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isActive
                    ? effectiveActiveColor
                    : Colors.white.withValues(alpha: 0.15),
              ),
              child: Icon(
                icon,
                color: isActive ? Colors.white : Colors.white70,
                size: 24,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: Colors.white.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEndCallButton() {
    final isEnded = _session.status == CallSessionState.ended;
    final isConnecting = _session.status == CallSessionState.connecting;

    return GestureDetector(
      onTap: () {
        if (_callActionLocked) return;
        if (isConnecting) {
          _endCall();
          return;
        }
        if (isEnded) {
          _startCallWithContext();
        } else {
          _endCall();
        }
      },
      child: Opacity(
        opacity: 1.0,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isEnded ? AppColors.primary : Colors.red,
                boxShadow: [
                  BoxShadow(
                    color: (isEnded ? AppColors.primary : Colors.red)
                        .withValues(alpha: 0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: isConnecting
                  ? const Icon(Icons.close, color: Colors.white, size: 28)
                  : Icon(
                      isEnded ? Icons.phone : Icons.call_end,
                      color: Colors.white,
                      size: 28,
                    ),
            ),
            const SizedBox(height: 6),
            Text(
              isConnecting ? '취소' : (isEnded ? '통화 시작' : '종료'),
              style: TextStyle(
                fontSize: 11,
                color: Colors.white.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showMemoBottomSheet() async {
    final callId = _session.currentCallId ?? _activeCallId ?? widget.callId;
    if (callId == null || callId.isEmpty) {
      _showErrorSnackBar('통화 정보를 찾을 수 없어 메모를 저장할 수 없습니다');
      return;
    }
    await _session.ensureMemoDraftLoaded(callId: callId);

    if (!mounted) return;
    final memo = await showMemoBottomSheet(
      context,
      initialText: _session.memoDraft,
    );
    _session.updateMemoDraft(memo);
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('메모가 임시 저장되었습니다')));
  }

  Color _getStatusColor() {
    switch (_session.status) {
      case CallSessionState.connecting:
        return AppColors.connecting;
      case CallSessionState.onCall:
        return AppColors.onCall;
      case CallSessionState.ended:
        return AppColors.ended;
    }
  }
}

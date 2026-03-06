import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../services/call_service.dart';
import '../../viewmodels/call_detail_viewmodel.dart';
import '../../viewmodels/call_session_viewmodel.dart';
import '../../theme/app_colors.dart';
import '../../utils/time_utils.dart';
import '../../widgets/call_status_indicator.dart';
import '../../widgets/memo_bottom_sheet.dart';

class CallDetailScreen extends StatefulWidget {
  final String residenceId;
  final String era;
  final String location;
  final String detail;
  final String receiverId;
  final String topicType;
  final String topicId;
  final List<InterviewGuideStep> interviewGuide;
  final List<String> exampleQuestions;

  const CallDetailScreen({
    super.key,
    required this.residenceId,
    required this.era,
    required this.location,
    required this.detail,
    required this.receiverId,
    this.topicType = 'residence',
    this.topicId = '',
    this.interviewGuide = const [],
    this.exampleQuestions = const [],
  });

  factory CallDetailScreen.forMeaning({
    Key? key,
    required String receiverId,
    required MeaningStats meaning,
  }) {
    return CallDetailScreen(
      key: key,
      residenceId: '',
      era: '질문 ${meaning.order}',
      location: meaning.title,
      detail: meaning.question,
      receiverId: receiverId,
      topicType: 'meaning',
      topicId: meaning.meaningId,
      interviewGuide: meaning.interviewGuide,
      exampleQuestions: meaning.exampleQuestions,
    );
  }

  @override
  State<CallDetailScreen> createState() => _CallDetailScreenState();
}

class _CallDetailScreenState extends State<CallDetailScreen>
    with TickerProviderStateMixin {
  static const List<_SessionGuideStep> _sessionGuideSteps = [
    _SessionGuideStep(
      title: '[Step 1.] 🗝️ Memory (기억 열기)',
      examples: [
        '"1940년대에 함경북도 청진에서 사셨다고 들었는데, 그곳에서 가장 먼저 떠오르는 장면이 있으세요?"',
      ],
    ),
    _SessionGuideStep(
      title: '[Step 2.] 🔍 Moment (장면 몰입)',
      examples: [
        '"그 순간에 특히 또렷하게 떠오르는 부분이 있으세요?"',
        '"그 순간의 감정, 소리, 냄새는 어땠나요?"',
      ],
    ),
    _SessionGuideStep(
      title: '[Step 3.] ✨ Meaning (의미 발견)',
      examples: [
        '"지금 돌아보니 그 일은 어떤 의미인가요?"',
        '"가족들이 꼭 기억해줬으면 하는 점이 있다면 무엇일까요?"',
      ],
      isOptional: true,
    ),
  ];

  final CallDetailViewModel _viewModel = CallDetailViewModel();
  final CallSessionViewModel _session = CallSessionViewModel.instance;
  final PageController _carouselController = PageController(
    viewportFraction: 0.85,
  );
  late final VoidCallback _onSessionChanged;
  final Map<String, String> _summaryByCallId = {};

  @override
  void initState() {
    super.initState();
    _onSessionChanged = () {
      if (mounted) setState(() {});
    };
    _session.addListener(_onSessionChanged);
    _viewModel.init(
      receiverId: widget.receiverId,
      topicType: widget.topicType,
      topicId: widget.topicType == 'meaning' ? widget.topicId : widget.residenceId,
      onChanged: () {
        if (mounted) setState(() {});
      },
    );
  }

  @override
  void dispose() {
    _session.removeListener(_onSessionChanged);
    _carouselController.dispose();
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.secondary,
        foregroundColor: Colors.white,
        title: Text(
          widget.location,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              widget.era,
              style: const TextStyle(fontSize: 12, color: Colors.white70),
            ),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _buildSessionGuideCard(),
                    _buildPreviousCallsSection(_viewModel.previousCalls),
                  ],
                ),
              ),
            ),
            _buildCallStatusBar(),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // 세션 가이드
  // ============================================================
  Widget _buildSessionGuideCard() {
    final sessionGuideSteps = widget.topicType == 'meaning'
        ? _buildMeaningGuideSteps()
        : _sessionGuideSteps;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.surfaceVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Session Guide: 3M Question',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          ...sessionGuideSteps.map(_buildSessionGuideStep),
        ],
      ),
    );
  }

  List<_SessionGuideStep> _buildMeaningGuideSteps() {
    final guide = widget.interviewGuide;
    if (guide.isNotEmpty) {
      return guide
          .map(
            (step) => _SessionGuideStep(
              title:
                  '[Step ${step.step}] ${step.label.isNotEmpty ? step.label : step.key}',
              examples: step.prompts,
            ),
          )
          .toList();
    }

    if (widget.exampleQuestions.isNotEmpty) {
      return [
        _SessionGuideStep(
          title: '[Step 1] Memory',
          examples: widget.exampleQuestions,
        ),
      ];
    }

    return _sessionGuideSteps;
  }

  Widget _buildSessionGuideStep(_SessionGuideStep step) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  step.title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              if (step.isOptional)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    '생략 가능',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          ...step.examples.map(
            (example) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                '예) $example',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  height: 1.45,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // 하단 통화 상태창
  // ============================================================
  Widget _buildCallStatusBar() {
    final isOnCall = _session.status == CallSessionState.onCall;
    final canControlAudio =
        _session.status == CallSessionState.connecting ||
        _session.status == CallSessionState.onCall;
    final isEnded = _session.status == CallSessionState.ended;
    final isConnecting = _session.status == CallSessionState.connecting;
    final statusText = switch (_session.status) {
      CallSessionState.connecting => '연결 중',
      CallSessionState.onCall => '통화 중',
      CallSessionState.ended => '종료됨',
    };
    final statusColor = switch (_session.status) {
      CallSessionState.connecting => AppColors.connecting,
      CallSessionState.onCall => AppColors.onCall,
      CallSessionState.ended => AppColors.ended,
    };
    final receiverName = _viewModel.receiverName;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      decoration: BoxDecoration(
        color: AppColors.secondary,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 통화 상태
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: statusColor,
                    boxShadow: [
                      BoxShadow(
                        color: statusColor.withValues(alpha: 0.5),
                        blurRadius: 6,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  statusText,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                if (isOnCall) ...[
                  const SizedBox(width: 12),
                  Text(
                    _session.formattedDuration,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w300,
                      color: Colors.white70,
                      letterSpacing: 2,
                    ),
                  ),
                ],
                const Spacer(),
                if (receiverName.isNotEmpty) ...[
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: statusColor, width: 2),
                      color: Colors.white.withValues(alpha: 0.15),
                    ),
                    child: Center(
                      child: Text(
                        receiverName.characters.first,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    receiverName,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 14),
            // 통화 컨트롤
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildMiniControlButton(
                  icon: _session.isMuted ? Icons.mic_off : Icons.mic,
                  isActive: _session.isMuted,
                  enabled: canControlAudio,
                  onPressed: _session.toggleMute,
                ),
                _buildMiniControlButton(
                  icon: _session.isSpeaker
                      ? Icons.volume_up
                      : Icons.volume_down,
                  isActive: _session.isSpeaker,
                  enabled: canControlAudio,
                  onPressed: _session.toggleSpeaker,
                ),
                // 통화 종료 버튼
                Opacity(
                  opacity: isEnded ? 0.4 : 1.0,
                  child: GestureDetector(
                    onTap: isEnded
                        ? null
                        : () async {
                            await _session.endCall();
                            if (mounted) Navigator.pop(context);
                          },
                    child: Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isEnded ? AppColors.primary : Colors.red,
                        boxShadow: [
                          BoxShadow(
                            color: (isEnded ? AppColors.primary : Colors.red)
                                .withValues(alpha: 0.4),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(
                        isConnecting
                            ? Icons.close
                            : (isEnded ? Icons.phone : Icons.call_end),
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                ),
                _buildMiniControlButton(
                  icon: Icons.edit_note,
                  onPressed: _showMemoBottomSheet,
                ),
                _buildMiniControlButton(
                  icon: Icons.arrow_back,
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniControlButton({
    required IconData icon,
    required VoidCallback onPressed,
    bool isActive = false,
    bool enabled = true,
  }) {
    return GestureDetector(
      onTap: enabled ? onPressed : null,
      child: Opacity(
        opacity: enabled ? 1.0 : 0.4,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive
                ? AppColors.accent
                : Colors.white.withValues(alpha: 0.15),
          ),
          child: Icon(
            icon,
            color: isActive ? Colors.white : Colors.white70,
            size: 20,
          ),
        ),
      ),
    );
  }

  Future<void> _showMemoBottomSheet() async {
    final callId = _session.currentCallId;
    if (callId == null || callId.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('통화 정보를 찾을 수 없어 메모를 작성할 수 없습니다')),
      );
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

  // ============================================================
  // 이전 통화요약 섹션
  // ============================================================
  Widget _buildPreviousCallsSection(List<Call> previousCalls) {
    if (previousCalls.isEmpty) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, 24),
        child: Center(
          child: Text(
            '이 주제의 이전 통화 기록이 아직 없습니다',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 섹션 헤더
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: Row(
            children: [
              const Icon(Icons.history, color: AppColors.accent, size: 22),
              const SizedBox(width: 8),
              const Text(
                '이전 통화 요약',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              Text(
                '${previousCalls.length}건',
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        // Carousel
        SizedBox(
          height: 320,
          child: PageView.builder(
            controller: _carouselController,
            itemCount: previousCalls.length,
            itemBuilder: (context, index) {
              return _buildSummaryCard(previousCalls[index], index);
            },
          ),
        ),
        // 페이지 인디케이터
        _buildPageIndicator(previousCalls.length),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildSummaryCard(Call call, int index) {
    final summaryText = _summaryByCallId[call.callId] ?? _resolveSummaryText(call);
    final caregiverName = call.giverNameSnapshot.isNotEmpty
        ? call.giverNameSnapshot
        : '알 수 없음';
    final caregiverInitial = caregiverName.isNotEmpty ? caregiverName[0] : '?';
    final dateText = _formatDate(call.startedAt);
    final durationText = _formatDuration(call.durationSec);

    return AnimatedBuilder(
      animation: _carouselController,
      builder: (context, child) {
        double value = 1.0;
        if (_carouselController.position.haveDimensions) {
          value = _carouselController.page! - index;
          value = (1 - (value.abs() * 0.15)).clamp(0.85, 1.0);
        }
        return Transform.scale(scale: value, child: child);
      },
      child: GestureDetector(
        onTap: () => _showSummaryPopupForCall(call),
        child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 인터뷰어 정보 & 날짜
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [AppColors.accentLight, AppColors.accent],
                            ),
                          ),
                          child: Center(
                            child: Text(
                              caregiverInitial,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                caregiverName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              Text(
                                '$dateText · $durationText',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // 구분선
                    Container(height: 1, color: AppColors.surfaceVariant),
                    const SizedBox(height: 16),
                    // 통화 요약
                    Text(
                      summaryText,
                      maxLines: 6,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        color: AppColors.textPrimary,
                        height: 1.6,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
      ),
    );
  }

  String _resolveSummaryText(Call call) {
    if (call.humanSummary.trim().isNotEmpty) return call.humanSummary.trim();
    if (call.humanNotes.trim().isNotEmpty) return call.humanNotes.trim();
    return '';
  }

  String _resolveSummaryTextFromDoc(Map<String, dynamic>? data) {
    if (data == null) return '';
    final summary = (data['humanSummary'] ?? '').toString().trim();
    if (summary.isNotEmpty) return summary;
    final notes =
        (data['humanNotes'] ?? data['hhumanNotes'] ?? '').toString().trim();
    if (notes.isNotEmpty) return notes;
    return '';
  }

  Future<String> _fetchSummaryFromCallDoc(Call call) async {
    if (call.callId.isEmpty) return '';
    if (_summaryByCallId.containsKey(call.callId)) {
      return _summaryByCallId[call.callId] ?? '';
    }
    try {
      final data = await CallService.instance.getCallDoc(call.callId);
      final nextText = _resolveSummaryTextFromDoc(data);
      _summaryByCallId[call.callId] = nextText;
      return nextText;
    } catch (_) {
      return '';
    }
  }

  Future<void> _showSummaryPopupForCall(Call call) async {
    final caregiverName = call.giverNameSnapshot.isNotEmpty
        ? call.giverNameSnapshot
        : '알 수 없음';
    final dateText = _formatDate(call.startedAt);
    final durationText = _formatDuration(call.durationSec);
    var summaryText = _summaryByCallId[call.callId];
    if (summaryText == null) {
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );
      summaryText = await _fetchSummaryFromCallDoc(call);
      if (!mounted) return;
      Navigator.of(context).pop();
      setState(() {});
    }
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(caregiverName),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$dateText${durationText.isNotEmpty ? ' · $durationText' : ''}',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 12),
              Text(summaryText ?? ''),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('닫기'),
          ),
        ],
      ),
    );
  }

  Widget _buildPageIndicator(int count) {
    return AnimatedBuilder(
      animation: _carouselController,
      builder: (context, child) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(count, (index) {
            double currentPage = 0;
            if (_carouselController.position.haveDimensions) {
              currentPage = _carouselController.page ?? 0;
            }
            final isActive = (currentPage.round() == index);
            return AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: isActive ? 24 : 8,
              height: 8,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                color: isActive
                    ? AppColors.accent
                    : AppColors.textHint.withValues(alpha: 0.3),
              ),
            );
          }),
        );
      },
    );
  }

  String _formatDuration(int? seconds) {
    if (seconds == null) return '';
    final duration = Duration(seconds: seconds);
    final totalMinutes = duration.inMinutes;
    if (totalMinutes < 60) {
      return '$totalMinutes분';
    }
    final hours = duration.inHours;
    final minutes = totalMinutes % 60;
    if (minutes == 0) {
      return '$hours시간';
    }
    return '$hours시간 $minutes분';
  }

  String _formatDate(DateTime dateTime) {
    final et = TimeUtils.toEt(dateTime);
    return '${et.year}.${et.month.toString().padLeft(2, '0')}.${et.day.toString().padLeft(2, '0')}';
  }
}

class _SessionGuideStep {
  final String title;
  final List<String> examples;
  final bool isOptional;

  const _SessionGuideStep({
    required this.title,
    required this.examples,
    this.isOptional = false,
  });
}

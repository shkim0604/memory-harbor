import 'package:flutter/material.dart';
import '../../models/models.dart';
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

  const CallDetailScreen({
    super.key,
    required this.residenceId,
    required this.era,
    required this.location,
    required this.detail,
    required this.receiverId,
  });

  @override
  State<CallDetailScreen> createState() => _CallDetailScreenState();
}

class _CallDetailScreenState extends State<CallDetailScreen>
    with TickerProviderStateMixin {
  final CallDetailViewModel _viewModel = CallDetailViewModel();
  final CallSessionViewModel _session = CallSessionViewModel.instance;
  final PageController _carouselController = PageController(
    viewportFraction: 0.85,
  );
  late AnimationController _keywordAnimController;
  late final VoidCallback _onSessionChanged;

  // 현재 통화 키워드
  List<String> _currentKeywords = [];

  @override
  void initState() {
    super.initState();
    _keywordAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _onSessionChanged = () {
      if (mounted) setState(() {});
    };
    _session.addListener(_onSessionChanged);
    // 빈 상태로 시작 - 사용자가 수동으로 추가
    _currentKeywords = [];
    _viewModel.init(
      receiverId: widget.receiverId,
      residenceId: widget.residenceId,
      onChanged: () {
        if (mounted) setState(() {});
      },
    );
  }

  @override
  void dispose() {
    _session.removeListener(_onSessionChanged);
    _carouselController.dispose();
    _keywordAnimController.dispose();
    _viewModel.dispose();
    super.dispose();
  }

  void _showAddKeywordSheet(List<String> allKeywords) {
    final availableKeywords = allKeywords
        .where((k) => !_currentKeywords.contains(k))
        .toList();
    final customController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '키워드 추가',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                '추천 키워드',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 12),
              // 추천 키워드 목록
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: availableKeywords.map((keyword) {
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _currentKeywords.add(keyword);
                      });
                      Navigator.pop(context);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceVariant,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        '#$keyword',
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
              const Text(
                '직접 입력',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: customController,
                      decoration: InputDecoration(
                        hintText: '새 키워드 입력...',
                        hintStyle: TextStyle(color: AppColors.textHint),
                        filled: true,
                        fillColor: AppColors.surfaceVariant,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () {
                      final text = customController.text.trim();
                      if (text.isNotEmpty && !_currentKeywords.contains(text)) {
                        setState(() {
                          _currentKeywords.add(text);
                        });
                        Navigator.pop(context);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('추가'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
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
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
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
      body: Column(
        children: [
          _buildKeywordsCard(_viewModel.keywords),
          Expanded(child: _buildPreviousCallsSection(_viewModel.previousCalls)),
          _buildCallStatusBar(),
        ],
      ),
    );
  }

  // ============================================================
  // 하단 통화 상태창
  // ============================================================
  Widget _buildCallStatusBar() {
    final isOnCall = _session.status == CallSessionState.onCall;
    final isEnded = _session.status == CallSessionState.ended;
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
                  onPressed: _session.toggleMute,
                ),
                _buildMiniControlButton(
                  icon: _session.isSpeaker
                      ? Icons.volume_up
                      : Icons.volume_down,
                  isActive: _session.isSpeaker,
                  onPressed: _session.toggleSpeaker,
                ),
                // 통화 종료 버튼
                GestureDetector(
                  onTap: () async {
                    if (!isEnded) {
                      await _session.endCall();
                    }
                    if (mounted) Navigator.pop(context);
                  },
                  child: Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.red,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.red.withValues(alpha: 0.4),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.call_end,
                      color: Colors.white,
                      size: 24,
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
  }) {
    return GestureDetector(
      onTap: onPressed,
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
    );
  }

  void _showMemoBottomSheet() {
    showMemoBottomSheet(context);
  }

  // ============================================================
  // 키워드 카드
  // ============================================================
  Widget _buildKeywordsCard(List<String> allKeywords) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary.withValues(alpha: 0.1),
            AppColors.primaryLight.withValues(alpha: 0.15),
            Colors.white,
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 헤더
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.auto_awesome,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '현재 통화 키워드',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      '${widget.location} 관련 대화 주제',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              // 키워드 추가 버튼
              GestureDetector(
                onTap: () => _showAddKeywordSheet(allKeywords),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.3),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add, color: Colors.white, size: 16),
                      SizedBox(width: 4),
                      Text(
                        '키워드 추가',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // 키워드 칩들
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _currentKeywords
                  .asMap()
                  .entries
                  .map((entry) => _buildKeywordChip(entry.value, entry.key))
                  .toList(),
            ),
          ),
          if (_currentKeywords.isEmpty) ...[
            const SizedBox(height: 12),
            Text(
              '+ 버튼을 눌러 대화 주제를 추가하세요',
              style: TextStyle(fontSize: 12, color: AppColors.textHint),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildKeywordChip(String keyword, int index) {
    final colors = [
      AppColors.primary,
      AppColors.secondary,
      AppColors.accent,
      AppColors.primaryDark,
      AppColors.secondaryLight,
    ];
    final color = colors[index % colors.length];

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 300 + (index * 50)),
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          child: Opacity(opacity: value, child: child),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.15),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          '#$keyword',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ),
    );
  }

  // ============================================================
  // 이전 통화요약 섹션
  // ============================================================
  Widget _buildPreviousCallsSection(List<Call> previousCalls) {
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
        Expanded(
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
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildSummaryCard(Call call, int index) {
    final summaryText = call.humanSummary.isNotEmpty
        ? call.humanSummary
        : call.humanNotes;
    final keywordsText = call.humanKeywords.isNotEmpty
        ? call.humanKeywords.join(', ')
        : '';
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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        caregiverName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        '$dateText · $durationText',
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
            Expanded(
              child: SingleChildScrollView(
                child: Text(
                  summaryText,
                  style: const TextStyle(
                    fontSize: 15,
                    color: AppColors.textPrimary,
                    height: 1.6,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            // 키워드
            if (keywordsText.isNotEmpty)
              Row(
                children: [
                  const Icon(Icons.tag, size: 14, color: AppColors.textHint),
                  const SizedBox(width: 4),
                  Text(
                    keywordsText,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
          ],
        ),
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
      return '${totalMinutes}분';
    }
    final hours = duration.inHours;
    final minutes = totalMinutes % 60;
    if (minutes == 0) {
      return '${hours}시간';
    }
    return '${hours}시간 ${minutes}분';
  }

  String _formatDate(DateTime dateTime) {
    final et = TimeUtils.toEt(dateTime);
    return '${et.year}.${et.month.toString().padLeft(2, '0')}.${et.day.toString().padLeft(2, '0')}';
  }
}

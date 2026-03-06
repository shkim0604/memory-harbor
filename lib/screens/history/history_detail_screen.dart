import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../models/models.dart';
import '../../services/call_service.dart';
import '../../viewmodels/history_detail_viewmodel.dart';
import '../../utils/time_utils.dart';

class HistoryDetailScreen extends StatefulWidget {
  final String residenceId;
  final String era;
  final String location;
  final String detail;
  final Color color;
  final String receiverId;
  final ResidenceStats? residenceStats;
  final MeaningStats? meaningStats;

  const HistoryDetailScreen({
    super.key,
    required this.residenceId,
    required this.era,
    required this.location,
    required this.detail,
    required this.color,
    required this.receiverId,
    this.residenceStats,
    this.meaningStats,
  });

  @override
  State<HistoryDetailScreen> createState() => _HistoryDetailScreenState();
}

class _HistoryDetailScreenState extends State<HistoryDetailScreen> {
  final HistoryDetailViewModel _viewModel = HistoryDetailViewModel();
  final Map<String, String> _summaryByCallId = {};
  Color get color => widget.color;
  String get era => widget.era;
  String get location => widget.location;
  String get detail => widget.detail;
  String get residenceId => widget.residenceId;
  String get receiverId => widget.receiverId;
  ResidenceStats? get residenceStats => widget.residenceStats;
  MeaningStats? get meaningStats => widget.meaningStats;
  bool get isMeaningTopic => meaningStats != null;

  @override
  void initState() {
    super.initState();
    _viewModel.init(
      receiverId: widget.receiverId,
      topicId: widget.residenceId,
      topicType: isMeaningTopic
          ? HistoryDetailTopicType.meaning
          : HistoryDetailTopicType.residence,
      onChanged: () {
        if (mounted) setState(() {});
      },
    );
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    final bulletStories = isMeaningTopic
        ? (meaningStats?.humanComments ?? const [])
        : (residenceStats?.humanComments ?? const []);
    final screenHeight = MediaQuery.of(context).size.height;
    const headerColor = AppColors.primary;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          // AppBar
          SliverAppBar(
            expandedHeight: 120,
            floating: false,
            pinned: true,
            backgroundColor: headerColor,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                location,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [headerColor, AppColors.primaryDark],
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(60, 50, 20, 50),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          era,
                          style: const TextStyle(
                            fontSize: 15,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        detail,
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // 콘텐츠
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // (1) 불릿 스토리 섹션
                  _buildBulletStoriesSection(
                    bulletStories,
                    screenHeight: screenHeight,
                  ),
                  const SizedBox(height: 18),

                  // (2) 통화 내역 섹션
                  _buildCallHistorySection(screenHeight: screenHeight),
                  const SizedBox(height: 4),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBulletStoriesSection(
    List<String> stories, {
    required double screenHeight,
  }) {
    final storyMinHeight = (screenHeight * 0.30).clamp(220.0, 360.0);
    final storyMaxHeight = (screenHeight * 0.56).clamp(360.0, 700.0);
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                '추억 스토리',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              Text(
                '통화 내용 기반',
                style: TextStyle(fontSize: 15, color: AppColors.textHint),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: storyMinHeight,
              maxHeight: storyMaxHeight,
            ),
            child: Scrollbar(
              thumbVisibility: stories.length > 3,
              child: SingleChildScrollView(
                child: stories.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Text(
                          '아직 정리된 추억 스토리가 없습니다.',
                          style: TextStyle(
                            fontSize: 18,
                            color: AppColors.textSecondary,
                            height: 1.5,
                          ),
                        ),
                      )
                    : Column(
                        children: stories.map((story) => _buildStoryItem(story)).toList(),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStoryItem(String story) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 6),
            width: 8,
            height: 8,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  story,
                  style: const TextStyle(
                    fontSize: 18,
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCallHistorySection({required double screenHeight}) {
    final calls = _viewModel.filteredCalls;
    final cardHeight = (screenHeight * 0.17).clamp(112.0, 156.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '통화 내역: ${calls.length}건',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const Spacer(),
          ],
        ),
        const SizedBox(height: 8),
        if (calls.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 6),
            child: Text(
              '통화 내역이 없습니다.',
              style: TextStyle(fontSize: 16, color: AppColors.textHint),
            ),
          )
        else
          SizedBox(
            height: cardHeight,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: calls.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                return SizedBox(
                  width: 286,
                  child: _buildCallHistoryCard(calls[index]),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildCallHistoryCard(Call call) {
    final summary =
        call.humanSummary.isNotEmpty ? call.humanSummary : call.humanNotes;

    return GestureDetector(
      onTap: () => _showSummaryPopupForCall(call),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          call.giverNameSnapshot,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    summary,
                    style: const TextStyle(
                      fontSize: 17,
                      color: AppColors.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _formatDate(call.startedAt),
                  style: const TextStyle(fontSize: 15, color: AppColors.textHint),
                ),
                const SizedBox(height: 2),
                Text(
                  _formatDuration(call.durationSec),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
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
                  fontSize: 14,
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

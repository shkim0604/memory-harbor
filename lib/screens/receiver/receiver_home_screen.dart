import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../theme/app_colors.dart';
import '../../viewmodels/receiver_home_viewmodel.dart';
import '../../utils/time_utils.dart';
import 'receiver_call_history_screen.dart';

class ReceiverHomeScreen extends StatefulWidget {
  const ReceiverHomeScreen({super.key});

  @override
  State<ReceiverHomeScreen> createState() => _ReceiverHomeScreenState();
}

class _ReceiverHomeScreenState extends State<ReceiverHomeScreen> {
  final ReceiverHomeViewModel _viewModel = ReceiverHomeViewModel();

  @override
  void initState() {
    super.initState();
    _viewModel.init(onChanged: () {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_viewModel.status == ReceiverHomeStatus.unauthenticated) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: Text('로그인이 필요합니다')),
      );
    }

    if (_viewModel.status == ReceiverHomeStatus.loadingGroup) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_viewModel.status == ReceiverHomeStatus.noGroup) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: Text('아직 그룹에 속해 있지 않습니다')),
      );
    }

    final group = _viewModel.group;
    if (group == null) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: Text('정보를 불러오는 중...')),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(child: _buildBody(group, _viewModel.calls)),
    );
  }

  Widget _buildBody(Group group, List<Call> calls) {
    return Column(
      children: [
        _buildHeader(group),
        const SizedBox(height: 12),
        Expanded(child: _buildCallList(calls)),
      ],
    );
  }

  Widget _buildHeader(Group group) {
    final memberCount = group.careGiverUserIds.length + 1;
    final totalCalls = _viewModel.totalCompletedCalls;
    final thisWeek = _viewModel.thisWeekCalls;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            group.name,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: AppColors.secondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '공동체 멤버 ${memberCount}명',
            style: TextStyle(
              fontSize: 18,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  title: '총 통화',
                  value: '${totalCalls}회',
                  subtitle: '전체 누적',
                  accent: AppColors.secondary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  title: '이번주',
                  value: '${thisWeek}회',
                  subtitle: '최근 7일',
                  accent: AppColors.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required String subtitle,
    required Color accent,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: accent,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 16,
              color: AppColors.textHint,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCallList(List<Call> calls) {
    if (calls.isEmpty) {
      return Center(
        child: Text(
          '아직 통화 기록이 없습니다',
          style: TextStyle(color: AppColors.textHint, fontSize: 18),
        ),
      );
    }
    final maxVisible = _maxVisibleCount(context);
    final visibleCalls = _viewModel.visibleCalls(maxVisible);
    final hasMore = _viewModel.hasMoreCalls(maxVisible);

    return Column(
      children: [
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            itemCount: visibleCalls.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final call = visibleCalls[index];
              return _buildCallCard(call);
            },
          ),
        ),
        if (hasMore)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _openAllCalls(context, calls),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.secondary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  '전체보기',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),
      ],
    );
  }

  int _maxVisibleCount(BuildContext context) {
    final height = MediaQuery.of(context).size.height;
    if (height < 700) return 2;
    if (height < 820) return 3;
    return 4;
  }

  void _openAllCalls(BuildContext context, List<Call> calls) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReceiverCallHistoryScreen(calls: calls),
      ),
    );
  }

  Widget _buildCallCard(Call call) {
    final dateText = _formatDate(call.startedAt);
    final durationText = _formatDuration(call.durationSec);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primaryLight.withValues(alpha: 0.35),
            ),
            child: const Icon(Icons.call, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  call.giverNameSnapshot.isNotEmpty
                      ? call.giverNameSnapshot
                      : '통화 상대',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  dateText,
                  style: TextStyle(
                    fontSize: 16,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Text(
            durationText,
            style: TextStyle(
              fontSize: 16,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final et = TimeUtils.toEt(date);
    final year = et.year.toString();
    final month = et.month.toString().padLeft(2, '0');
    final day = et.day.toString().padLeft(2, '0');
    final hour = et.hour.toString().padLeft(2, '0');
    final minute = et.minute.toString().padLeft(2, '0');
    return '$year.$month.$day $hour:$minute';
  }

  String _formatDuration(int? seconds) {
    if (seconds == null || seconds <= 0) return '0분';
    final minutes = seconds ~/ 60;
    final remain = seconds % 60;
    if (minutes <= 0) return '${remain}초';
    return remain == 0 ? '${minutes}분' : '${minutes}분 ${remain}초';
  }
}

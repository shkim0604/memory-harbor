import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../theme/app_colors.dart';
import '../../models/models.dart';
import '../../utils/call_format_utils.dart';
import '../../viewmodels/home_viewmodel.dart';
import '../../widgets/widgets.dart';
import '../reviews/review_write_screen.dart';

// Firebase 에서 불러오는 데이터
// - 사용자 정보
// - 그룹 정보 : User에 있는 groupIds를 기반으로 그룹 정보를 불러옴. 없으면 "그룹이 없습니다" 안내
// - 나레이터 정보 : 그룹 정보에 있는 receiverId를 기반으로 나레이터 정보를 불러옴
// - 통화기록 : 그룹 정보에 있는 groupId를 기반으로 통화기록을 불러옴

class HomeScreen extends StatefulWidget {
  final VoidCallback? onCallPressed;

  const HomeScreen({super.key, this.onCallPressed});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final HomeViewModel _viewModel = HomeViewModel();

  @override
  void initState() {
    super.initState();
    _viewModel.init(
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
    if (_viewModel.status == HomeStatus.unauthenticated) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: Text('로그인이 필요합니다')),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(child: _buildBody(context)),
    );
  }

  Widget _buildBody(BuildContext context) {
    switch (_viewModel.status) {
      case HomeStatus.loadingUser:
        return _buildScaffoldWithSlivers([
          _buildMessageSliver('사용자 정보를 불러오는 중...'),
        ]);
      case HomeStatus.noGroup:
        return _buildScaffoldWithSlivers([
          _buildEmptyStateSliver(
            title: '아직 그룹에 속해 있지 않습니다',
            subtitle: '관리자에게 연락해주세요.',
            email: 'd.house0827@gmail.com',
            icon: Icons.group_off_outlined,
          ),
        ]);
      case HomeStatus.loadingGroup:
        return _buildScaffoldWithSlivers([
          _buildMessageSliver('그룹 정보를 불러오는 중...'),
        ]);
      case HomeStatus.loadingReceiver:
        return _buildScaffoldWithSlivers([
          _buildMessageSliver('나레이터 정보를 불러오는 중...'),
        ]);
      case HomeStatus.ready:
        final group = _viewModel.group;
        final receiver = _viewModel.receiver;
        if (group == null || receiver == null) {
          return _buildScaffoldWithSlivers([
            _buildMessageSliver('데이터를 불러오는 중...'),
          ]);
        }

        return _buildScaffoldWithSlivers([
          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _buildCareReceiverSection(
                  receiver,
                  _viewModel.totalCompletedCalls,
                  _viewModel.thisWeekCalls,
                  group.careGiverUserIds.length + 1, // 나레이터 포함
                ),
                const SizedBox(height: 24),
                _buildSectionHeader(
                  '공동체 통화기록',
                  onSeeAll: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => _CallHistoryListScreen(
                          title: '공동체 통화기록',
                          calls: _viewModel.sortedCommunityCalls,
                          itemBuilder: _buildCommunityCallCard,
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),
                _buildCommunityCallHistoryList(
                  _viewModel.recentCommunityCalls(2),
                ),
                const SizedBox(height: 24),
                _buildSectionHeader(
                  '나의 통화기록',
                  onSeeAll: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => _CallHistoryListScreen(
                          title: '나의 통화기록',
                          calls: _viewModel.sortedMyCalls,
                          itemBuilder: _buildMyCallCard,
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),
                _buildMyCallHistoryList(_viewModel.recentMyCalls(2)),
                const SizedBox(height: 20),
              ]),
            ),
          ),
        ]);
      case HomeStatus.unauthenticated:
        return const SizedBox.shrink();
    }
  }

  Widget _buildScaffoldWithSlivers(List<Widget> slivers) {
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          floating: true,
          backgroundColor: AppColors.background,
          elevation: 0,
          title: const Text(
            'MemHarbor',
            style: TextStyle(
              color: AppColors.secondary,
              fontWeight: FontWeight.bold,
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(
                Icons.notifications_outlined,
                color: AppColors.secondary,
              ),
              onPressed: () {},
            ),
          ],
        ),
        ...slivers,
      ],
    );
  }

  SliverToBoxAdapter _buildMessageSliver(String message) {
    return SliverToBoxAdapter(
      child: Padding(padding: const EdgeInsets.all(20), child: Text(message)),
    );
  }

  Widget _buildEmptyStateSliver({
    required String title,
    required String subtitle,
    required IconData icon,
    String? email,
  }) {
    return SliverFillRemaining(
      hasScrollBody: false,
      child: Align(
        alignment: const Alignment(0, -0.2),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 32, color: AppColors.textHint),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 16,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              if (email != null) ...[
                const SizedBox(height: 12),
                TextButton.icon(
                  onPressed: () => _launchEmail(email),
                  icon: const Icon(Icons.mail_outline),
                  label: Text(
                    email,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _launchEmail(String email) async {
    final uri = Uri(scheme: 'mailto', path: email);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  // ============================================================
  // 나레이터 정보 섹션
  // ============================================================
  Widget _buildCareReceiverSection(
    AppUser receiver,
    int totalCalls,
    int thisWeekCalls,
    int connectedPeople,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, AppColors.primaryDark],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              ProfileAvatar(
                imageUrl: receiver.profileImage.isNotEmpty
                    ? receiver.profileImage
                    : 'assets/images/logo.png',
                size: 72,
                borderColor: Colors.white,
                borderWidth: 3,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  receiver.name,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: IconButton(
                  icon: const Icon(Icons.phone, color: AppColors.primary),
                  onPressed: widget.onCallPressed,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                _buildStatItem('총 통화', '$totalCalls', '회'),
                _buildStatDivider(),
                _buildStatItem('이번 주', '$thisWeekCalls', '회'),
                _buildStatDivider(),
                _buildStatItem('그룹원 수', '$connectedPeople', '명'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, String unit) {
    return Expanded(
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 2, left: 2),
                child: Text(
                  unit,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatDivider() {
    return Container(
      width: 1,
      height: 36,
      color: Colors.white.withValues(alpha: 0.3),
    );
  }

  // ============================================================
  // 섹션 헤더
  // ============================================================
  Widget _buildSectionHeader(String title, {required VoidCallback onSeeAll}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        TextButton(
          onPressed: onSeeAll,
          style: TextButton.styleFrom(
            padding: EdgeInsets.zero,
            minimumSize: const Size(0, 0),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: const Text(
            '전체보기',
            style: TextStyle(fontSize: 14, color: AppColors.primary),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // 나의 통화기록
  // ============================================================
  Widget _buildMyCallHistoryList(List<Call> calls) {
    if (calls.isEmpty) {
      return _buildEmptyListMessage('아직 통화기록이 없습니다.');
    }
    return Column(
      children: calls
          .map(
            (call) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildMyCallCard(call),
            ),
          )
          .toList(),
    );
  }

  Widget _buildMyCallCard(Call call) {
    final isCompleted = call.endedAt != null && (call.durationSec ?? 0) > 0;
    final icon = isCompleted ? Icons.call : Icons.phone_missed;
    final name = call.receiverNameSnapshot.isNotEmpty
        ? call.receiverNameSnapshot
        : '통화 상대';
    final hasReview = call.reviewCount > 0;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primaryLight.withValues(alpha: 0.35),
                ),
                child: Icon(icon, color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      CallFormatUtils.formatDateTimeEt(call.startedAt),
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                CallFormatUtils.formatDurationHumanized(call),
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
            ],
          ),
          if (isCompleted) ...[
            const SizedBox(height: 12),
            Divider(color: AppColors.surfaceVariant.withValues(alpha: 0.9)),
            const SizedBox(height: 10),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: hasReview
                        ? AppColors.primaryLight.withValues(alpha: 0.45)
                        : AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    hasReview ? '리뷰 있음' : '리뷰 없음',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: hasReview
                          ? AppColors.primaryDark
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
                const Spacer(),
                hasReview
                    ? OutlinedButton.icon(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  ReviewWriteScreen(callId: call.callId),
                            ),
                          );
                        },
                        icon: const Icon(Icons.visibility_outlined, size: 16),
                        label: const Text('수정/보기'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primaryDark,
                          side: BorderSide(
                            color: AppColors.primary.withValues(alpha: 0.5),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          minimumSize: const Size(0, 36),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      )
                    : ElevatedButton.icon(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  ReviewWriteScreen(callId: call.callId),
                            ),
                          );
                        },
                        icon: const Icon(Icons.edit_note, size: 18),
                        label: const Text('리뷰 쓰기'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          minimumSize: const Size(0, 36),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          elevation: 0,
                        ),
                      ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ============================================================
  // 공동체 통화기록
  // ============================================================
  Widget _buildCommunityCallHistoryList(List<Call> calls) {
    if (calls.isEmpty) {
      return _buildEmptyListMessage('아직 통화기록이 없습니다.');
    }
    return Column(
      children: calls
          .map(
            (call) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildCommunityCallCard(call),
            ),
          )
          .toList(),
    );
  }

  Widget _buildCommunityCallCard(Call call) {
    final isCompleted = call.endedAt != null && (call.durationSec ?? 0) > 0;
    final icon = isCompleted ? Icons.call : Icons.phone_missed;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.surfaceVariant, width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ProfileAvatar(
            imageUrl: null,
            fallbackText: call.giverNameSnapshot,
            size: 44,
            backgroundColor: AppColors.primaryLight,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.primaryLight.withValues(alpha: 0.35),
                      ),
                      child: Icon(icon, color: AppColors.primary, size: 14),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        call.giverNameSnapshot,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceVariant,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        CallFormatUtils.formatDurationHumanized(call),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today_outlined,
                      size: 13,
                      color: AppColors.textHint.withValues(alpha: 0.9),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        CallFormatUtils.formatDateTimeEt(call.startedAt),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textSecondary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                // const SizedBox(height: 10),
                // Text(
                //   call.humanSummary.isNotEmpty ? call.humanSummary : call.humanNotes,
                //   style: const TextStyle(
                //     fontSize: 14,
                //     color: AppColors.textSecondary,
                //     height: 1.4,
                //   ),
                //   maxLines: 2,
                //   overflow: TextOverflow.ellipsis,
                // ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyListMessage(String message) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Text(
        message,
        style: const TextStyle(fontSize: 14, color: AppColors.textHint),
      ),
    );
  }
}

class _CallHistoryListScreen extends StatelessWidget {
  final String title;
  final List<Call> calls;
  final Widget Function(Call call) itemBuilder;

  const _CallHistoryListScreen({
    required this.title,
    required this.calls,
    required this.itemBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: calls.isEmpty
          ? const Center(child: Text('표시할 통화기록이 없습니다.'))
          : ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: calls.length,
              itemBuilder: (context, index) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: itemBuilder(calls[index]),
              ),
            ),
    );
  }
}

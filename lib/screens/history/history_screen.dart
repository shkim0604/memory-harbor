import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../data/mock_data.dart';
import '../../models/models.dart';
import 'history_detail_screen.dart';
import '../../viewmodels/history_viewmodel.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final HistoryViewModel _viewModel = HistoryViewModel();

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
    if (_viewModel.status == HistoryStatus.unauthenticated) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: Text('로그인이 필요합니다')),
      );
    }

    if (_viewModel.status == HistoryStatus.noGroup) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: Text('아직 그룹에 속해 있지 않습니다')),
      );
    }

    if (_viewModel.status != HistoryStatus.ready) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final receiver = _viewModel.receiver;
    final group = _viewModel.group;
    if (receiver == null || group == null) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: Text('정보를 불러오는 중...')),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: _buildHistoryBody(
        receiver,
        _viewModel.totalCompletedCalls,
        _viewModel.statsList,
      ),
    );
  }

  Widget _buildHistoryBody(
    CareReceiver receiver,
    int totalCalls,
    List<ResidenceStats> statsList,
  ) {
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          expandedHeight: 140,
          floating: false,
          pinned: true,
          backgroundColor: AppColors.secondary,
          flexibleSpace: FlexibleSpaceBar(
            title: const Text(
              '추억 히스토리',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            background: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.secondary, AppColors.secondaryLight],
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 60, 20, 50),
                child: Row(
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                        image: receiver.profileImage.isNotEmpty
                            ? DecorationImage(
                                image: receiver.profileImage.startsWith('assets/')
                                    ? AssetImage(receiver.profileImage)
                                        as ImageProvider
                                    : NetworkImage(receiver.profileImage),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      child: receiver.profileImage.isEmpty
                          ? const Icon(Icons.person, color: Colors.white)
                          : null,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            receiver.name,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '총 ${totalCalls}회 통화 · ${statsList.length}개 시대',
                            style: const TextStyle(
                              fontSize: 13,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate((context, index) {
              final stats = statsList[index];
              final residence = Residence(
                residenceId: stats.residenceId,
                era: stats.era,
                location: stats.location,
                detail: stats.detail,
              );
              return _buildResidenceCard(
                context,
                residence,
                stats,
                receiver.receiverId,
              );
            }, childCount: statsList.length),
          ),
        ),
      ],
    );
  }

  Widget _buildResidenceCard(
    BuildContext context,
    Residence residence,
    ResidenceStats? residenceStats,
    String receiverId,
  ) {
    final residenceUi = MockData.getResidenceUi(residence);
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => HistoryDetailScreen(
              residenceId: residence.residenceId,
              era: residence.era,
              location: residence.location,
              detail: residence.detail,
              color: residenceUi.color,
              receiverId: receiverId,
              residenceStats: residenceStats,
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: residenceUi.color.withValues(alpha: 0.2),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            // 상단 컬러 바
            Container(
              height: 6,
              decoration: BoxDecoration(
                color: residenceUi.color,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  // 아이콘
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: residenceUi.color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      residenceUi.icon,
                      color: residenceUi.color,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  // 정보
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: residenceUi.color.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            residence.era,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: residenceUi.color,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          residence.location,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          residence.detail,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        if ((residenceStats?.aiSummary ?? '').isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            residenceStats!.aiSummary,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                              height: 1.4,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  // 통화 횟수 & 화살표
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceVariant,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${residenceStats?.totalCalls ?? 0}회',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Icon(
                        Icons.arrow_forward_ios,
                        color: AppColors.textHint,
                        size: 16,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // 하단 정보
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant.withValues(alpha: 0.5),
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(20),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.access_time, size: 14, color: AppColors.textHint),
                  const SizedBox(width: 4),
                  Text(
                    '마지막 통화: ${residenceStats?.lastCallAt != null ? MockData.formatDate(residenceStats!.lastCallAt!) : '-'}',
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
      ),
    );
  }
}

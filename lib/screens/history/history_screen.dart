import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../models/models.dart';
import 'history_detail_screen.dart';
import '../../viewmodels/history_viewmodel.dart';
import '../../utils/time_utils.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final HistoryViewModel _viewModel = HistoryViewModel();
  _HistoryTab _selectedTab = _HistoryTab.place;

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
      appBar: AppBar(
        title: Text("${receiver.name}'s Life"),
        centerTitle: true,
      ),
      body: _buildHistoryBody(
        receiver,
        _viewModel.statsList,
        _viewModel.meaningStatsList,
      ),
    );
  }

  Widget _buildHistoryBody(
    CareReceiver receiver,
    List<ResidenceStats> statsList,
    List<MeaningStats> meaningStatsList,
  ) {
    final residenceSummaryMap = _viewModel.residenceCallSummaryMap;
    final meaningSummaryMap = _viewModel.meaningCallSummaryMap;
    final isPlaceTab = _selectedTab == _HistoryTab.place;
    final showEmpty = isPlaceTab ? statsList.isEmpty : meaningStatsList.isEmpty;

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: _buildTabSelector(),
          ),
        ),
        if (showEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Text(
                isPlaceTab ? '아직 장소 데이터가 없습니다' : '아직 의미 데이터가 없습니다',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                if (isPlaceTab) {
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
                    residenceSummaryMap[stats.residenceId],
                    receiver.receiverId,
                    index,
                    statsList.length,
                  );
                }

                final stats = meaningStatsList[index];
                return _buildMeaningCard(
                  stats,
                  meaningSummaryMap[stats.meaningId],
                  receiver.receiverId,
                  index,
                  meaningStatsList.length,
                );
              },
              childCount: isPlaceTab ? statsList.length : meaningStatsList.length,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTabSelector() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildTabButton(
              label: '장소중심',
              selected: _selectedTab == _HistoryTab.place,
              onTap: () => setState(() => _selectedTab = _HistoryTab.place),
            ),
          ),
          Expanded(
            child: _buildTabButton(
              label: '의미중심',
              selected: _selectedTab == _HistoryTab.meaning,
              onTap: () => setState(() => _selectedTab = _HistoryTab.meaning),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: selected ? AppColors.textPrimary : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildResidenceCard(
    BuildContext context,
    Residence residence,
    ResidenceStats? residenceStats,
    ResidenceCallSummary? callSummary,
    String receiverId,
    int index,
    int totalCount,
  ) {
    final residenceColor = _residenceColorByOrder(index, totalCount);
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
              color: residenceColor,
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
              color: residenceColor.withValues(alpha: 0.2),
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
                color: residenceColor,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
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
                            color: residenceColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            residence.era,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: residenceColor,
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
                          '${callSummary?.callCount ?? 0}회',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
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
                  Text(
                    '마지막 통화: ${callSummary?.lastCallAt != null ? _formatDate(callSummary!.lastCallAt!) : '-'}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const Spacer(),
                  Flexible(
                    child: Text(
                      callSummary?.lastCallerName.isNotEmpty == true
                          ? callSummary!.lastCallerName
                          : '-',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                      overflow: TextOverflow.ellipsis,
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

  Widget _buildMeaningCard(
    MeaningStats meaningStats,
    ResidenceCallSummary? callSummary,
    String receiverId,
    int index,
    int totalCount,
  ) {
    final meaningColor = _meaningColorByOrder(index, totalCount);
    final question = meaningStats.question.trim().isNotEmpty
        ? meaningStats.question.trim()
        : meaningStats.title.trim();
    final compactTitle = meaningStats.title.trim().isNotEmpty
        ? meaningStats.title.trim()
        : 'Q${meaningStats.order}';
    final callCount = callSummary?.callCount ?? meaningStats.totalCalls;
    final lastCallAt = callSummary?.lastCallAt ?? meaningStats.lastCallAt;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => HistoryDetailScreen(
              residenceId: meaningStats.meaningId,
              era: '의미',
              location: compactTitle,
              detail: '',
              color: meaningColor,
              receiverId: receiverId,
              meaningStats: meaningStats,
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
              color: meaningColor.withValues(alpha: 0.2),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              height: 6,
              decoration: BoxDecoration(
                color: meaningColor,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
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
                            color: meaningColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Q${meaningStats.order}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: meaningColor,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          question,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        if (meaningStats.aiSummary.trim().isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            meaningStats.aiSummary,
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
                          '$callCount회',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
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
                  Text(
                    '마지막 통화: ${lastCallAt != null ? _formatDate(lastCallAt) : '-'}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const Spacer(),
                  Flexible(
                    child: Text(
                      callSummary?.lastCallerName.isNotEmpty == true
                          ? callSummary!.lastCallerName
                          : '-',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                      overflow: TextOverflow.ellipsis,
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

  Color _residenceColorByOrder(int index, int totalCount) {
    if (totalCount <= 1) return AppColors.primary;
    final clamped = index.clamp(0, totalCount - 1);
    final t = clamped / (totalCount - 1);
    return Color.lerp(AppColors.primaryLight, AppColors.primaryDark, t) ??
        AppColors.primary;
  }

  Color _meaningColorByOrder(int index, int totalCount) {
    const start = Color(0xFF2E7D32);
    const end = Color(0xFF00796B);
    if (totalCount <= 1) return start;
    final clamped = index.clamp(0, totalCount - 1);
    final t = clamped / (totalCount - 1);
    return Color.lerp(start, end, t) ?? start;
  }

  String _formatDate(DateTime dateTime) {
    final et = TimeUtils.toEt(dateTime);
    return '${et.year}.${et.month.toString().padLeft(2, '0')}.${et.day.toString().padLeft(2, '0')}';
  }
}

enum _HistoryTab { place, meaning }

import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../theme/app_colors.dart';
import '../../viewmodels/community_members_viewmodel.dart';
import '../../widgets/widgets.dart';

class CommunityMembersScreen extends StatefulWidget {
  const CommunityMembersScreen({super.key});

  @override
  State<CommunityMembersScreen> createState() => _CommunityMembersScreenState();
}

class _CommunityMembersScreenState extends State<CommunityMembersScreen> {
  final CommunityMembersViewModel _viewModel = CommunityMembersViewModel();
  final PageController _othersController = PageController(viewportFraction: 0.94);
  static const String _defaultIntroMessage = '함께 이야기를 모아봐요';

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
    _othersController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_viewModel.status == CommunityMembersStatus.unauthenticated) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: Text('로그인이 필요합니다')),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: const Text(
          '공동체 구성원',
          style: TextStyle(
            color: AppColors.secondary,
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: const IconThemeData(color: AppColors.secondary),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    switch (_viewModel.status) {
      case CommunityMembersStatus.loadingUser:
      case CommunityMembersStatus.loadingGroup:
      case CommunityMembersStatus.loadingMembers:
        return const Center(child: CircularProgressIndicator());
      case CommunityMembersStatus.noGroup:
        return const Center(child: Text('아직 그룹에 속해 있지 않습니다'));
      case CommunityMembersStatus.ready:
        return _buildMemberList();
      case CommunityMembersStatus.unauthenticated:
        return const SizedBox.shrink();
    }
  }

  Widget _buildMemberList() {
    final receiver = _viewModel.receiver;
    final caregivers = _viewModel.caregivers;
    final me = _viewModel.currentUser;
    final others =
        caregivers.where((user) => me == null || user.uid != me.uid).toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        children: [
          Expanded(
            flex: 3,
            child: _buildStaticSection(
              title: '나',
              child: me == null
                  ? _buildEmptyCard('내 정보를 불러오는 중입니다.')
                  : _buildCaregiverCard(me),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            flex: 3,
            child: _buildStaticSection(
              title: 'Narrator',
              child: receiver == null
                  ? _buildEmptyCard('Narrator 정보를 불러오는 중입니다.')
                  : _buildReceiverCard(receiver),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            flex: 4,
            child: _buildCarouselSection(
              title: 'Companion ${others.length}명',
              controller: _othersController,
              items: others.isEmpty
                  ? [
                      _buildEmptyCard('등록된 Companion이 없습니다.'),
                    ]
                  : others.map(_buildCaregiverCard).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStaticSection({
    required String title,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(title),
        const SizedBox(height: 12),
        Expanded(child: child),
      ],
    );
  }

  Widget _buildCarouselSection({
    required String title,
    required PageController controller,
    required List<Widget> items,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(title),
        const SizedBox(height: 12),
        Expanded(
          child: PageView.builder(
            controller: controller,
            itemCount: items.length,
            itemBuilder: (context, index) {
              return AnimatedBuilder(
                animation: controller,
                builder: (context, child) {
                  double value = 1.0;
                  if (controller.position.haveDimensions) {
                    value = controller.page! - index;
                    value = (1 - (value.abs() * 0.12)).clamp(0.88, 1.0);
                  }
                  return Transform.scale(
                    scale: value,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: child,
                    ),
                  );
                },
                child: items[index],
              );
            },
          ),
        ),
        if (items.length > 1) ...[
          const SizedBox(height: 8),
          _buildPageIndicator(controller, items.length),
        ],
      ],
    );
  }

  Widget _buildPageIndicator(PageController controller, int count) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        double currentPage = 0;
        if (controller.position.haveDimensions) {
          currentPage = controller.page ?? 0;
        }
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(count, (index) {
            final isActive = currentPage.round() == index;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: isActive ? 18 : 8,
              height: 8,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
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

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
    );
  }

  Widget _buildReceiverCard(CareReceiver receiver) {
    return _buildMemberCard(
      name: receiver.name,
      subtitle: 'Narrator',
      imageUrl: receiver.profileImage,
      introMessage: _defaultIntroMessage,
    );
  }

  Widget _buildCaregiverCard(AppUser user) {
    return _buildMemberCard(
      name: user.name,
      subtitle: user.email.isNotEmpty ? user.email : 'Companion',
      imageUrl: user.profileImage,
      introMessage: user.introMessage.isNotEmpty
          ? user.introMessage
          : _defaultIntroMessage,
    );
  }

  Widget _buildMemberCard({
    required String name,
    required String subtitle,
    required String imageUrl,
    required String introMessage,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
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
      child: LayoutBuilder(
        builder: (context, constraints) {
          final imageSize = (constraints.maxWidth / 3).clamp(90.0, 140.0);
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              ProfileAvatar(
                imageUrl: imageUrl,
                fallbackText: name,
                size: imageSize,
                borderColor: AppColors.accentLight,
                borderWidth: 1,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      name.isNotEmpty ? name : '이름 없음',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Flexible(
                      child: Text(
                        introMessage,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary.withValues(alpha: 0.9),
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildEmptyCard(String message) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.accentLight),
      ),
      child: Text(
        message,
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 14,
        ),
      ),
    );
  }
}

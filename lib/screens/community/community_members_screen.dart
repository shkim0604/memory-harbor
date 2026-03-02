import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../theme/app_colors.dart';
import '../../viewmodels/community_members_viewmodel.dart';

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
        title: const Text('공동체 구성원'),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          _buildBackgroundDecor(),
          _buildBody(),
        ],
      ),
    );
  }

  Widget _buildBackgroundDecor() {
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            top: -80,
            right: -40,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.accent.withValues(alpha: 0.08),
              ),
            ),
          ),
          Positioned(
            bottom: -90,
            left: -50,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withValues(alpha: 0.06),
              ),
            ),
          ),
        ],
      ),
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

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Column(
        children: [
          Expanded(
            flex: 1,
            child: _buildStaticSection(
              title: 'Narrator',
              icon: Icons.auto_stories_rounded,
              child: receiver == null
                  ? _buildEmptyCard('Narrator 정보를 불러오는 중입니다.')
                  : _buildReceiverCard(receiver),
            ),
          ),
          const SizedBox(height: 14),
          Expanded(
            flex: 1,
            child: _buildCarouselSection(
              title: 'Interviewer ${caregivers.length}명',
              icon: Icons.groups_2_outlined,
              controller: _othersController,
              items: caregivers.isEmpty
                  ? [
                      _buildEmptyCard('등록된 Interviewer가 없습니다.'),
                    ]
                  : caregivers.map(_buildCaregiverCard).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStaticSection({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.accentLight.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle(title, icon: icon),
          const SizedBox(height: 10),
          Expanded(child: child),
        ],
      ),
    );
  }

  Widget _buildCarouselSection({
    required String title,
    required IconData icon,
    required PageController controller,
    required List<Widget> items,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.accentLight.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle(title, icon: icon),
          const SizedBox(height: 10),
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
      ),
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

  Widget _buildSectionTitle(String title, {required IconData icon}) {
    return Row(
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: AppColors.accentLight.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: AppColors.secondary),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildRoleChip(String subtitle) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.accentLight.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        subtitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        softWrap: false,
        style: TextStyle(
          fontSize: 12,
          color: AppColors.secondary.withValues(alpha: 0.9),
          fontWeight: FontWeight.w600,
        ),
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
      subtitle: user.email.isNotEmpty ? user.email : 'Interviewer',
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
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white,
            AppColors.surfaceVariant.withValues(alpha: 0.55),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.accentLight.withValues(alpha: 0.6)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final imageWidth = constraints.maxWidth / 3;
          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(18),
                    bottomLeft: Radius.circular(18),
                  ),
                  child: SizedBox(
                    width: imageWidth,
                    child: _buildRectProfile(
                      imageUrl: imageUrl,
                      fallbackText: name,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(0, 14, 14, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          name.isNotEmpty ? name : '이름 없음',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        LayoutBuilder(
                          builder: (context, chipConstraints) {
                            return ConstrainedBox(
                              constraints: BoxConstraints(
                                maxWidth: chipConstraints.maxWidth,
                              ),
                              child: _buildRoleChip(subtitle),
                            );
                          },
                        ),
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.75),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.format_quote_rounded,
                                size: 16,
                                color: AppColors.textHint.withValues(alpha: 0.75),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  introMessage,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: AppColors.textSecondary.withValues(
                                      alpha: 0.9,
                                    ),
                                    height: 1.35,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildRectProfile({
    required String imageUrl,
    required String fallbackText,
  }) {
    final hasImage = imageUrl.isNotEmpty;
    return Container(
      decoration: BoxDecoration(
        color: hasImage ? null : AppColors.accentLight,
        image: hasImage
            ? DecorationImage(
                image: imageUrl.startsWith('assets/')
                    ? AssetImage(imageUrl) as ImageProvider
                    : NetworkImage(imageUrl),
                fit: BoxFit.cover,
              )
            : null,
      ),
      child: hasImage
          ? null
          : Center(
              child: Text(
                fallbackText.isNotEmpty ? fallbackText[0] : '?',
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
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
      child: Row(
        children: [
          const Icon(
            Icons.info_outline_rounded,
            color: AppColors.textSecondary,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

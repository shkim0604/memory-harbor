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
  final PageController _othersController = PageController(
    viewportFraction: 0.88,
  );
  static const String _defaultIntroMessage = '함께 이야기를 모아봐요';

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
        title: const Text(
          '우리 그룹',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.primaryLight.withValues(alpha: 0.14),
              AppColors.background,
              AppColors.background,
            ],
            stops: const [0.0, 0.22, 1.0],
          ),
        ),
        child: _buildBody(),
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

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 1,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(left: 4),
                    child: Text(
                      '나레이터',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: receiver == null
                        ? _buildEmptyCard('나레이터 정보를 불러오는 중입니다.')
                        : SizedBox.expand(
                            child: Align(
                              alignment: Alignment.topCenter,
                              child: FractionallySizedBox(
                                widthFactor: _othersController.viewportFraction,
                                heightFactor: 1,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                  ),
                                  child: _buildReceiverCard(receiver),
                                ),
                              ),
                            ),
                          ),
                  ),
                  if (caregivers.length > 1) ...[
                    const SizedBox(height: 8),
                    const SizedBox(height: 8),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              flex: 1,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Text(
                      '인터뷰어 ${caregivers.length}명',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: caregivers.isEmpty
                        ? _buildEmptyCard('등록된 구성원이 없습니다.')
                        : PageView.builder(
                            controller: _othersController,
                            itemCount: caregivers.length,
                            itemBuilder: (context, index) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                ),
                                child: _buildCaregiverCard(caregivers[index]),
                              );
                            },
                          ),
                  ),
                  if (caregivers.length > 1) ...[
                    const SizedBox(height: 8),
                    _buildPageIndicator(_othersController, caregivers.length),
                  ],
                ],
              ),
            ),
          ],
        ),
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
                    ? AppColors.primary
                    : AppColors.textHint.withValues(alpha: 0.3),
              ),
            );
          }),
        );
      },
    );
  }

  Widget _buildRoleChip(String subtitle) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.primaryLight.withValues(alpha: 0.26),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        subtitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        softWrap: false,
        style: TextStyle(
          fontSize: 13,
          color: AppColors.secondary.withValues(alpha: 0.9),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildReceiverCard(CareReceiver receiver) {
    return _buildMemberCard(
      name: receiver.name,
      subtitle: '',
      imageUrl: receiver.profileImage,
      introMessage: _defaultIntroMessage,
    );
  }

  Widget _buildCaregiverCard(AppUser user) {
    return _buildMemberCard(
      name: user.name,
      subtitle: '',
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
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.primaryLight.withValues(alpha: 0.45),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.045),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final imageWidth = constraints.maxWidth * 2 / 5;
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
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
                    children: [
                      Text(
                        name.isNotEmpty ? name : '이름 없음',
                        style: const TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (subtitle.isNotEmpty) ...[
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
                      ],
                      const SizedBox(height: 8),
                      Expanded(
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceVariant.withValues(
                              alpha: 0.75,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: SingleChildScrollView(
                            child: Text(
                              introMessage,
                              style: TextStyle(
                                fontSize: 15,
                                color: AppColors.textSecondary.withValues(
                                  alpha: 0.9,
                                ),
                                height: 1.4,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
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
    final fallbackChar = fallbackText.isNotEmpty ? fallbackText[0] : '?';
    return Container(
      decoration: BoxDecoration(color: AppColors.accentLight),
      child: hasImage
          ? (imageUrl.startsWith('assets/')
                ? Image.asset(imageUrl, fit: BoxFit.cover)
                : Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) =>
                        _buildProfileFallback(fallbackChar),
                  ))
          : _buildProfileFallback(fallbackChar),
    );
  }

  Widget _buildProfileFallback(String fallbackChar) {
    return Center(
      child: Text(
        fallbackChar,
        style: const TextStyle(
          fontSize: 36,
          fontWeight: FontWeight.w700,
          color: Colors.white,
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
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

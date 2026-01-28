import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Memory Harbor'),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {
              // TODO: Notifications
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profile Section
            _buildProfileSection(context),
            const SizedBox(height: 24),
            // Stats Section
            _buildStatsSection(),
            const SizedBox(height: 24),
            // My Call History
            _buildSectionTitle('나의 통화기록'),
            const SizedBox(height: 12),
            _buildCallHistoryList(isMyHistory: true),
            const SizedBox(height: 24),
            // Community Call History
            _buildSectionTitle('공동체 통화기록'),
            const SizedBox(height: 12),
            _buildCallHistoryList(isMyHistory: false),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileSection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Profile Image
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primaryLight,
              border: Border.all(
                color: AppColors.primary,
                width: 3,
              ),
            ),
            child: const Icon(
              Icons.person,
              size: 40,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 16),
          // Profile Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '사용자님',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '오늘도 소중한 기억을 나눠보세요',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsSection() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primaryDark],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildStatItem('총 통화', '12', '회'),
          _buildDivider(),
          _buildStatItem('이번 주', '3', '회'),
          _buildDivider(),
          _buildStatItem('연결된 분', '5', '명'),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, String unit) {
    return Column(
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
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              value,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 4, left: 2),
              child: Text(
                unit,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withValues(alpha: 0.8),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDivider() {
    return Container(
      width: 1,
      height: 40,
      color: Colors.white.withValues(alpha: 0.3),
    );
  }

  Widget _buildSectionTitle(String title) {
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
          onPressed: () {
            // TODO: See all
          },
          child: const Text('전체보기'),
        ),
      ],
    );
  }

  Widget _buildCallHistoryList({required bool isMyHistory}) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 3,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        return _buildCallHistoryItem(
          name: isMyHistory ? '할머니' : '김OO 어르신',
          date: '2026.01.${28 - index}',
          duration: '${15 + index * 5}분',
          isMyHistory: isMyHistory,
        );
      },
    );
  }

  Widget _buildCallHistoryItem({
    required String name,
    required String date,
    required String duration,
    required bool isMyHistory,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.surfaceVariant,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: isMyHistory
                  ? AppColors.accentLight
                  : AppColors.primaryLight,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.phone,
              color: isMyHistory ? AppColors.accentDark : AppColors.primaryDark,
            ),
          ),
          const SizedBox(width: 16),
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
                  date,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              duration,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

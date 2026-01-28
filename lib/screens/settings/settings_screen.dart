import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('설정'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 20),
            // Profile Edit Section
            _buildProfileSection(context),
            const SizedBox(height: 24),
            // Settings List
            _buildSettingsSection(context),
            const SizedBox(height: 24),
            // App Info
            _buildAppInfoSection(context),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileSection(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
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
      child: Column(
        children: [
          // Profile Image
          Stack(
            children: [
              Container(
                width: 100,
                height: 100,
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
                  size: 50,
                  color: AppColors.primary,
                ),
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.accent,
                  ),
                  child: const Icon(
                    Icons.camera_alt,
                    size: 18,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            '사용자님',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'user@email.com',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: () {
              // TODO: Edit profile
            },
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.primary),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('프로필 수정'),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsSection(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 20, 20, 8),
            child: Text(
              '나의 정보',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          _buildSettingItem(
            icon: Icons.person_outline,
            title: '이름 변경',
            onTap: () {},
          ),
          _buildSettingItem(
            icon: Icons.phone_outlined,
            title: '연락처 관리',
            onTap: () {},
          ),
          _buildSettingItem(
            icon: Icons.location_on_outlined,
            title: '거주지 정보',
            subtitle: '시대별 거주지 입력',
            onTap: () {},
          ),
          const Divider(height: 1),
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 20, 20, 8),
            child: Text(
              '앱 설정',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          _buildSettingItem(
            icon: Icons.notifications_outlined,
            title: '알림 설정',
            onTap: () {},
          ),
          _buildSettingItem(
            icon: Icons.lock_outline,
            title: '개인정보 및 보안',
            onTap: () {},
          ),
          _buildSettingItem(
            icon: Icons.help_outline,
            title: '도움말',
            onTap: () {},
          ),
        ],
      ),
    );
  }

  Widget _buildSettingItem({
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: AppColors.secondary),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          color: AppColors.textPrimary,
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            )
          : null,
      trailing: const Icon(
        Icons.chevron_right,
        color: AppColors.textHint,
      ),
      onTap: onTap,
    );
  }

  Widget _buildAppInfoSection(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          _buildSettingItem(
            icon: Icons.info_outline,
            title: '앱 정보',
            subtitle: 'v1.0.0',
            onTap: () {},
          ),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text(
              '로그아웃',
              style: TextStyle(
                fontSize: 16,
                color: Colors.red,
              ),
            ),
            onTap: () {
              // TODO: Logout
              Navigator.of(context).pushReplacementNamed('/auth');
            },
          ),
        ],
      ),
    );
  }
}

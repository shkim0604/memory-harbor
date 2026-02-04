import 'package:flutter/material.dart';
import 'dart:io';
import 'package:permission_handler/permission_handler.dart';
import '../../theme/app_colors.dart';
import '../../viewmodels/settings_viewmodel.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final SettingsViewModel _viewModel = SettingsViewModel();

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

  Future<void> _showEditNameDialog() async {
    final user = _viewModel.user;
    if (user == null) return;

    final controller = TextEditingController(text: user.name);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('이름 변경'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: '새 이름을 입력하세요'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('저장'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty && result != user.name) {
      final error = await _viewModel.updateName(result);
      if (!mounted) return;
      if (error != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error)));
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('이름이 변경되었습니다')));
    }
  }

  Future<void> _showEditEmailDialog() async {
    final user = _viewModel.user;
    if (user == null) return;

    final controller = TextEditingController(text: user.email);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('이메일 변경'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: '새 이메일을 입력하세요'),
          keyboardType: TextInputType.emailAddress,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('저장'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty && result != user.email) {
      if (!_viewModel.isValidEmail(result)) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('이메일 형식을 확인해주세요')));
        }
        return;
      }

      final error = await _viewModel.updateEmail(result);
      if (!mounted) return;
      if (error != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error)));
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('이메일이 변경되었습니다')));
    }
  }

  Future<void> _pickAndUploadImage() async {
    final error = await _viewModel.uploadProfileImage();
    if (!mounted) return;
    if (error != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
    }
  }

  Future<void> _requestPermission(Permission permission, String label) async {
    final status = await _viewModel.requestPermission(permission);
    if (!mounted) return;
    if (status.isGranted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$label 권한이 허용되었습니다')));
      return;
    }

    if (status.isPermanentlyDenied) {
      final extraHint = (Platform.isIOS && permission == Permission.microphone)
          ? ' (iOS: 설정 > 개인정보 보호 및 보안 > 마이크)'
          : '';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$label 권한이 차단되었습니다. 설정에서 허용해주세요.$extraHint'),
          action: SnackBarAction(
            label: '설정 열기',
            onPressed: () => openAppSettings(),
          ),
        ),
      );
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$label 권한이 거부되었습니다')));
  }

  String _permissionStatusLabel(PermissionStatus? status) {
    if (status == null) return '확인 중...';
    if (status.isGranted) return '허용됨';
    if (status.isLimited) return '제한됨';
    if (status.isPermanentlyDenied) return '차단됨';
    if (status.isDenied) return '거부됨';
    if (status.isRestricted) return '제한됨';
    return '알 수 없음';
  }

  Color _permissionStatusColor(PermissionStatus? status) {
    if (status == null) return AppColors.textHint;
    if (status.isGranted) return Colors.green;
    if (status.isLimited) return AppColors.accent;
    if (status.isPermanentlyDenied) return Colors.red;
    if (status.isDenied) return Colors.redAccent;
    if (status.isRestricted) return AppColors.accent;
    return AppColors.textHint;
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('설정'), centerTitle: true),
      body: _viewModel.isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  _buildProfileSection(context),
                  const SizedBox(height: 24),
                  _buildSettingsSection(context),
                  const SizedBox(height: 24),
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
          GestureDetector(
            onTap: _viewModel.isUploading ? null : _pickAndUploadImage,
            child: Stack(
              children: [
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.primaryLight,
                    border: Border.all(color: AppColors.primary, width: 3),
                    image: _viewModel.user?.profileImage.isNotEmpty == true
                        ? DecorationImage(
                            image:
                                NetworkImage(_viewModel.user!.profileImage),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: _viewModel.isUploading
                      ? const Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : (_viewModel.user?.profileImage.isEmpty ?? true)
                      ? const Icon(
                          Icons.person,
                          size: 50,
                          color: AppColors.primary,
                        )
                      : null,
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
          ),
          const SizedBox(height: 16),
          Text(
            _viewModel.user?.name ?? '사용자',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _viewModel.user?.email ?? '',
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
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
            onTap: _showEditNameDialog,
          ),
          _buildSettingItem(
            icon: Icons.phone_outlined,
            title: '연락처 관리',
            onTap: _showEditEmailDialog,
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
            icon: Icons.camera_alt_outlined,
            title: '카메라 권한',
            subtitle: _permissionStatusLabel(_viewModel.cameraStatus),
            subtitleColor: _permissionStatusColor(_viewModel.cameraStatus),
            onTap: () => _requestPermission(Permission.camera, '카메라'),
          ),
          _buildSettingItem(
            icon: Icons.mic_none_outlined,
            title: '마이크 권한',
            subtitle: _permissionStatusLabel(_viewModel.microphoneStatus),
            subtitleColor: _permissionStatusColor(_viewModel.microphoneStatus),
            onTap: () => _requestPermission(Permission.microphone, '마이크'),
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
    Color? subtitleColor,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: AppColors.secondary),
      title: Text(
        title,
        style: const TextStyle(fontSize: 16, color: AppColors.textPrimary),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle,
              style: TextStyle(
                fontSize: 13,
                color: subtitleColor ?? AppColors.textSecondary,
              ),
            )
          : null,
      trailing: const Icon(Icons.chevron_right, color: AppColors.textHint),
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
              style: TextStyle(fontSize: 16, color: Colors.red),
            ),
            onTap: () async {
              await _viewModel.signOut();
              if (context.mounted) {
                Navigator.of(context).pushReplacementNamed('/auth');
              }
            },
          ),
        ],
      ),
    );
  }
}

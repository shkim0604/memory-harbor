import 'package:flutter/material.dart';
import 'dart:io';
import 'package:permission_handler/permission_handler.dart';
import '../../constants/input_limits.dart';
import '../../theme/app_colors.dart';
import '../../viewmodels/settings_viewmodel.dart';

enum _ProfileImageSource { gallery, camera }

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final SettingsViewModel _viewModel = SettingsViewModel();
  bool _isPickingProfileImage = false;

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

  Future<void> _showEditIntroDialog() async {
    final user = _viewModel.user;
    if (user == null) return;

    final controller = TextEditingController(text: user.introMessage);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('한 마디 변경'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: '한 마디를 입력하세요'),
          maxLines: 2,
          maxLength: InputLimits.introMessageMaxLength,
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

    final trimmed = result?.trim() ?? '';
    if (trimmed.isEmpty) return;
    if (trimmed.length > InputLimits.introMessageMaxLength) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '한 마디는 ${InputLimits.introMessageMaxLength}자 이내로 입력해 주세요',
            ),
          ),
        );
      }
      return;
    }
    if (trimmed != user.introMessage) {
      final error = await _viewModel.updateIntroMessage(trimmed);
      if (!mounted) return;
      if (error != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error)));
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('한 마디가 변경되었습니다')));
    }
  }

  Future<void> _pickAndUploadImage() async {
    if (_isPickingProfileImage || _viewModel.isUploading) return;
    setState(() {
      _isPickingProfileImage = true;
    });
    final beforeImageUrl = _viewModel.user?.profileImage ?? '';
    try {
      final source = await showModalBottomSheet<_ProfileImageSource>(
        context: context,
        builder: (context) {
          return SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.photo_library_outlined),
                  title: const Text('갤러리에서 선택'),
                  onTap: () =>
                      Navigator.pop(context, _ProfileImageSource.gallery),
                ),
                ListTile(
                  leading: const Icon(Icons.camera_alt_outlined),
                  title: const Text('사진 찍기'),
                  onTap: () => Navigator.pop(context, _ProfileImageSource.camera),
                ),
              ],
            ),
          );
        },
      );
      if (source == null) return;

      // Let bottom sheet route finish popping before opening image picker.
      await Future<void>.delayed(const Duration(milliseconds: 120));

      final error = await _viewModel.uploadProfileImage(
        useCamera: source == _ProfileImageSource.camera,
      );
      if (!mounted) return;
      if (error != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error)));
        return;
      }
      final afterImageUrl = _viewModel.user?.profileImage ?? '';
      if (afterImageUrl.isNotEmpty && afterImageUrl != beforeImageUrl) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('프로필 사진이 변경되었습니다')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isPickingProfileImage = false;
        });
      }
    }
  }

  Future<void> _requestPermission(Permission permission, String label) async {
    final currentStatus = await permission.status;
    if (!mounted) return;

    if (currentStatus.isGranted || currentStatus.isLimited) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$label 권한을 끄려면 설정에서 변경해주세요.'),
          action: SnackBarAction(
            label: '설정 열기',
            onPressed: () => openAppSettings(),
          ),
        ),
      );
      return;
    }

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

  Future<void> _showDeleteAccountDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('계정 삭제 요청'),
          content: const Text(
            '계정 삭제를 요청하면 30일 뒤 계정과 모든 데이터가 완전히 삭제됩니다.\n'
            '삭제 요청 UID는 d.house0827@gmail.com 으로 이메일 전송됩니다.\n\n'
            '계속 진행할까요?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('삭제 요청'),
            ),
          ],
        );
      },
    );
    if (confirmed != true) return;

    final error = await _viewModel.requestAccountDeletion();
    if (!mounted) return;
    if (error != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('계정 삭제가 요청되었습니다. 30일 후 계정과 데이터가 삭제됩니다.'),
      ),
    );
    Navigator.of(context).pushReplacementNamed('/auth');
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
            onTap: (_viewModel.isUploading || _isPickingProfileImage)
                ? null
                : _pickAndUploadImage,
            child: Stack(
              children: [
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.primaryLight,
                    border: Border.all(color: AppColors.primary, width: 3),
                  ),
                  child: _viewModel.isUploading
                      ? const Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : ClipOval(
                          child: _viewModel.user?.profileImage.isNotEmpty == true
                              ? Image.network(
                                  _viewModel.user!.profileImage,
                                  fit: BoxFit.cover,
                                  width: 100,
                                  height: 100,
                                  errorBuilder: (_, _, _) => const Icon(
                                    Icons.person,
                                    size: 50,
                                    color: AppColors.primary,
                                  ),
                                )
                              : const Icon(
                                  Icons.person,
                                  size: 50,
                                  color: AppColors.primary,
                                ),
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
          if ((_viewModel.user?.introMessage ?? '').isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              _viewModel.user!.introMessage,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary.withValues(alpha: 0.9),
              ),
            ),
          ],
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
            icon: Icons.message_outlined,
            title: '한 마디 변경',
            onTap: _showEditIntroDialog,
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
          ListTile(
            leading: const Icon(Icons.delete_forever_outlined, color: Colors.red),
            title: const Text(
              '계정 삭제 요청',
              style: TextStyle(fontSize: 16, color: Colors.red),
            ),
            subtitle: const Text(
              '요청 후 30일 뒤 계정과 모든 데이터가 삭제됩니다',
              style: TextStyle(fontSize: 12),
            ),
            onTap: _showDeleteAccountDialog,
          ),
        ],
      ),
    );
  }
}

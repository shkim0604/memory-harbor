import 'package:flutter/material.dart';
import '../../constants/input_limits.dart';
import '../../theme/app_colors.dart';
import '../../viewmodels/onboarding_viewmodel.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _introController = TextEditingController();
  final OnboardingViewModel _viewModel = OnboardingViewModel();

  @override
  void initState() {
    super.initState();
    _viewModel.init(onChanged: () {
      if (mounted) {
        if (_viewModel.initialName != null &&
            _nameController.text.trim().isEmpty) {
          _nameController.text = _viewModel.initialName!;
        }
        setState(() {});
      }
    });
  }

  Future<void> _pickImage() async {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('갤러리에서 선택'),
              onTap: () async {
                Navigator.pop(context);
                await _viewModel.pickImageFromGallery();
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('카메라로 촬영'),
              onTap: () async {
                Navigator.pop(context);
                await _viewModel.pickImageFromCamera(this.context);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _introController.dispose();
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFAD4D4), Color(0xFFF5E6E0), Color(0xFFE8F4F8)],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                  const SizedBox(height: 60),
                  // Welcome Text
                  const Text(
                    '환영합니다!',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: AppColors.secondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '프로필을 설정해 주세요',
                    style: TextStyle(
                      fontSize: 16,
                      color: AppColors.secondary.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: 48),
                  // Profile Image
                  Center(
                    child: GestureDetector(
                      onTap: _pickImage,
                      child: Stack(
                        children: [
                          CircleAvatar(
                            radius: 60,
                            backgroundColor: AppColors.surfaceVariant,
                            backgroundImage: _viewModel.selectedImage != null
                                ? FileImage(_viewModel.selectedImage!)
                                : (_viewModel.profileImageUrl != null
                                      ? NetworkImage(_viewModel.profileImageUrl!)
                                      : null),
                            child:
                                (_viewModel.selectedImage == null &&
                                    _viewModel.profileImageUrl == null)
                                ? const Icon(
                                    Icons.person,
                                    size: 60,
                                    color: AppColors.textSecondary,
                                  )
                                : null,
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: const BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.camera_alt,
                                size: 20,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 48),
                  // Name Field
                  const Text(
                    '이름',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      hintText: '이름을 입력해 주세요',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return '이름을 입력해 주세요';
                      }
                      if (value.trim().length < 2) {
                        return '이름은 2자 이상이어야 합니다';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  // Email Display (read-only)
                  const Text(
                    '이메일',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _viewModel.initialEmail ?? '',
                      style: TextStyle(
                        fontSize: 16,
                        color: AppColors.textPrimary.withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    '그룹원들에게 한 마디',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _introController,
                    decoration: InputDecoration(
                      hintText: '그룹원들에게 전하고 싶은 말을 적어주세요',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                    ),
                    maxLength: InputLimits.introMessageMaxLength,
                    maxLines: 2,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return '한 마디를 입력해 주세요';
                      }
                      if (value.trim().length >
                          InputLimits.introMessageMaxLength) {
                        return '한 마디는 ${InputLimits.introMessageMaxLength}자 이내로 입력해 주세요';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    '그룹 선택',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_viewModel.groupsLoading)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (_viewModel.groupsError != null)
                    Text(
                      _viewModel.groupsError!,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.red.shade400,
                      ),
                    )
                  else if (_viewModel.groups.isEmpty)
                    Text(
                      '참여 가능한 그룹이 없습니다',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary.withValues(alpha: 0.7),
                      ),
                    )
                  else
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.65),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.secondary.withValues(alpha: 0.1),
                        ),
                      ),
                      child: Column(
                        children: _viewModel.groups.map((group) {
                          final selected = _viewModel.selectedGroupIds
                              .contains(group.groupId);
                          final role =
                              _viewModel.selectedGroupRoles[group.groupId];
                          final narratorLocked = group.receiverId.isNotEmpty;
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: selected
                                    ? AppColors.primary.withValues(alpha: 0.6)
                                    : AppColors.secondary.withValues(alpha: 0.15),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Checkbox(
                                      value: selected,
                                      onChanged: (checked) {
                                        _viewModel.toggleGroupSelection(
                                          group,
                                          checked ?? false,
                                        );
                                      },
                                      activeColor: AppColors.primary,
                                    ),
                                    Expanded(
                                      child: Text(
                                        group.name,
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                    ),
                                    if (narratorLocked)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.secondary.withValues(
                                            alpha: 0.1,
                                          ),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: const Text(
                                          'Narrator 있음',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Opacity(
                                  opacity: selected ? 1 : 0.4,
                                  child: Wrap(
                                    spacing: 8,
                                    children: [
                                      ChoiceChip(
                                        label: const Text('Narrator'),
                                        selected:
                                            role == 'narrator' && selected,
                                        onSelected: selected && !narratorLocked
                                            ? (_) => _viewModel.setGroupRole(
                                                  group.groupId,
                                                  'narrator',
                                                )
                                            : null,
                                        selectedColor: AppColors.primary,
                                        labelStyle: TextStyle(
                                          color: role == 'narrator' && selected
                                              ? Colors.white
                                              : AppColors.textPrimary,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      ChoiceChip(
                                        label: const Text('Interviewer'),
                                        selected:
                                            role == 'companion' && selected,
                                        onSelected: selected
                                            ? (_) => _viewModel.setGroupRole(
                                                  group.groupId,
                                                  'companion',
                                                )
                                            : null,
                                        selectedColor: AppColors.primary,
                                        labelStyle: TextStyle(
                                          color: role == 'companion' && selected
                                              ? Colors.white
                                              : AppColors.textPrimary,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  const SizedBox(height: 24),
                  // Submit Button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed:
                          _viewModel.isLoading ? null : _handleSubmit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: AppColors.primary.withValues(
                          alpha: 0.5,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _viewModel.isLoading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              '시작하기',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_viewModel.selectedGroupIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('그룹을 최소 1개 선택해 주세요'),
          backgroundColor: Colors.red.shade400,
        ),
      );
      return;
    }
    final missingRole = _viewModel.selectedGroupIds.any(
      (id) => !_viewModel.selectedGroupRoles.containsKey(id),
    );
    if (missingRole) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('각 그룹의 역할을 선택해 주세요'),
          backgroundColor: Colors.red.shade400,
        ),
      );
      return;
    }

    final error = await _viewModel.submitProfile(
      _nameController.text.trim(),
      _introController.text.trim(),
    );
    if (!mounted) return;
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error),
          backgroundColor: Colors.red.shade400,
        ),
      );
      return;
    }

    Navigator.of(context).pushReplacementNamed('/main');
  }
}

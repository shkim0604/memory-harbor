import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../services/permission_service.dart';
import '../services/storage_service.dart';
import '../services/user_service.dart';

class OnboardingViewModel {
  bool isLoading = false;
  File? selectedImage;
  String? profileImageUrl;
  String? initialName;
  String? initialEmail;

  void Function()? _onChanged;

  void init({required void Function() onChanged}) {
    _onChanged = onChanged;
    _prefillUserData();
  }

  void dispose() {
    _onChanged = null;
  }

  void _prefillUserData() {
    final user = FirebaseAuth.instance.currentUser;
    if (user?.displayName != null && user!.displayName!.isNotEmpty) {
      initialName = user.displayName;
    }
    if (user?.photoURL != null) {
      profileImageUrl = user!.photoURL;
    }
    initialEmail = user?.email ?? '';
    _onChanged?.call();
  }

  Future<void> pickImageFromGallery() async {
    final file = await StorageService.instance.pickImageFromGallery();
    if (file == null) return;
    selectedImage = file;
    profileImageUrl = null;
    _onChanged?.call();
  }

  Future<bool> pickImageFromCamera(BuildContext context) async {
    final hasPermission =
        await PermissionService.instance.requestCameraWithUI(context);
    if (!hasPermission) return false;

    final file = await StorageService.instance.pickImageFromCamera();
    if (file == null) return false;
    selectedImage = file;
    profileImageUrl = null;
    _onChanged?.call();
    return true;
  }

  Future<String?> submitProfile(String name) async {
    if (isLoading) return null;
    isLoading = true;
    _onChanged?.call();

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        return '로그인 정보를 찾을 수 없습니다';
      }

      String? finalProfileImageUrl = profileImageUrl;
      if (selectedImage != null) {
        finalProfileImageUrl = await StorageService.instance.uploadProfileImage(
          userId: user.uid,
          imageFile: selectedImage!,
        );
      }

      await UserService.instance.createUser(
        uid: user.uid,
        name: name,
        email: user.email ?? '',
        profileImage: finalProfileImageUrl,
      );

      return null;
    } catch (e) {
      return '프로필 저장에 실패했습니다: $e';
    } finally {
      isLoading = false;
      _onChanged?.call();
    }
  }
}

import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../services/permission_service.dart';
import '../services/storage_service.dart';
import '../services/call_notification_service.dart';
import '../services/user_service.dart';
import '../services/group_service.dart';
import '../models/group.dart';

class OnboardingViewModel {
  bool isLoading = false;
  File? selectedImage;
  String? profileImageUrl;
  String? initialName;
  String? initialEmail;
  List<Group> groups = [];
  final Set<String> selectedGroupIds = {};
  final Map<String, String> selectedGroupRoles = {};
  bool groupsLoading = false;

  void Function()? _onChanged;

  void init({required void Function() onChanged}) {
    _onChanged = onChanged;
    _prefillUserData();
    _loadGroups();
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

  String? groupsError;

  Future<void> _loadGroups() async {
    if (groupsLoading) return;
    groupsLoading = true;
    groupsError = null;
    _onChanged?.call();
    try {
      groups = await GroupService.instance.listGroups();
    } catch (e) {
      debugPrint('Failed to load groups: $e');
      groupsError = '그룹 목록을 불러오지 못했습니다: $e';
    } finally {
      groupsLoading = false;
      _onChanged?.call();
    }
  }

  void toggleGroupSelection(Group group, bool selected) {
    final groupId = group.groupId;
    if (selected) {
      selectedGroupIds.add(groupId);
      if (group.receiverId.isNotEmpty) {
        selectedGroupRoles[groupId] = 'companion';
      }
    } else {
      selectedGroupIds.remove(groupId);
      selectedGroupRoles.remove(groupId);
    }
    _onChanged?.call();
  }

  void setGroupRole(String groupId, String role) {
    if (!selectedGroupIds.contains(groupId)) return;
    selectedGroupRoles[groupId] = role;
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

  Future<String?> submitProfile(String name, String introMessage) async {
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

      for (final groupId in selectedGroupIds) {
        final role = selectedGroupRoles[groupId];
        if (role != 'narrator') continue;
        final success = await GroupService.instance.assignReceiverIfEmpty(
          groupId: groupId,
          receiverId: user.uid,
        );
        if (!success) {
          return '이미 Narrator가 있는 그룹입니다';
        }
      }

      await UserService.instance.createUser(
        uid: user.uid,
        name: name,
        email: user.email ?? '',
        profileImage: finalProfileImageUrl,
        introMessage: introMessage,
        groupIds: selectedGroupIds.toList(),
      );

      // User doc now exists — register push tokens that were deferred during sign-in.
      CallNotificationService.instance.registerTokens();

      return null;
    } catch (e) {
      return '프로필 저장에 실패했습니다: $e';
    } finally {
      isLoading = false;
      _onChanged?.call();
    }
  }
}

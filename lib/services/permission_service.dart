import 'dart:io';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

/// 앱 권한 관리 서비스
class PermissionService {
  PermissionService._();
  static final instance = PermissionService._();

  /// 마이크 권한 확인
  Future<bool> hasMicrophonePermission() async {
    final status = await Permission.microphone.status;
    return status.isGranted;
  }

  /// 마이크 권한 요청
  Future<bool> requestMicrophonePermission() async {
    final status = await Permission.microphone.request();
    return status.isGranted;
  }

  /// 카메라 권한 확인
  Future<bool> hasCameraPermission() async {
    final status = await Permission.camera.status;
    return status.isGranted;
  }

  /// 카메라 권한 요청
  Future<bool> requestCameraPermission() async {
    final status = await Permission.camera.request();
    return status.isGranted;
  }

  /// 사진 라이브러리 권한 확인
  Future<bool> hasPhotosPermission() async {
    final status = await Permission.photos.status;
    return status.isGranted;
  }

  /// 사진 라이브러리 권한 요청
  Future<bool> requestPhotosPermission() async {
    final status = await Permission.photos.request();
    return status.isGranted;
  }

  /// 저장소 권한 요청 (Android)
  Future<bool> requestStoragePermission() async {
    if (!Platform.isAndroid) return true;
    final status = await Permission.storage.request();
    return status.isGranted;
  }

  /// 통화에 필요한 모든 권한 요청
  Future<bool> requestCallPermissions() async {
    final micGranted = await requestMicrophonePermission();
    if (!micGranted) return false;

    // Android에서는 저장소 권한도 요청 (녹음 저장용)
    if (Platform.isAndroid) {
      await requestStoragePermission();
    }

    return true;
  }

  /// 권한이 영구 거부되었는지 확인
  Future<bool> isPermanentlyDenied(Permission permission) async {
    final status = await permission.status;
    return status.isPermanentlyDenied;
  }

  /// 설정으로 이동하는 다이얼로그 표시
  Future<void> showPermissionSettingsDialog(
    BuildContext context, {
    required String title,
    required String message,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('설정으로 이동'),
          ),
        ],
      ),
    );

    if (result == true) {
      await openAppSettings();
    }
  }

  /// 마이크 권한 요청 (UI 포함)
  Future<bool> requestMicrophoneWithUI(BuildContext context) async {
    // 이미 권한이 있으면 true 반환
    if (await hasMicrophonePermission()) return true;

    // 권한 요청
    final granted = await requestMicrophonePermission();
    if (granted) return true;

    // 영구 거부 상태면 설정으로 안내
    if (await isPermanentlyDenied(Permission.microphone)) {
      if (context.mounted) {
        await showPermissionSettingsDialog(
          context,
          title: '마이크 권한 필요',
          message: Platform.isIOS
              ? '통화 기능을 사용하려면 iOS 설정에서 마이크 권한을 허용해 주세요.\n(설정 > 개인정보 보호 및 보안 > 마이크 > MemHarbor)'
              : '통화 기능을 사용하려면 설정에서 마이크 권한을 허용해 주세요.',
        );
      }
    }

    return false;
  }

  /// 카메라 권한 요청 (UI 포함)
  Future<bool> requestCameraWithUI(BuildContext context) async {
    if (await hasCameraPermission()) return true;

    final granted = await requestCameraPermission();
    if (granted) return true;

    if (await isPermanentlyDenied(Permission.camera)) {
      if (context.mounted) {
        await showPermissionSettingsDialog(
          context,
          title: '카메라 권한 필요',
          message: '사진 촬영을 위해 설정에서 카메라 권한을 허용해 주세요.',
        );
      }
    }

    return false;
  }
}

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import '../config/agora_config.dart';
import 'api_client.dart';

/// Firebase Storage 서비스
class StorageService {
  StorageService._();
  static final instance = StorageService._();

  final ImagePicker _picker = ImagePicker();
  final ApiClient _api = ApiClient.instance;

  String get _apiBaseUrl => AgoraConfig.apiBaseUrl;

  /// 갤러리에서 이미지 선택
  Future<File?> pickImageFromGallery() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 80,
      );
      if (image == null) return null;
      return File(image.path);
    } catch (e) {
      debugPrint('Error picking image from gallery: $e');
      return null;
    }
  }

  /// 카메라로 이미지 촬영
  Future<File?> pickImageFromCamera() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 80,
      );
      if (image == null) return null;
      return File(image.path);
    } catch (e) {
      debugPrint('Error picking image from camera: $e');
      return null;
    }
  }

  /// 프로필 이미지 업로드
  Future<String?> uploadProfileImage({
    required String userId,
    required File imageFile,
  }) async {
    try {
      if (_apiBaseUrl.trim().isEmpty) return null;
      final url = '$_apiBaseUrl/api/user/profile-image';
      final response = await _api.postMultipart(
        url,
        file: imageFile,
        fileField: 'file',
        contentType: 'image/jpeg',
        fields: {'userId': userId},
      );
      if (response == null) return null;
      final downloadUrl = response['url'];
      if (downloadUrl is String && downloadUrl.isNotEmpty) {
        debugPrint('Profile image uploaded: $downloadUrl');
        return downloadUrl;
      }
      return null;
    } catch (e) {
      debugPrint('Error uploading profile image: $e');
      return null;
    }
  }

  /// 프로필 이미지 삭제
  Future<void> deleteProfileImage(String userId) async {
    try {
      if (_apiBaseUrl.trim().isEmpty) return;
      final url = '$_apiBaseUrl/api/user/profile-image/delete';
      await _api.postJsonOk(url, {});
    } catch (e) {
      debugPrint('Error deleting profile image: $e');
    }
  }
}

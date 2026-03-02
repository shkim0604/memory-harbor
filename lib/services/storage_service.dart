import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
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
  final FirebaseStorage _storage = FirebaseStorage.instance;

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
      final apiUrl = await _uploadProfileImageViaApi(userId: userId, imageFile: imageFile);
      if (apiUrl != null && _isLikelyValidImageUrl(apiUrl)) {
        debugPrint('Profile image uploaded via API: $apiUrl');
        return apiUrl;
      }

      // Fallback: upload directly to Firebase Storage if API upload is unavailable.
      final firebaseUrl = await _uploadProfileImageViaFirebase(
        userId: userId,
        imageFile: imageFile,
      );
      if (firebaseUrl != null && firebaseUrl.isNotEmpty) {
        debugPrint('Profile image uploaded via Firebase Storage: $firebaseUrl');
        return firebaseUrl;
      }
      return null;
    } catch (e) {
      debugPrint('Error uploading profile image: $e');
      return null;
    }
  }

  Future<String?> _uploadProfileImageViaApi({
    required String userId,
    required File imageFile,
  }) async {
    if (_apiBaseUrl.trim().isEmpty) return null;
    final url = '$_apiBaseUrl/api/user/profile-image';

    // Try common backend variants for multipart field names and uid keys.
    final attempts = <({String fileField, Map<String, String> fields})>[
      (fileField: 'file', fields: {'userId': userId}),
      (fileField: 'image', fields: {'userId': userId}),
      (fileField: 'file', fields: {'uid': userId}),
      (fileField: 'image', fields: {'uid': userId}),
    ];

    final contentType = _contentTypeForFile(imageFile.path);
    final filename = _filenameForUpload(imageFile.path);

    for (final attempt in attempts) {
      final response = await _api.postMultipart(
        url,
        file: imageFile,
        fileField: attempt.fileField,
        filename: filename,
        contentType: contentType,
        fields: attempt.fields,
      );
      final parsedUrl = _extractImageUrl(response);
      if (parsedUrl != null && parsedUrl.isNotEmpty) {
        return parsedUrl;
      }
    }
    return null;
  }

  Future<String?> _uploadProfileImageViaFirebase({
    required String userId,
    required File imageFile,
  }) async {
    final extension = _extensionForFile(imageFile.path);
    final path =
        'users/$userId/profile_${DateTime.now().millisecondsSinceEpoch}$extension';
    final ref = _storage.ref(path);
    await ref.putFile(
      imageFile,
      SettableMetadata(contentType: _contentTypeForFile(imageFile.path)),
    );
    return ref.getDownloadURL();
  }

  String _filenameForUpload(String path) {
    final lastSlash = path.lastIndexOf(Platform.pathSeparator);
    if (lastSlash == -1 || lastSlash == path.length - 1) {
      return 'upload${_extensionForFile(path)}';
    }
    return path.substring(lastSlash + 1);
  }

  String _extensionForFile(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.jpeg')) return '.jpeg';
    if (lower.endsWith('.jpg')) return '.jpg';
    if (lower.endsWith('.png')) return '.png';
    if (lower.endsWith('.webp')) return '.webp';
    if (lower.endsWith('.heic')) return '.heic';
    if (lower.endsWith('.heif')) return '.heif';
    return '.jpg';
  }

  String _contentTypeForFile(String path) {
    final ext = _extensionForFile(path);
    switch (ext) {
      case '.jpeg':
      case '.jpg':
        return 'image/jpeg';
      case '.png':
        return 'image/png';
      case '.webp':
        return 'image/webp';
      case '.heic':
        return 'image/heic';
      case '.heif':
        return 'image/heif';
      default:
        return 'image/jpeg';
    }
  }

  String? _extractImageUrl(Map<String, dynamic>? response) {
    if (response == null) return null;
    const keys = [
      'url',
      'downloadUrl',
      'profileImage',
      'profileImageUrl',
      'imageUrl',
      'photoUrl',
      'photoURL',
      'avatarUrl',
      'avatarURL',
    ];
    for (final key in keys) {
      final value = response[key];
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    final data = response['data'];
    if (data is Map<String, dynamic>) {
      for (final key in keys) {
        final value = data[key];
        if (value is String && value.trim().isNotEmpty) {
          return value.trim();
        }
      }
    }
    return null;
  }

  bool _isLikelyValidImageUrl(String url) {
    final parsed = Uri.tryParse(url);
    if (parsed == null || (parsed.scheme != 'http' && parsed.scheme != 'https')) {
      return false;
    }
    // Known placeholder URL in current data can return invalid bytes.
    if (parsed.host.contains('placehold.co')) return false;
    return true;
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

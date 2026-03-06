import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/painting.dart';
import '../models/user.dart';
import '../services/auth_service.dart';
import '../services/storage_service.dart';
import '../services/text_scale_service.dart';
import '../services/user_service.dart';

class SettingsViewModel {
  AppUser? user;
  bool isLoading = true;
  bool isUploading = false;
  PermissionStatus? cameraStatus;
  PermissionStatus? microphoneStatus;

  void Function()? _onChanged;

  void init({required void Function() onChanged}) {
    _onChanged = onChanged;
    loadUser();
    loadPermissionStatuses();
  }

  void dispose() {
    _onChanged = null;
  }

  AppTextScalePreset get textScalePreset =>
      TextScaleService.instance.presetNotifier.value;

  Future<void> loadUser() async {
    final fetched = await UserService.instance.getCurrentUser();
    user = fetched;
    isLoading = false;
    _onChanged?.call();
  }

  Future<void> loadPermissionStatuses() async {
    cameraStatus = await Permission.camera.status;
    microphoneStatus = await Permission.microphone.status;
    _onChanged?.call();
  }

  Future<PermissionStatus> requestPermission(Permission permission) async {
    final status = await permission.request();
    if (permission == Permission.camera) {
      cameraStatus = status;
    } else if (permission == Permission.microphone) {
      microphoneStatus = status;
    }
    _onChanged?.call();
    return status;
  }

  Future<String?> uploadProfileImage({required bool useCamera}) async {
    if (user == null) return '사용자 정보를 불러올 수 없습니다';
    if (isUploading) return null;

    if (useCamera) {
      final status = await Permission.camera.request();
      cameraStatus = status;
      _onChanged?.call();
      if (!status.isGranted) {
        if (status.isPermanentlyDenied) {
          return '카메라 권한이 차단되었습니다. 설정에서 허용해주세요.';
        }
        return '카메라 권한이 필요합니다.';
      }
    }

    isUploading = true;
    _onChanged?.call();

    final file = useCamera
        ? await StorageService.instance.pickImageFromCamera()
        : await StorageService.instance.pickImageFromGallery();
    if (file == null) {
      isUploading = false;
      _onChanged?.call();
      return null;
    }

    try {
      final previousUrl = user!.profileImage;
      final url = await StorageService.instance.uploadProfileImage(
        userId: user!.uid,
        imageFile: file,
      );
      if (url == null || url.isEmpty) {
        return '이미지 업로드에 실패했습니다. 잠시 후 다시 시도해주세요.';
      }

      await UserService.instance.updateUserProfileImage(user!.uid, url);
      await loadUser();

      // Server may return the same URL path. Evict cache so updated bytes render.
      if (previousUrl.isNotEmpty) {
        PaintingBinding.instance.imageCache.evict(NetworkImage(previousUrl));
      }
      PaintingBinding.instance.imageCache.evict(NetworkImage(url));
      return null;
    } catch (e) {
      return '이미지 업로드 실패: $e';
    } finally {
      isUploading = false;
      _onChanged?.call();
    }
  }

  Future<String?> updateName(String name) async {
    if (user == null) return '사용자 정보를 불러올 수 없습니다';
    try {
      await UserService.instance.updateUserName(user!.uid, name);
      await loadUser();
      return null;
    } catch (e) {
      return '이름 변경 실패: $e';
    }
  }

  bool isValidEmail(String email) {
    final regex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
    return regex.hasMatch(email);
  }

  Future<String?> updateEmail(String email) async {
    if (user == null) return '사용자 정보를 불러올 수 없습니다';
    try {
      await UserService.instance.updateUserEmail(user!.uid, email);
      await loadUser();
      return null;
    } catch (e) {
      return '이메일 변경 실패: $e';
    }
  }

  Future<String?> updateIntroMessage(String introMessage) async {
    if (user == null) return '사용자 정보를 불러올 수 없습니다';
    try {
      await UserService.instance.updateUserIntroMessage(
        user!.uid,
        introMessage,
      );
      await loadUser();
      return null;
    } catch (e) {
      return '한 마디 변경 실패: $e';
    }
  }

  Future<String?> updateTextScalePreset(AppTextScalePreset preset) async {
    try {
      await TextScaleService.instance.setPreset(preset);
      if (user != null) {
        user = user!.copyWith(textScalePreset: preset.storageValue);
      }
      _onChanged?.call();
      return null;
    } catch (e) {
      return '글씨 크기 변경 실패: $e';
    }
  }

  Future<void> signOut() async {
    await AuthService.instance.signOut();
  }

  Future<String?> requestAccountDeletion() async {
    if (user == null) return '사용자 정보를 불러올 수 없습니다';
    try {
      await UserService.instance.requestAccountDeletion(
        uid: user!.uid,
        email: user!.email,
      );
      await signOut();
      return null;
    } catch (e) {
      return '계정 삭제 요청 실패: $e';
    }
  }
}

import 'package:permission_handler/permission_handler.dart';
import '../models/user.dart';
import '../services/auth_service.dart';
import '../services/storage_service.dart';
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

  Future<String?> uploadProfileImage() async {
    if (user == null) return '사용자 정보를 불러올 수 없습니다';
    final file = await StorageService.instance.pickImageFromGallery();
    if (file == null) return null;

    isUploading = true;
    _onChanged?.call();

    try {
      final url = await StorageService.instance.uploadProfileImage(
        userId: user!.uid,
        imageFile: file,
      );
      if (url != null) {
        await UserService.instance.updateUserProfileImage(user!.uid, url);
        await loadUser();
      }
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

  Future<void> signOut() async {
    await AuthService.instance.signOut();
  }
}

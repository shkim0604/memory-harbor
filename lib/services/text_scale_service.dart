import 'package:flutter/foundation.dart';
import '../models/user.dart';
import 'user_service.dart';

enum AppTextScalePreset {
  small('small', '작게', 1.0),
  normal('normal', '보통', 1.15),
  large('large', '크게', 1.3),
  extraLarge('extra_large', '아주 크게', 1.45);

  const AppTextScalePreset(this.storageValue, this.label, this.scale);

  final String storageValue;
  final String label;
  final double scale;

  static AppTextScalePreset fromStorageValue(String? value) {
    return AppTextScalePreset.values.firstWhere(
      (preset) => preset.storageValue == value,
      orElse: () => AppTextScalePreset.normal,
    );
  }
}

class TextScaleService {
  TextScaleService._();

  static final TextScaleService instance = TextScaleService._();

  final ValueNotifier<AppTextScalePreset> presetNotifier =
      ValueNotifier<AppTextScalePreset>(AppTextScalePreset.normal);

  Future<void> init() async {
    final user = await UserService.instance.getCurrentUser();
    presetNotifier.value = _presetFromUser(user);
  }

  Future<void> refreshFromCurrentUser() async {
    final user = await UserService.instance.getCurrentUser();
    presetNotifier.value = _presetFromUser(user);
  }

  Future<void> setPreset(AppTextScalePreset preset) async {
    if (presetNotifier.value == preset) return;
    presetNotifier.value = preset;

    final uid = UserService.instance.currentUid();
    if (uid == null || uid.isEmpty) return;
    await UserService.instance.updateUser(
      uid,
      {'textScalePreset': preset.storageValue},
    );
  }

  AppTextScalePreset _presetFromUser(AppUser? user) {
    return AppTextScalePreset.fromStorageValue(user?.textScalePreset);
  }
}

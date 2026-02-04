import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_storage/firebase_storage.dart';

import 'firebase_options_dev.dart' as dev;
import 'firebase_options_prod.dart' as prod;
import '../services/seed_service.dart';

enum AppEnv { emul, dev, prod }

class FirebaseConfig {
  FirebaseConfig._();

  static const String _env = String.fromEnvironment('ENV', defaultValue: 'dev');

  // Emulator enabled by default for emul environment.
  static const bool _useEmulator = bool.fromEnvironment(
    'USE_EMULATOR',
    defaultValue: false,
  );

  // Override emulator host for physical devices (e.g. '192.168.0.12').
  //
  // Note: On physical devices, 'localhost' points to the device itself, not your
  // development machine where Firebase emulators are running.
  static const String _emulatorHostOverride = String.fromEnvironment(
    'EMULATOR_HOST',
    defaultValue: '',
  );

  static AppEnv get env {
    if (_env == 'prod') return AppEnv.prod;
    if (_env == 'emul') return AppEnv.emul;
    return AppEnv.dev;
  }

  static bool get useEmulator =>
      env == AppEnv.emul || (env == AppEnv.dev && _useEmulator);

  static FirebaseOptions get options {
    if (env == AppEnv.prod) {
      return prod.DefaultFirebaseOptionsProd.currentPlatform;
    }
    if (env == AppEnv.emul) {
      return dev.DefaultFirebaseOptionsDev.currentPlatform;
    }
    // Dev now uses the real Firebase project (former prod).
    return prod.DefaultFirebaseOptionsProd.currentPlatform;
  }

  static Future<void> initialize() async {
    await Firebase.initializeApp(options: options);

    if (!useEmulator) return;

    final host = _emulatorHost;
    debugPrint('Firebase emulator enabled. host=$host');
    FirebaseAuth.instance.useAuthEmulator(host, 9098);
    FirebaseFirestore.instance.useFirestoreEmulator(host, 8081);
    FirebaseFunctions.instance.useFunctionsEmulator(host, 5001);
    FirebaseStorage.instance.useStorageEmulator(host, 9198);

    try {
      await SeedService.instance.seedIfNeeded();
    } catch (e, st) {
      // If the emulator is unreachable (common on physical devices without
      // EMULATOR_HOST), don't crash the app during startup.
      debugPrint('SeedService.seedIfNeeded failed: $e');
      debugPrint('$st');
    }
  }

  static String get _emulatorHost {
    final override = _emulatorHostOverride.trim();
    if (override.isNotEmpty) return override;
    if (kIsWeb) return 'localhost';

    // Defaults:
    // - Android emulator -> 10.0.2.2 maps to host machine's localhost
    // - iOS simulator / desktop -> localhost
    // - Physical devices -> pass --dart-define=EMULATOR_HOST=<your-mac-ip>
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return '10.0.2.2';
      case TargetPlatform.iOS:
        debugPrint(
          'Firebase emulator host defaults to localhost on iOS. '
          'If you are running on a physical device, pass '
          '--dart-define=EMULATOR_HOST=<your-mac-ip>.',
        );
        return 'localhost';
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      case TargetPlatform.fuchsia:
        return 'localhost';
    }
  }
}

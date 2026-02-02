import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_storage/firebase_storage.dart';

import 'firebase_options_dev.dart' as dev;
import 'firebase_options_prod.dart' as prod;

enum AppEnv { dev, prod }

class FirebaseConfig {
  FirebaseConfig._();

  static const String _env = String.fromEnvironment(
    'ENV',
    defaultValue: 'dev',
  );

  static const bool _useEmulator =
      bool.fromEnvironment('USE_EMULATOR', defaultValue: true);

  static AppEnv get env => _env == 'prod' ? AppEnv.prod : AppEnv.dev;

  static bool get useEmulator => env == AppEnv.dev && _useEmulator;

  static FirebaseOptions get options => env == AppEnv.prod
      ? prod.DefaultFirebaseOptionsProd.currentPlatform
      : dev.DefaultFirebaseOptionsDev.currentPlatform;

  static Future<void> initialize() async {
    await Firebase.initializeApp(options: options);

    if (!useEmulator) return;

    final host = _emulatorHost;
    FirebaseAuth.instance.useAuthEmulator(host, 9099);
    FirebaseFirestore.instance.useFirestoreEmulator(host, 8080);
    FirebaseFunctions.instance.useFunctionsEmulator(host, 5001);
    FirebaseStorage.instance.useStorageEmulator(host, 9199);
  }

  static String get _emulatorHost {
    if (kIsWeb) return 'localhost';
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return '10.0.2.2';
      default:
        return 'localhost';
    }
  }
}

import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options_prod.dart' as prod;

enum AppEnv { dev, prod }

class FirebaseConfig {
  FirebaseConfig._();

  static const String _env = String.fromEnvironment('ENV', defaultValue: 'dev');

  static AppEnv get env {
    if (_env == 'prod') return AppEnv.prod;
    return AppEnv.dev;
  }

  static FirebaseOptions get options {
    if (env == AppEnv.prod) {
      return prod.DefaultFirebaseOptionsProd.currentPlatform;
    }
    // Dev currently uses the same Firebase project as prod.
    return prod.DefaultFirebaseOptionsProd.currentPlatform;
  }

  static Future<void> initialize() async {
    await Firebase.initializeApp(options: options);
    final opts = Firebase.app().options;
    debugPrint(
      'Firebase init: projectId=${opts.projectId} appId=${opts.appId} '
      'iosBundleId=${opts.iosBundleId ?? ''}',
    );
  }
}

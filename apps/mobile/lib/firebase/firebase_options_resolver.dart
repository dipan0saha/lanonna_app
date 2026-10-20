import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;

import '../config/app_config.dart';
import 'firebase_options_dev.dart';
import 'firebase_options_prod.dart';

/// Resolves [FirebaseOptions] from [AppConfig.environment].
FirebaseOptions resolveFirebaseOptions() {
  switch (AppConfig.environment) {
    case 'prod':
      return ProdFirebaseOptions.currentPlatform;
    case 'dev':
    default:
      return DevFirebaseOptions.currentPlatform;
  }
}

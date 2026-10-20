import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Placeholder until prod Firebase apps exist and `flutterfire configure` runs.
///
/// Replace this file with generated output for the prod Firebase project.
class ProdFirebaseOptions {
  static const String _configureMessage =
      'Prod Firebase is not configured. Create the prod Firebase project, '
      'register Android/iOS apps, then run `flutterfire configure` from '
      'apps/mobile and commit the generated prod options.';

  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError('Web is not configured for La Nonna yet.');
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.iOS:
        throw UnsupportedError(_configureMessage);
      case TargetPlatform.macOS:
        throw UnsupportedError('macOS is not configured for La Nonna yet.');
      case TargetPlatform.windows:
        throw UnsupportedError('Windows is not configured for La Nonna yet.');
      case TargetPlatform.linux:
        throw UnsupportedError('Linux is not configured for La Nonna yet.');
      default:
        throw UnsupportedError(
          'ProdFirebaseOptions are not supported for this platform.',
        );
    }
  }
}

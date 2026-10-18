import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';

import 'bootstrap.dart';
import 'core/app_check/app_check_bootstrap.dart';
import 'core/data/parallel_requests.dart';
import 'core/theme/bundled_font_licenses.dart';
import 'firebase_options.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

/// Start-up runs independent steps together; the native launch screen stays
/// up until [runApp] draws the first frame.
///
/// 1. Firebase, together with the portrait lock.
/// 2. App Check activation, together with [bootstrapLaNonnaApp] (local
///    storage, connectivity, cold-start link). Neither makes a network call;
///    API requests wait for activation through the token source.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  registerBundledFontLicenses();
  const maestroSemantics =
      kDebugMode || bool.fromEnvironment('MAESTRO_SEMANTICS');
  if (maestroSemantics) {
    SemanticsBinding.instance.ensureSemantics();
  }
  await waitBoth(
    Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform),
    _lockPortraitOnAndroid(),
  );
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  final appCheck = startFirebaseAppCheck();
  final (_, app) = await waitBoth(
    appCheck.activated,
    bootstrapLaNonnaApp(appCheck: appCheck),
  );
  runApp(app);
}

Future<void> _lockPortraitOnAndroid() async {
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  }
}

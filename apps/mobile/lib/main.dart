import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import 'bootstrap.dart';
import 'config/prod_config_guard.dart';
import 'core/app_check/app_check_bootstrap.dart';
import 'core/data/parallel_requests.dart';
import 'core/theme/app_fonts.dart';
import 'firebase/firebase_options_resolver.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: resolveFirebaseOptions());
}

/// Start-up runs independent steps together; the native launch screen stays
/// up until [runApp] draws the first frame.
///
/// 1. Firebase. Android portrait is declared on `MainActivity` in the
///    manifest, so no orientation request is needed here.
/// 2. App Check activation, together with [bootstrapLaNonnaApp] (local
///    storage, connectivity, cold-start link) and the bundled brand fonts
///    ([AppFonts.preload]). Signed-in users start an App Check prefetch here
///    so attestation overlaps bootstrap. API requests wait for activation
///    through the token source.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  AppFonts.configure();
  final fonts = AppFonts.preload();
  const maestroSemantics =
      kDebugMode || bool.fromEnvironment('MAESTRO_SEMANTICS');
  if (maestroSemantics) {
    SemanticsBinding.instance.ensureSemantics();
  }
  ensureProdConfigReady();
  await Firebase.initializeApp(options: resolveFirebaseOptions());
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  final appCheck = startFirebaseAppCheck();
  if (FirebaseAuth.instance.currentUser != null) {
    appCheck.prefetch();
  }
  final (_, app, _) = await waitAll3(
    appCheck.activated,
    bootstrapLaNonnaApp(appCheck: appCheck),
    fonts,
  );
  runApp(app);
}

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import 'bootstrap.dart';
import 'core/app_check/app_check_bootstrap.dart';
import 'firebase_options.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const maestroSemantics =
      kDebugMode || bool.fromEnvironment('MAESTRO_SEMANTICS');
  if (maestroSemantics) {
    SemanticsBinding.instance.ensureSemantics();
  }
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await activateFirebaseAppCheck();
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  final app = await bootstrapLaNonnaApp();
  runApp(app);
}

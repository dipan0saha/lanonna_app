import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'bootstrap.dart';
import 'core/router/app_router.dart';
import 'core/router/router_refresh.dart';
import 'core/theme/app_theme.dart';
import 'firebase_options.dart';

Future<void> _maybeDevAutoSignIn() async {
  if (!kDebugMode) return;
  const email = String.fromEnvironment('DEV_AUTO_SIGN_IN_EMAIL');
  const password = String.fromEnvironment('DEV_AUTO_SIGN_IN_PASSWORD');
  if (email.isEmpty || password.isEmpty) return;
  if (FirebaseAuth.instance.currentUser != null) return;
  await FirebaseAuth.instance.signInWithEmailAndPassword(
    email: email,
    password: password,
  );
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await _maybeDevAutoSignIn();
  final app = await bootstrapLaNonnaApp();
  runApp(app);
}

class LaNonnaApp extends StatefulWidget {
  const LaNonnaApp({super.key, required this.routerRefresh});

  final RouterRefreshListenable routerRefresh;

  @override
  State<LaNonnaApp> createState() => _LaNonnaAppState();
}

class _LaNonnaAppState extends State<LaNonnaApp> {
  late final GoRouter _router = createAppRouter(widget.routerRefresh);

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'La Nonna',
      theme: AppTheme.light,
      themeMode: ThemeMode.light,
      routerConfig: _router,
    );
  }
}

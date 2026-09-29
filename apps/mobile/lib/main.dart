import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const LaNonnaApp());
}

class LaNonnaApp extends StatefulWidget {
  const LaNonnaApp({super.key});

  @override
  State<LaNonnaApp> createState() => _LaNonnaAppState();
}

class _LaNonnaAppState extends State<LaNonnaApp> {
  late final GoRouter _router = createAppRouter();

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

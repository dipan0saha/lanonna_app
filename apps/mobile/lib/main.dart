import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:lanonna/l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'bootstrap.dart';
import 'core/app_check/app_check_bootstrap.dart';
import 'core/notifications/push_notification_service.dart';
import 'features/account/data/notifications_repository.dart';
import 'core/auth/auth_repository.dart';
import 'core/deep_links/app_link_bootstrap.dart';
import 'core/router/app_router.dart';
import 'core/router/deep_link_navigation.dart';
import 'features/onboarding/domain/onboarding_routes.dart';
import 'core/router/router_refresh.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/app_offline_wrapper.dart';
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

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await activateFirebaseAppCheck();
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  await _maybeDevAutoSignIn();
  final app = await bootstrapLaNonnaApp();
  runApp(app);
}

class LaNonnaApp extends StatefulWidget {
  const LaNonnaApp({
    super.key,
    required this.routerRefresh,
    this.initialInviteLocation,
  });

  final RouterRefreshListenable routerRefresh;
  final String? initialInviteLocation;

  @override
  State<LaNonnaApp> createState() => _LaNonnaAppState();
}

class _LaNonnaAppState extends State<LaNonnaApp> {
  late final GoRouter _router = createAppRouter(
    widget.routerRefresh,
    initialLocation: widget.initialInviteLocation,
  );
  PushNotificationService? _pushService;
  var _pushStarted = false;
  StreamSubscription<String>? _inviteLinkSub;

  @override
  void initState() {
    super.initState();
    _inviteLinkSub = watchInviteAppLinks().listen(_onInviteAppLink);
  }

  void _onInviteAppLink(String location) {
    if (!mounted) return;
    final current = _router.routerDelegate.currentConfiguration.uri;
    if (current.path == OnboardingRoutes.inviteAccept &&
        current.queryParameters['token'] ==
            Uri.parse(location).queryParameters['token']) {
      return;
    }
    _router.go(location);
  }

  @override
  void dispose() {
    _inviteLinkSub?.cancel();
    _pushService?.dispose();
    super.dispose();
  }

  void _ensurePush(BuildContext context) {
    if (_pushStarted || kIsWeb) return;
    _pushStarted = true;
    _pushService = PushNotificationService(
      context.read<NotificationsRepository>(),
    );
    _pushService!.start(
      authStateChanges: context.read<AuthRepository>().authStateChanges(),
      onDeepLink: (link) {
        final path = normalizeAppDeepLinkPath(link);
        if (path != null) _router.push(path);
      },
      context: context,
    );
  }

  @override
  Widget build(BuildContext context) {
    _ensurePush(context);
    return MaterialApp.router(
      title: 'La Nonna',
      theme: AppTheme.light,
      themeMode: ThemeMode.light,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: _router,
      builder: (context, child) => AppOfflineWrapper(
        child: child ?? const SizedBox.shrink(),
      ),
    );
  }
}

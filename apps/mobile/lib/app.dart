import 'dart:async';
import 'core/auth/auth_email_verification.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:lanonna/l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'core/auth/auth_repository.dart';
import 'core/auth/biometric_app_lock.dart';
import 'core/auth/email_verification_link_handler.dart';
import 'core/deep_links/app_link_bootstrap.dart';
import 'core/deep_links/auth_action_app_link.dart';
import 'core/deep_links/invite_app_link.dart';
import 'core/notifications/push_notification_service.dart';
import 'core/router/app_router.dart';
import 'core/router/deep_link_navigation.dart';
import 'core/router/router_refresh.dart';
import 'core/theme/app_theme.dart';
import 'core/version/app_version_gate.dart';
import 'core/shell/app_shell_ui.dart';
import 'core/widgets/app_offline_wrapper.dart';
import 'features/onboarding/domain/onboarding_routes.dart';
import 'features/onboarding/presentation/onboarding_coordinator.dart';

class LaNonnaApp extends StatefulWidget {
  const LaNonnaApp({
    super.key,
    required this.routerRefresh,
    this.initialInviteLocation,
    this.initialEmailVerifyUri,
    this.signedInOnLaunch = false,
  });

  final RouterRefreshListenable routerRefresh;
  final String? initialInviteLocation;
  final Uri? initialEmailVerifyUri;
  final bool signedInOnLaunch;

  @override
  State<LaNonnaApp> createState() => _LaNonnaAppState();
}

class _LaNonnaAppState extends State<LaNonnaApp> {
  late final GoRouter _router = createAppRouter(
    widget.routerRefresh,
    initialLocation: widget.initialInviteLocation,
    signedInOnLaunch: widget.signedInOnLaunch,
  );
  var _pushStarted = false;
  PushNotificationService? _pushService;
  StreamSubscription<Uri>? _appLinkSub;

  @override
  void initState() {
    super.initState();
    _appLinkSub = watchAppLinkUris().listen(_onAppLinkUri);
    final initialVerify = widget.initialEmailVerifyUri;
    if (initialVerify != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _handleEmailVerificationLink(initialVerify);
      });
    }
  }

  void _onAppLinkUri(Uri uri) {
    if (!mounted) return;
    if (parseEmailVerifyActionLink(uri) != null) {
      _handleEmailVerificationLink(uri);
      return;
    }
    final location = inviteAppLinkToRouterLocation(uri);
    if (location == null) return;
    // Post-frame so a link that arrives during create-baby's build is not dropped.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final current = _router.routerDelegate.currentConfiguration.uri;
      if (current.path == OnboardingRoutes.inviteAccept &&
          current.queryParameters['token'] ==
              Uri.parse(location).queryParameters['token']) {
        return;
      }
      _router.go(location);
    });
  }

  Future<void> _handleEmailVerificationLink(Uri uri) async {
    if (!mounted) return;
    await handleEmailVerificationLink(
      authRepository: context.read<AuthRepository>(),
      coordinator: context.read<OnboardingCoordinator>(),
      router: _router,
      uri: uri,
    );
  }

  @override
  void dispose() {
    _appLinkSub?.cancel();
    _pushService?.dispose();
    widget.routerRefresh.dispose();
    super.dispose();
  }

  void _ensurePush(BuildContext context) {
    if (_pushStarted || kIsWeb) return;
    _pushStarted = true;
    _pushService = context.read<PushNotificationService>();
    _pushService!.start(
      authStateChanges: context.read<AuthRepository>().authStateChanges(),
      onDeepLink: (link, babyProfileId) {
        final ctx = appRootNavigatorKey.currentContext;
        if (ctx == null) return;
        navigateAppDeepLink(ctx, link, babyProfileId: babyProfileId);
      },
      context: context,
    );
  }

  @override
  Widget build(BuildContext context) {
    _ensurePush(context);
    return MaterialApp.router(
      scaffoldMessengerKey: rootScaffoldMessengerKey,
      onGenerateTitle: (context) => AppLocalizations.of(context)!.appTitle,
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
      builder: (context, child) => AppVersionGate(
        child: AppOfflineWrapper(
          child: BiometricAppLock(
            router: _router,
            child: child ?? const SizedBox.shrink(),
          ),
        ),
      ),
    );
  }
}

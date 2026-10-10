import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:lanonna/l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'core/auth/auth_repository.dart';
import 'core/auth/email_verify_link_result.dart';
import 'core/deep_links/app_link_bootstrap.dart';
import 'core/deep_links/auth_action_app_link.dart';
import 'core/deep_links/invite_app_link.dart';
import 'core/notifications/push_notification_service.dart';
import 'core/router/app_router.dart';
import 'core/router/deep_link_navigation.dart';
import 'core/router/router_refresh.dart';
import 'core/theme/app_theme.dart';
import 'core/version/app_version_gate.dart';
import 'core/widgets/app_offline_wrapper.dart';
import 'core/widgets/app_snackbar.dart';
import 'features/account/data/notifications_repository.dart';
import 'features/onboarding/domain/onboarding_routes.dart';
import 'features/onboarding/domain/onboarding_step.dart';
import 'features/onboarding/presentation/onboarding_coordinator.dart';

class LaNonnaApp extends StatefulWidget {
  const LaNonnaApp({
    super.key,
    required this.routerRefresh,
    this.initialInviteLocation,
    this.initialEmailVerifyUri,
  });

  final RouterRefreshListenable routerRefresh;
  final String? initialInviteLocation;
  final Uri? initialEmailVerifyUri;

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
    final current = _router.routerDelegate.currentConfiguration.uri;
    if (current.path == OnboardingRoutes.inviteAccept &&
        current.queryParameters['token'] ==
            Uri.parse(location).queryParameters['token']) {
      return;
    }
    _router.go(location);
  }

  Future<void> _handleEmailVerificationLink(Uri uri) async {
    if (!mounted) return;
    final authRepo = context.read<AuthRepository>();
    final result = await authRepo.applyEmailVerificationLink(uri);
    if (!mounted) return;

    final messenger = ScaffoldMessenger.maybeOf(context);
    switch (result.outcome) {
      case EmailVerifyLinkOutcome.success:
      case EmailVerifyLinkOutcome.alreadyVerified:
        await authRepo.refreshSessionClaims();
        if (!mounted) return;
        final coordinator = context.read<OnboardingCoordinator>();
        await coordinator.setStep(OnboardingStep.completeProfile);
        if (!mounted) return;
        _router.go(OnboardingRoutes.completeProfile);
        if (result.message != null) {
          AppSnackBar.showInfoWithMessenger(messenger, result.message!);
        }
      case EmailVerifyLinkOutcome.noSignedInUser:
        _router.go(OnboardingRoutes.login);
        AppSnackBar.showAlertWithMessenger(
          messenger,
          result.message ??
              'Email verified. Sign in with the same address to continue.',
        );
      case EmailVerifyLinkOutcome.invalidOrExpired:
      case EmailVerifyLinkOutcome.wrongMode:
        AppSnackBar.showAlertWithMessenger(
          messenger,
          result.message ?? 'Could not verify your email from this link.',
        );
    }
  }

  @override
  void dispose() {
    _appLinkSub?.cancel();
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
      builder: (context, child) => AppVersionGate(
        child: AppOfflineWrapper(
          child: child ?? const SizedBox.shrink(),
        ),
      ),
    );
  }
}

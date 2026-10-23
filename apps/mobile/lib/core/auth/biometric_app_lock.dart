import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:go_router/go_router.dart';
import 'package:lanonna/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

import '../../features/account/data/account_repository.dart';
import '../../features/onboarding/domain/onboarding_routes.dart';
import '../../features/onboarding/presentation/app_session.dart';
import '../theme/app_colors.dart';
import '../time/monotonic_clock.dart';
import 'auth_repository.dart';
import 'biometric_app_lock_policy.dart';
import 'biometric_sign_in_service.dart';
import 'biometric_unlock_service.dart';
import 'session_cleanup.dart';

/// Full-screen lock when the user returns with biometric unlock enabled.
class BiometricAppLock extends StatefulWidget {
  const BiometricAppLock({
    super.key,
    required this.router,
    required this.child,
    this.biometricService,
    this.monotonicClock,
  });

  final GoRouter router;
  final Widget child;
  final BiometricUnlockService? biometricService;
  final MonotonicClock? monotonicClock;

  @override
  State<BiometricAppLock> createState() => _BiometricAppLockState();
}

class _BiometricAppLockState extends State<BiometricAppLock>
    with WidgetsBindingObserver {
  late final BiometricUnlockService _biometricService =
      widget.biometricService ?? BiometricUnlockService();
  late final MonotonicClock _monotonicClock =
      widget.monotonicClock ?? SystemMonotonicClock();
  var _locked = false;

  /// Monotonic time the app went to the background while a resume lock was
  /// owed; null when resume must not lock.
  Duration? _backgroundedAt;
  var _unlockInProgress = false;
  var _coldStartLockCompleted = false;
  AccountProfileUpdates? _profileUpdates;
  AppSession? _session;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.router.routerDelegate.addListener(_onRouterChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _hydrateAccountIfNeeded().then((_) => _tryColdStartLock());
    });
  }

  @override
  void didUpdateWidget(BiometricAppLock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.router != widget.router) {
      oldWidget.router.routerDelegate.removeListener(_onRouterChanged);
      widget.router.routerDelegate.addListener(_onRouterChanged);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final session = context.read<AppSession>();
    if (_session != session) {
      _session?.removeListener(_onSessionChanged);
      _session = session;
      session.addListener(_onSessionChanged);
    }
    final updates = context.read<AccountRepository>().profileUpdates;
    if (_profileUpdates != updates) {
      _profileUpdates?.removeListener(_onProfileUpdated);
      _profileUpdates = updates;
      updates.addListener(_onProfileUpdated);
    }
  }

  /// A profile save never locks the app (turning the setting on in Settings,
  /// or the first save after signing in); it only releases the lock when the
  /// setting was turned off. Locking happens on cold start and resume. A
  /// pending cold-start evaluation may still settle here once the profile
  /// (and so the setting) is first known.
  void _onProfileUpdated() {
    if (_locked && !_wouldEngageLock()) {
      setState(() => _locked = false);
    }
    _tryColdStartLock();
  }

  void _onRouterChanged() {
    _tryColdStartLock();
  }

  void _onSessionChanged() {
    _tryColdStartLock();
  }

  @override
  void dispose() {
    _profileUpdates?.removeListener(_onProfileUpdated);
    _session?.removeListener(_onSessionChanged);
    widget.router.routerDelegate.removeListener(_onRouterChanged);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  String _currentPath() {
    final path = widget.router.routerDelegate.currentConfiguration.uri.path;
    return path.isEmpty ? '/' : path;
  }

  /// Locks when the app actually leaves the screen: [AppLifecycleState.paused]
  /// is only reached on the way into the background (the way back passes
  /// through hidden and inactive). [AppLifecycleState.inactive] alone is a
  /// focus loss (notification shade, permission dialog, or the biometric
  /// prompt itself) and must not lock, or unlocking would re-lock the app.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
        if (!_locked && !_unlockInProgress) {
          _backgroundedAt = _wouldEngageLock() ? _monotonicClock.elapsed : null;
        }
      case AppLifecycleState.resumed:
        final backgroundedAt = _backgroundedAt;
        _backgroundedAt = null;
        if (backgroundedAt != null &&
            biometricAppLockShouldEngageOnResume(
              timeInBackground: _monotonicClock.elapsed - backgroundedAt,
            )) {
          _engageLock();
        }
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        break;
    }
  }

  bool _wouldEngageLock() {
    final auth = context.read<AuthRepository>();
    final session = context.read<AppSession>();
    final accountRepo = context.read<AccountRepository>();
    final account = accountRepo.cachedAccount;
    final location = _currentPath();
    final unlockActive = account != null
        ? context.read<BiometricSignInService>().isUnlockActiveForSignedInUser(
            serverBiometricUnlockEnabled: account.biometricUnlockEnabled,
          )
        : false;
    return biometricAppLockShouldEngage(
      isSignedIn: auth.currentUser != null,
      canAccessMainApp: session.canAccessMainApp,
      isOnboardingPath: OnboardingRoutes.isOnboardingPath(location),
      biometricUnlockEnabled: unlockActive,
    );
  }

  Future<void> _hydrateAccountIfNeeded() async {
    if (!mounted) return;
    if (context.read<AuthRepository>().currentUser == null) return;
    final repo = context.read<AccountRepository>();
    if (repo.cachedAccount != null) return;
    try {
      await repo.ensureAccountLoaded();
    } catch (_) {
      // Evaluation stays pending until a later profile load publishes.
    }
  }

  /// True when cold-start evaluation has enough data to decide. A signed-in
  /// launch waits for the profile (the setting) and a loaded onboarding
  /// status; with main-app access it also waits for the redirect off the
  /// onboarding routes, so the lock never shows on a sign-in screen.
  bool _isColdStartEvaluationSettled() {
    final auth = context.read<AuthRepository>();
    if (auth.currentUser == null) return true;
    final session = context.read<AppSession>();
    if (session.statusPhase != OnboardingStatusPhase.loaded) return false;
    if (!session.canAccessMainApp) return true;
    if (context.read<AccountRepository>().cachedAccount == null) return false;
    return !OnboardingRoutes.isOnboardingPath(_currentPath());
  }

  /// Cold start: lock once when a signed-in session opens with the setting on.
  void _tryColdStartLock() {
    if (_coldStartLockCompleted || !mounted) return;
    if (!_isColdStartEvaluationSettled()) return;
    _coldStartLockCompleted = true;
    _engageLock();
  }

  void _engageLock() {
    if (!mounted || !_wouldEngageLock()) return;
    // Router and session listeners can fire while the tree is building (the
    // initial route parse); apply the lock right after that frame instead.
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      SchedulerBinding.instance.addPostFrameCallback((_) => _engageLock());
      return;
    }
    if (_locked) return;
    setState(() => _locked = true);
    _attemptUnlock();
  }

  Future<void> _attemptUnlock() async {
    if (_unlockInProgress || !mounted) return;
    _unlockInProgress = true;
    final l10n = AppLocalizations.of(context)!;
    final ok = await _biometricService.authenticate(
      reason: l10n.biometricUnlockReason,
    );
    _unlockInProgress = false;
    if (!mounted) return;
    if (ok) {
      setState(() => _locked = false);
    }
  }

  Future<void> _signOutFromLock() async {
    await context.read<SessionCleanup>().clearLocalUserData();
    if (!mounted) return;
    await context.read<AuthRepository>().signOut();
    if (!mounted) return;
    setState(() => _locked = false);
    widget.router.go(OnboardingRoutes.ownerCarousel);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        if (_locked) ...[
          const ModalBarrier(dismissible: false, color: AppColors.background),
          _LockOverlay(onRetry: _attemptUnlock, onSignOut: _signOutFromLock),
        ],
      ],
    );
  }
}

class _LockOverlay extends StatelessWidget {
  const _LockOverlay({required this.onRetry, required this.onSignOut});

  final VoidCallback onRetry;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Material(
      color: AppColors.background,
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.lock_outline,
                  size: 48,
                  color: AppColors.textPrimary,
                ),
                const SizedBox(height: 16),
                Text(
                  l10n.biometricUnlockTitle,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: onRetry,
                  child: Text(l10n.biometricUnlockRetry),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: onSignOut,
                  child: Text(l10n.biometricUnlockSignOut),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

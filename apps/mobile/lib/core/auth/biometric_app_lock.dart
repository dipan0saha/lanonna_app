import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lanonna/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

import '../../features/account/data/account_repository.dart';
import '../../features/onboarding/domain/onboarding_routes.dart';
import '../../features/onboarding/presentation/app_session.dart';
import '../theme/app_colors.dart';
import 'auth_repository.dart';
import 'biometric_app_lock_policy.dart';
import 'biometric_unlock_service.dart';
import 'session_cleanup.dart';

/// Full-screen lock when the user returns with biometric unlock enabled.
class BiometricAppLock extends StatefulWidget {
  const BiometricAppLock({
    super.key,
    required this.router,
    required this.child,
    this.biometricService,
  });

  final GoRouter router;
  final Widget child;
  final BiometricUnlockService? biometricService;

  @override
  State<BiometricAppLock> createState() => _BiometricAppLockState();
}

class _BiometricAppLockState extends State<BiometricAppLock>
    with WidgetsBindingObserver {
  late final BiometricUnlockService _biometricService =
      widget.biometricService ?? BiometricUnlockService();
  var _locked = false;
  var _lockOnResume = false;
  var _unlockInProgress = false;
  var _accountHydrated = false;
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
  /// setting was turned off. Locking happens on cold start and resume.
  void _onProfileUpdated() {
    if (_locked && !_wouldEngageLock()) {
      setState(() => _locked = false);
    }
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
    final path =
        widget.router.routerDelegate.currentConfiguration.uri.path;
    return path.isEmpty ? '/' : path;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      _lockOnResume = _wouldEngageLock();
      return;
    }
    if (state == AppLifecycleState.resumed && _lockOnResume) {
      _lockOnResume = false;
      _engageLock();
    }
  }

  bool _wouldEngageLock() {
    final auth = context.read<AuthRepository>();
    final session = context.read<AppSession>();
    final account = context.read<AccountRepository>().cachedAccount;
    final location = _currentPath();
    return biometricAppLockShouldEngage(
      isSignedIn: auth.currentUser != null,
      canAccessMainApp: session.canAccessMainApp,
      isOnboardingPath: OnboardingRoutes.isOnboardingPath(location),
      biometricUnlockEnabled: account?.biometricUnlockEnabled ?? false,
    );
  }

  Future<void> _hydrateAccountIfNeeded() async {
    if (_accountHydrated) return;
    final auth = context.read<AuthRepository>();
    if (auth.currentUser == null) {
      _accountHydrated = true;
      return;
    }
    final repo = context.read<AccountRepository>();
    if (repo.cachedAccount != null) {
      _accountHydrated = true;
      return;
    }
    try {
      await repo.ensureAccountLoaded();
    } catch (_) {
      // Lock stays off when profile flag is unknown.
    } finally {
      _accountHydrated = true;
    }
  }

  /// True when cold-start evaluation has enough data and is not waiting on a
  /// redirect from an onboarding route into the main app.
  bool _isColdStartEvaluationSettled() {
    final auth = context.read<AuthRepository>();
    if (auth.currentUser == null) return true;
    if (!_accountHydrated) return false;
    final session = context.read<AppSession>();
    if (session.statusPhase == OnboardingStatusPhase.unknown) return false;
    if (OnboardingRoutes.isOnboardingPath(_currentPath())) return false;
    return true;
  }

  /// Cold start: lock once when a signed-in session opens with the setting on.
  void _tryColdStartLock() {
    if (_coldStartLockCompleted || !mounted) return;
    if (!_isColdStartEvaluationSettled()) return;
    _coldStartLockCompleted = true;
    _engageLock();
  }

  void _engageLock() {
    if (!_wouldEngageLock()) return;
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
    context.watch<AppSession>();

    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        if (_locked) ...[
          const ModalBarrier(dismissible: false, color: AppColors.background),
          _LockOverlay(
            onRetry: _attemptUnlock,
            onSignOut: _signOutFromLock,
          ),
        ],
      ],
    );
  }
}

class _LockOverlay extends StatelessWidget {
  const _LockOverlay({
    required this.onRetry,
    required this.onSignOut,
  });

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

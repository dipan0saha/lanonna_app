import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lanonna/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

import '../../features/account/data/account_repository.dart';
import '../../features/onboarding/domain/onboarding_routes.dart';
import '../../features/onboarding/presentation/app_session.dart';
import '../router/app_router.dart';
import '../theme/app_colors.dart';
import 'auth_repository.dart';
import 'biometric_app_lock_policy.dart';
import 'biometric_unlock_service.dart';
import 'session_cleanup.dart';

/// Full-screen lock when the user returns with biometric unlock enabled.
class BiometricAppLock extends StatefulWidget {
  const BiometricAppLock({
    super.key,
    required this.child,
    this.biometricService,
  });

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
  AccountProfileUpdates? _profileUpdates;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _hydrateAccountIfNeeded().then((_) => _evaluateLock(coldStart: true));
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final updates = context.read<AccountRepository>().profileUpdates;
    if (_profileUpdates != updates) {
      _profileUpdates?.removeListener(_onProfileUpdated);
      _profileUpdates = updates;
      updates.addListener(_onProfileUpdated);
    }
  }

  void _onProfileUpdated() {
    if (!_locked) {
      _evaluateLock(coldStart: false);
    }
  }

  @override
  void dispose() {
    _profileUpdates?.removeListener(_onProfileUpdated);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  String _currentPath() {
    final ctx = appRootNavigatorKey.currentContext;
    if (ctx != null) {
      return GoRouterState.of(ctx).uri.path;
    }
    return '/';
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
    if (auth.currentUser == null) return;
    final repo = context.read<AccountRepository>();
    if (repo.cachedAccount != null) {
      _accountHydrated = true;
      return;
    }
    try {
      await repo.fetchAccount();
    } catch (_) {
      // Lock stays off when profile flag is unknown.
    } finally {
      _accountHydrated = true;
    }
  }

  Future<void> _evaluateLock({required bool coldStart}) async {
    if (!mounted) return;
    if (!_wouldEngageLock()) {
      if (_locked) setState(() => _locked = false);
      return;
    }
    if (coldStart || !_locked) {
      _engageLock();
    }
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
    context.go(OnboardingRoutes.ownerCarousel);
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

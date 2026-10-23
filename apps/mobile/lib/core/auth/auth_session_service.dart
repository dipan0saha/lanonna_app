import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../notifications/push_notification_service.dart';
import 'auth_repository.dart';
import 'biometric_sign_in_service.dart';
import 'session_cleanup.dart';

/// The single place that ends a signed-in session on this device.
///
/// Every sign-out path goes through [signOut] or [signOutDeletedAccount], so
/// the order is the same everywhere: server-side cleanup that needs the
/// Firebase session first, then local user data, then Firebase sign-out.
class AuthSessionService {
  AuthSessionService({
    required AuthRepository authRepository,
    required SessionCleanup sessionCleanup,
    BiometricSignInService? biometricSignInService,
    PushNotificationService? pushNotificationService,
    Duration pushUnregisterTimeout = const Duration(seconds: 3),
  })  : _authRepository = authRepository,
        _sessionCleanup = sessionCleanup,
        _biometricSignInService = biometricSignInService,
        _pushNotificationService = pushNotificationService,
        _pushUnregisterTimeout = pushUnregisterTimeout;

  final AuthRepository _authRepository;
  final SessionCleanup _sessionCleanup;
  final BiometricSignInService? _biometricSignInService;
  final PushNotificationService? _pushNotificationService;
  final Duration _pushUnregisterTimeout;
  StreamSubscription<User?>? _userScopeSub;

  /// Account switch without [signOut]: Firebase reports a different signed-in
  /// uid (signing in from an onboarding screen that a signed-in user can
  /// still reach, or biometric sign-in into another account, #400).
  ///
  /// Runs the same local cleanup as [signOut] (no server call: the previous
  /// account's ID token is gone, and the push token is re-registered to the
  /// new account by [PushNotificationService]), then [onUserSwitched] for the
  /// new account's startup reads. Signing in from signed out needs nothing
  /// here: [signOut] already cleared local data.
  void bindUserScopedSession({
    required Stream<User?> authStateChanges,
    required Future<void> Function() onUserSwitched,
  }) {
    _userScopeSub?.cancel();
    var boundUid = _authRepository.currentUser?.uid;
    _userScopeSub = authStateChanges.listen((user) async {
      final previousUid = boundUid;
      final uid = user?.uid;
      boundUid = uid;
      if (previousUid == null || uid == null || previousUid == uid) return;
      try {
        await _sessionCleanup.clearLocalUserData();
        await onUserSwitched();
      } catch (e) {
        debugPrint('account_switch_cleanup_failed: $e');
      }
    });
  }

  /// Normal logout (account screen, app lock, account switch).
  ///
  /// Removes this device's push token from the server, bounded by
  /// [_pushUnregisterTimeout] so a slow or offline network never holds up
  /// sign-out. Keeps this install's biometric sign-in enrollment: biometric
  /// sign-in is meant to survive logout.
  Future<void> signOut() async {
    await _unregisterPushBestEffort();
    await _endLocalSession();
  }

  /// The account no longer exists (deleted here, or reported deleted by the
  /// API). The server already dropped its device tokens and biometric
  /// credentials, so no authenticated call is made (it would only fail with
  /// `user_deleted`). Forgets this install's biometric enrollment for that
  /// account, then ends the session.
  Future<void> signOutDeletedAccount() async {
    final biometric = _biometricSignInService;
    final uid = _authRepository.currentUser?.uid;
    if (biometric != null &&
        uid != null &&
        biometric.enrollment?.firebaseUid == uid) {
      await biometric.clearLocalEnrollment();
    }
    await _endLocalSession();
  }

  Future<void> _endLocalSession() async {
    await _sessionCleanup.clearLocalUserData();
    await _authRepository.signOut();
  }

  Future<void> _unregisterPushBestEffort() async {
    final push = _pushNotificationService;
    if (push == null) return;
    try {
      await push.unregisterFromServer().timeout(_pushUnregisterTimeout);
    } catch (e) {
      debugPrint('push_unregister_before_sign_out_failed: $e');
    }
  }
}

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../notifications/push_notification_service.dart';
import 'auth_repository.dart';
import 'session_cleanup.dart';

/// Single entry point for ending the Firebase session and wiping local user state.
class AuthSessionService {
  AuthSessionService({
    required AuthRepository authRepository,
    required SessionCleanup sessionCleanup,
    PushNotificationService? pushNotificationService,
    Duration pushUnregisterTimeout = const Duration(seconds: 3),
  })  : _authRepository = authRepository,
        _sessionCleanup = sessionCleanup,
        _pushNotificationService = pushNotificationService,
        _pushUnregisterTimeout = pushUnregisterTimeout;

  final AuthRepository _authRepository;
  final SessionCleanup _sessionCleanup;
  final PushNotificationService? _pushNotificationService;
  final Duration _pushUnregisterTimeout;

  /// Unregister push while authenticated, clear local caches, then sign out of Firebase.
  Future<void> signOut() async {
    await _unregisterPushBestEffort();
    await _sessionCleanup.clearLocalUserData();
    await _authRepository.signOut();
  }

  Future<void> _unregisterPushBestEffort() async {
    final push = _pushNotificationService;
    if (push == null) return;
    try {
      await push.unregisterBeforeSignOut().timeout(_pushUnregisterTimeout);
    } catch (e, st) {
      debugPrint('push_unregister_before_sign_out_failed: $e');
      assert(() {
        debugPrint('$st');
        return true;
      }());
    }
  }
}

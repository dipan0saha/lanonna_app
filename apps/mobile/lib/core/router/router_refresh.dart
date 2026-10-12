import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

import '../../features/onboarding/presentation/app_session.dart';
import '../../features/onboarding/presentation/onboarding_coordinator.dart';
import '../auth/auth_repository.dart';

class RouterRefreshListenable extends ChangeNotifier {
  RouterRefreshListenable({
    required AuthRepository authRepository,
    required OnboardingCoordinator coordinator,
    required AppSession session,
  }) : _coordinator = coordinator,
       _session = session {
    _onRefresh = _scheduleRefresh;
    _authSub = authRepository.authStateChanges().listen((_) => _scheduleRefresh());
    coordinator.addListener(_onRefresh!);
    session.addListener(_onRefresh!);
  }

  final OnboardingCoordinator _coordinator;
  final AppSession _session;
  StreamSubscription<dynamic>? _authSub;
  VoidCallback? _onRefresh;
  bool _refreshScheduled = false;

  /// Coalesce coordinator/session/auth updates so GoRouter does not redirect
  /// while a route widget (e.g. onboarding [Form]) is still building.
  void _scheduleRefresh() {
    if (_refreshScheduled) return;
    _refreshScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _refreshScheduled = false;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    final onRefresh = _onRefresh;
    if (onRefresh != null) {
      _coordinator.removeListener(onRefresh);
      _session.removeListener(onRefresh);
    }
    super.dispose();
  }
}

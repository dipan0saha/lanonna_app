import 'dart:async';

import 'package:flutter/foundation.dart';

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
    _onRefresh = notifyListeners;
    _authSub = authRepository.authStateChanges().listen((_) => notifyListeners());
    coordinator.addListener(_onRefresh!);
    session.addListener(_onRefresh!);
  }

  final OnboardingCoordinator _coordinator;
  final AppSession _session;
  StreamSubscription<dynamic>? _authSub;
  VoidCallback? _onRefresh;

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

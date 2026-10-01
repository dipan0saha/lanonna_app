import 'package:flutter/foundation.dart';

import '../../features/onboarding/presentation/app_session.dart';
import '../../features/onboarding/presentation/onboarding_coordinator.dart';
import '../auth/auth_repository.dart';

class RouterRefreshListenable extends ChangeNotifier {
  RouterRefreshListenable({
    required AuthRepository authRepository,
    required OnboardingCoordinator coordinator,
    required AppSession session,
  }) {
    authRepository.authStateChanges().listen((_) => notifyListeners());
    coordinator.addListener(notifyListeners);
    session.addListener(notifyListeners);
  }
}

import 'package:go_router/go_router.dart';

import '../../features/onboarding/domain/onboarding_routes.dart';
import '../../features/onboarding/presentation/onboarding_coordinator.dart';
import '../api/api_exception.dart';
import '../router/app_router.dart';
import 'auth_repository.dart';

/// Signs out locally and routes to login when the API reports a deleted account.
Future<void> handleUserDeletedSession({
  required AuthRepository authRepository,
  required OnboardingCoordinator coordinator,
  ApiException? exception,
}) async {
  await authRepository.signOut();
  await coordinator.clearPendingInvite();
  final context = appRootNavigatorKey.currentContext;
  if (context != null && context.mounted) {
    context.go(OnboardingRoutes.login);
  }
}

import 'package:go_router/go_router.dart';

import '../../features/onboarding/domain/onboarding_routes.dart';
import '../api/api_exception.dart';
import '../router/app_router.dart';
import '../widgets/app_snackbar.dart';
import 'auth_repository.dart';
import 'session_cleanup.dart';

var _handlingUserDeleted = false;

/// Signs out locally and routes to login when the API reports a deleted account.
Future<void> handleUserDeletedSession({
  required AuthRepository authRepository,
  required SessionCleanup sessionCleanup,
  ApiException? exception,
}) async {
  if (_handlingUserDeleted) return;
  _handlingUserDeleted = true;
  try {
    await sessionCleanup.clearLocalUserData();
    await authRepository.signOut();
    final context = appRootNavigatorKey.currentContext;
    if (context != null && context.mounted) {
      final message = exception?.message ?? 'This account was deleted.';
      AppSnackBar.showAlert(context, message);
      context.go(OnboardingRoutes.login);
    }
  } finally {
    _handlingUserDeleted = false;
  }
}

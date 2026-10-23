import 'package:go_router/go_router.dart';
import 'package:lanonna/l10n/app_localizations.dart';

import '../../features/onboarding/domain/onboarding_routes.dart';
import '../router/app_router.dart';
import '../widgets/app_snackbar.dart';
import 'auth_session_service.dart';

var _handlingUserDeleted = false;

/// Signs out locally and routes to login when the API reports a deleted account.
Future<void> handleUserDeletedSession({
  required AuthSessionService authSessionService,
}) async {
  if (_handlingUserDeleted) return;
  _handlingUserDeleted = true;
  try {
    await authSessionService.signOut();
    final context = appRootNavigatorKey.currentContext;
    if (context != null && context.mounted) {
      AppSnackBar.showAlert(
        context,
        AppLocalizations.of(context)!.errorAccountDeleted,
      );
      context.go(OnboardingRoutes.login);
    }
  } finally {
    _handlingUserDeleted = false;
  }
}

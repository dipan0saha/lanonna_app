import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:lanonna/l10n/app_localizations.dart';

import '../api/api_error_message.dart';
import '../api/api_exception.dart';
import '../comments/comment_composer_controller.dart';
import '../widgets/app_load_error_pane.dart';
import '../widgets/app_snackbar.dart';

/// Shared loading UX for baby-scoped detail screens (photo, event, etc.).
bool shouldShowDetailFullScreenLoader({
  required bool hasContent,
  required bool initialLoadInFlight,
}) {
  return !hasContent && initialLoadInFlight;
}

/// Routes a failed detail load: a real 404 is "not found", anything else
/// (offline, timeout, 5xx, 403) is retryable and never shown as missing.
///
/// - 404 → [onNotFound] (the screen shows its not-found message and leaves).
///   Screens whose repository already maps 404 to `null` omit it.
/// - Cached detail on screen → snackbar; the content stays.
/// - Nothing to show yet → [onBlockingError] with the mapped message, for an
///   [AppLoadErrorPane] with Try again.
void reportDetailLoadFailure(
  BuildContext context,
  Object error, {
  required bool hasContent,
  VoidCallback? onNotFound,
  required void Function(String message) onBlockingError,
}) {
  if (onNotFound != null && error is ApiException && error.statusCode == 404) {
    onNotFound();
    return;
  }
  final message = apiErrorMessage(AppLocalizations.of(context)!, error);
  if (hasContent) {
    AppSnackBar.showAlert(context, message);
    return;
  }
  onBlockingError(message);
}

/// Push a sub-route, then return focus to the detail screen without the keyboard.
///
/// Unfocus runs before the push and again after every pop (Save and Back).
/// [refresh] runs only when [shouldRefresh] returns true.
Future<T?> pushAndRefresh<T>(
  BuildContext context,
  String location, {
  required CommentComposerController composer,
  required Future<void> Function() refresh,
  bool Function(T? result)? shouldRefresh,
  Object? extra,
}) async {
  composer.unfocus();
  final result = await context.push<T>(location, extra: extra);
  if (!context.mounted) return result;
  composer.unfocus();
  if (shouldRefresh?.call(result) ?? false) {
    await refresh();
  }
  return result;
}

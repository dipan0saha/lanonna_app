import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:lanonna/l10n/app_localizations.dart';

import '../api/api_error_message.dart';
import '../comments/comment_composer_controller.dart';
import '../widgets/app_snackbar.dart';

/// Shared loading UX for baby-scoped detail screens (photo, event, etc.).
bool shouldShowDetailFullScreenLoader({
  required bool hasContent,
  required bool initialLoadInFlight,
}) {
  return !hasContent && initialLoadInFlight;
}

/// Surfaces a failed detail load without treating it as missing content.
///
/// Cached detail stays on screen and the failure is a snackbar. The first
/// load, with nothing to show, records [message] for the error state.
void reportDetailLoadFailure(
  BuildContext context,
  Object error, {
  required bool hasContent,
  required void Function(String message) onBlockingError,
}) {
  final message = apiErrorMessage(AppLocalizations.of(context)!, error);
  if (hasContent) {
    AppSnackBar.showAlert(context, message);
    return;
  }
  onBlockingError(message);
}

/// Blocking error + Try again for baby-scoped detail screens (photo, etc.).
class DetailLoadErrorPane extends StatelessWidget {
  const DetailLoadErrorPane({
    super.key,
    required this.message,
    required this.onRetry,
    this.retryButtonKey = const Key('detail_load_retry'),
  });

  final String message;
  final VoidCallback onRetry;
  final Key retryButtonKey;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(
              key: retryButtonKey,
              onPressed: onRetry,
              child: Text(AppLocalizations.of(context)!.actionTryAgain),
            ),
          ],
        ),
      ),
    );
  }
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

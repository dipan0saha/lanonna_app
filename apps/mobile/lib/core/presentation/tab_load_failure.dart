import 'package:flutter/widgets.dart';
import 'package:lanonna/l10n/app_localizations.dart';

import '../api/api_error_message.dart';
import '../widgets/app_snackbar.dart';

/// Snackbar when pull-to-refresh (or an equivalent reload) fails but content
/// is already on screen.
void reportRefreshFailure(BuildContext context, Object error) {
  reportTabLoadFailure(
    context,
    error,
    hasPayload: true,
    onBlockingError: (_) {},
  );
}

/// Surfaces a failed tab load without treating it as an empty baby list.
///
/// Cached payload stays on screen and the failure is a snackbar. The first
/// load, with nothing to show, records [message] for the error state.
void reportTabLoadFailure(
  BuildContext context,
  Object error, {
  required bool hasPayload,
  required void Function(String message) onBlockingError,
}) {
  final message = apiErrorMessage(AppLocalizations.of(context)!, error);
  if (hasPayload) {
    AppSnackBar.showAlert(context, message);
    return;
  }
  onBlockingError(message);
}

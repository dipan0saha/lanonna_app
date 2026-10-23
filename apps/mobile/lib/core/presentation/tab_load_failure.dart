import 'package:flutter/widgets.dart';
import 'package:lanonna/l10n/app_localizations.dart';

import '../api/api_error_message.dart';
import '../widgets/app_snackbar.dart';

/// Tells the user a reload failed while the content already on screen stays.
///
/// The one snackbar for a failed pull-to-refresh, tab revisit or other reload
/// that has something to keep showing (#421). [AppRefreshIndicator] also uses
/// it for any failure its refresh callback throws.
void reportRefreshFailure(BuildContext context, Object error) {
  AppSnackBar.showAlert(
    context,
    apiErrorMessage(AppLocalizations.of(context)!, error),
  );
}

/// Surfaces a failed tab load without treating it as an empty baby list.
///
/// Cached payload stays on screen and the failure is reported with
/// [reportRefreshFailure]. The first load, with nothing to show, records the
/// message for the error state.
void reportTabLoadFailure(
  BuildContext context,
  Object error, {
  required bool hasPayload,
  required void Function(String message) onBlockingError,
}) {
  if (hasPayload) {
    reportRefreshFailure(context, error);
    return;
  }
  onBlockingError(apiErrorMessage(AppLocalizations.of(context)!, error));
}

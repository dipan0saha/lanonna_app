import 'package:flutter/material.dart';
import 'package:lanonna/l10n/app_localizations.dart';

import '../widgets/app_snackbar.dart';
import 'api_error_message.dart';

/// Runs a repository mutation from UI; surfaces API/network errors via snackbar.
///
/// Returns `true` when [action] completes, `false` on any thrown error.
Future<bool> runMutation(
  BuildContext context,
  Future<void> Function() action,
) async {
  try {
    await action();
    return true;
  } catch (e) {
    if (context.mounted) {
      AppSnackBar.showAlert(context, apiErrorMessage(AppLocalizations.of(context)!, e));
    }
    return false;
  }
}

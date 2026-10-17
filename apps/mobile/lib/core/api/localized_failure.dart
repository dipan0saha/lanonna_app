import 'package:lanonna/l10n/app_localizations.dart';

/// A failure that knows its own localized user copy.
///
/// Domain code throws these instead of `Exception('English text')`, so the
/// message is resolved with the reader's [AppLocalizations] at display time
/// by `apiErrorMessage`.
abstract interface class LocalizedFailure implements Exception {
  String userMessage(AppLocalizations l10n);
}

import 'package:lanonna/l10n/app_localizations.dart';

/// User-facing name for another member (author, uploader, voter, attendee):
/// the name the API returned, or a neutral fallback when it has none.
///
/// Models keep the raw API value (empty when missing) so the fallback is
/// resolved here, in the viewer's locale.
String personDisplayName(AppLocalizations l10n, String? name) {
  final trimmed = name?.trim() ?? '';
  return trimmed.isEmpty ? l10n.personNameFallback : trimmed;
}

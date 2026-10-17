import 'package:lanonna/l10n/app_localizations.dart';

import '../../time/app_date_time.dart';

/// Relative "when" label for activity rows; shares [formatRelativeTime] with the inbox.
String formatActivityWhen(
  AppLocalizations l10n,
  String raw, [
  String? localeName,
]) {
  final instant = DateTime.tryParse(raw);
  if (instant == null) return '';
  return formatRelativeTime(l10n, instant, localeName);
}

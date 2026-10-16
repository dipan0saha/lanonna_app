import '../../time/app_date_time.dart';

/// Relative "when" label for activity rows; shares [formatRelativeTime] with the inbox.
String formatActivityWhen(String raw, [String? localeName]) {
  final instant = DateTime.tryParse(raw);
  if (instant == null) return '';
  return formatRelativeTime(instant, localeName);
}

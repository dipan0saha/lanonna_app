import '../time/app_date_time.dart';
import 'package:lanonna/l10n/app_localizations.dart';
import 'baby_summary.dart';

String babyLifecycleSubtitle(
  AppLocalizations l10n,
  BabySummary baby, [
  String? localeName,
]) {
  final raw = baby.isBorn ? baby.actualBirthDate : baby.expectedBirthDate;
  final date = formatApiCalendarDate(raw, localeName);
  if (date.isEmpty) return baby.lifecycle.label(l10n);
  return baby.isBorn ? l10n.lifecycleBornOn(date) : l10n.lifecycleDueOn(date);
}

String babyListSubtitle(
  AppLocalizations l10n,
  BabySummary baby, [
  String? localeName,
]) {
  final lifecycle = babyLifecycleSubtitle(l10n, baby, localeName);
  final label = baby.relationshipLabel?.trim();
  if (label != null && label.isNotEmpty) {
    return '$label · $lifecycle';
  }
  return lifecycle;
}

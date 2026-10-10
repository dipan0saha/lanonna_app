import '../time/app_date_time.dart';
import 'baby_summary.dart';

String babyLifecycleSubtitle(BabySummary baby, [String? localeName]) {
  if (baby.lifecycleStatus == 'born') {
    final bornLabel = formatApiCalendarDate(baby.actualBirthDate, localeName);
    if (bornLabel.isNotEmpty) return 'Born $bornLabel';
    return 'Born';
  }
  final dueLabel = formatApiCalendarDate(baby.expectedBirthDate, localeName);
  if (dueLabel.isNotEmpty) return 'Due $dueLabel';
  return 'Expecting';
}

String babyListSubtitle(BabySummary baby, [String? localeName]) {
  final lifecycle = babyLifecycleSubtitle(baby, localeName);
  final label = baby.relationshipLabel?.trim();
  if (label != null && label.isNotEmpty) {
    return '$label · $lifecycle';
  }
  return lifecycle;
}

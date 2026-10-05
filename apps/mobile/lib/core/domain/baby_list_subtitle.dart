import 'baby_summary.dart';

String babyLifecycleSubtitle(BabySummary baby) {
  if (baby.lifecycleStatus == 'born') {
    final born = baby.actualBirthDate;
    if (born != null && born.isNotEmpty) return 'Born $born';
    return 'Born';
  }
  final due = baby.expectedBirthDate;
  if (due != null && due.isNotEmpty) return 'Due $due';
  return 'Expecting';
}

String babyListSubtitle(BabySummary baby) {
  final lifecycle = babyLifecycleSubtitle(baby);
  final label = baby.relationshipLabel?.trim();
  if (label != null && label.isNotEmpty) {
    return '$label · $lifecycle';
  }
  return lifecycle;
}

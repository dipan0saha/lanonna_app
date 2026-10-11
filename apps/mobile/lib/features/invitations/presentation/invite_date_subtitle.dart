import '../../../core/time/app_date_time.dart';
import '../data/models/invitation_preview.dart';

String inviteBabyDateSubtitle(InvitationPreview preview, [String? localeName]) {
  if (preview.isBorn) {
    final formatted = formatApiCalendarDate(preview.actualBirthDate, localeName);
    return formatted.isEmpty ? 'Already here' : 'Born $formatted';
  }
  final formatted = formatApiCalendarDate(preview.expectedBirthDate, localeName);
  return formatted.isEmpty ? 'On the way' : 'Arriving $formatted';
}

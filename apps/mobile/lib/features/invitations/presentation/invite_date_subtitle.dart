import '../../../core/time/app_date_time.dart';
import 'package:lanonna/l10n/app_localizations.dart';
import '../data/models/invitation_preview.dart';

String inviteBabyDateSubtitle(
  AppLocalizations l10n,
  InvitationPreview preview, [
  String? localeName,
]) {
  if (preview.isBorn) {
    final formatted = formatApiCalendarDate(preview.actualBirthDate, localeName);
    return formatted.isEmpty
        ? l10n.inviteBabyAlreadyHere
        : l10n.lifecycleBornOn(formatted);
  }
  final formatted = formatApiCalendarDate(preview.expectedBirthDate, localeName);
  return formatted.isEmpty
      ? l10n.inviteBabyOnTheWay
      : l10n.inviteBabyArriving(formatted);
}

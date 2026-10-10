import 'package:lanonna/l10n/app_localizations.dart';

String rsvpStatusLabel(AppLocalizations l10n, String status) {
  switch (status) {
    case 'going':
      return l10n.rsvpStatusGoing;
    case 'maybe':
      return l10n.rsvpStatusMaybe;
    case 'cant_go':
      return l10n.rsvpStatusCantGo;
    default:
      return status.replaceAll('_', ' ');
  }
}

import 'package:lanonna/l10n/app_localizations.dart';

import '../data/models/calendar_models.dart';

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

String rsvpSummaryViewAllTeaser(AppLocalizations l10n, RsvpSummary summary) {
  String segment(int count, String status) => l10n.eventRsvpCountWithStatus(
        count,
        rsvpStatusLabel(l10n, status),
      );
  return l10n.eventRsvpViewAllTeaser(
    segment(summary.going, 'going'),
    segment(summary.maybe, 'maybe'),
  );
}

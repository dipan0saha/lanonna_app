import 'package:lanonna/l10n/app_localizations.dart';

/// Server-owned RSVP answer (`event_rsvps.status`).
enum RsvpStatus {
  going('going'),
  maybe('maybe'),
  cantGo('cant_go');

  const RsvpStatus(this.apiValue);

  final String apiValue;

  static RsvpStatus? fromApi(String? raw) {
    for (final s in values) {
      if (s.apiValue == raw) return s;
    }
    return null;
  }

  String label(AppLocalizations l10n) => switch (this) {
        RsvpStatus.going => l10n.rsvpStatusGoing,
        RsvpStatus.maybe => l10n.rsvpStatusMaybe,
        RsvpStatus.cantGo => l10n.rsvpStatusCantGo,
      };
}

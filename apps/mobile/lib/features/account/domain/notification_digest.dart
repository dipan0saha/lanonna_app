import 'package:lanonna/l10n/app_localizations.dart';

/// Server-owned digest cadence (`users.notification_digest`).
enum NotificationDigest {
  realtime('realtime'),
  daily('daily'),
  weekly('weekly');

  const NotificationDigest(this.apiValue);

  final String apiValue;

  static NotificationDigest fromApi(String? raw) => values.firstWhere(
        (d) => d.apiValue == raw,
        orElse: () => NotificationDigest.realtime,
      );

  /// Option label on the notification preferences screen.
  String label(AppLocalizations l10n) => switch (this) {
        NotificationDigest.realtime => l10n.digestRealtime,
        NotificationDigest.daily => l10n.digestDaily,
        NotificationDigest.weekly => l10n.digestWeekly,
      };

  /// What the cadence delivers (FR-NOTIF-002): account row and option subtitle.
  String summaryLabel(AppLocalizations l10n) => switch (this) {
        NotificationDigest.realtime => l10n.digestSummaryRealtime,
        NotificationDigest.daily => l10n.digestSummaryDaily,
        NotificationDigest.weekly => l10n.digestSummaryWeekly,
      };
}

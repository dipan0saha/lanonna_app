import 'package:lanonna/l10n/app_localizations.dart';

/// Server-owned invitation state (`invitations.status`).
enum InvitationStatus {
  pending('pending'),
  accepted('accepted'),
  expired('expired'),
  revoked('revoked');

  const InvitationStatus(this.apiValue);

  final String apiValue;

  /// Missing or unrecognised values are treated as [expired] (not actionable).
  static InvitationStatus fromApi(String? raw) => values.firstWhere(
        (s) => s.apiValue == raw,
        orElse: () => InvitationStatus.expired,
      );

  String label(AppLocalizations l10n) => switch (this) {
        InvitationStatus.pending => l10n.invitationStatusPending,
        InvitationStatus.accepted => l10n.invitationStatusAccepted,
        InvitationStatus.expired => l10n.invitationStatusExpired,
        InvitationStatus.revoked => l10n.invitationStatusRevoked,
      };
}

/// Server-owned invite email state (`invitations.email_delivery_status`).
enum InviteEmailDeliveryStatus {
  pending('pending'),
  sent('sent'),
  failed('failed');

  const InviteEmailDeliveryStatus(this.apiValue);

  final String apiValue;

  static InviteEmailDeliveryStatus? fromApi(String? raw) {
    for (final s in values) {
      if (s.apiValue == raw) return s;
    }
    return null;
  }

  String label(AppLocalizations l10n) => switch (this) {
        InviteEmailDeliveryStatus.pending => l10n.inviteEmailPending,
        InviteEmailDeliveryStatus.sent => l10n.inviteEmailSent,
        InviteEmailDeliveryStatus.failed => l10n.inviteEmailFailed,
      };
}

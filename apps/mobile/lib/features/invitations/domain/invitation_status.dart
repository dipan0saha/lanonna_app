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

/// Server-owned outcome of one batch-invite row (`results[].status`).
enum InviteRowStatus {
  created('created'),
  resent('resent'),
  skippedMember('skipped_member'),
  skippedDuplicate('skipped_duplicate'),
  emailQueueFailed('email_queue_failed');

  const InviteRowStatus(this.apiValue);

  final String apiValue;

  static InviteRowStatus? fromApi(String? raw) {
    for (final s in values) {
      if (s.apiValue == raw) return s;
    }
    return null;
  }
}

/// Why an invite row will be skipped, from `GET …/membership-check`.
///
/// Kept as a value (not display text) so send-time checks never compare
/// localized strings.
enum InviteMembershipHint {
  alreadyMember,
  invitePending;

  static InviteMembershipHint? fromCheck({
    required bool isMember,
    required bool hasPendingInvite,
  }) {
    if (isMember) return InviteMembershipHint.alreadyMember;
    if (hasPendingInvite) return InviteMembershipHint.invitePending;
    return null;
  }

  String label(AppLocalizations l10n) => switch (this) {
        InviteMembershipHint.alreadyMember => l10n.invitationsAlreadyOnTheFamily,
        InviteMembershipHint.invitePending =>
          l10n.invitationsInvitationAlreadyPending,
      };
}

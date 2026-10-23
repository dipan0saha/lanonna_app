import '../../account/data/account_repository.dart';
import 'invitation_status.dart';

/// Invite email is queued or the worker is sending (not yet `sent` / `failed`).
bool invitationEmailDeliveryInFlight(InvitationRow inv) {
  return inv.status == InvitationStatus.pending &&
      inv.emailSentAt == null &&
      inv.emailDeliveryStatus == InviteEmailDeliveryStatus.pending;
}

/// True when any pending invite is waiting on delivery (poll the list).
bool invitationsNeedDeliveryRefresh(List<InvitationRow> invites) {
  return invites.any(invitationEmailDeliveryInFlight);
}

/// Mirrors API resend: only failed, never-delivered pending invites.
bool invitationCanResendEmail(InvitationRow inv) {
  return inv.status == InvitationStatus.pending &&
      inv.emailSentAt == null &&
      inv.emailDeliveryStatus == InviteEmailDeliveryStatus.failed;
}

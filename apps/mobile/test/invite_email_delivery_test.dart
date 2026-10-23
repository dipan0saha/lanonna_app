import 'package:flutter_test/flutter_test.dart';
import 'package:lanonna/features/account/data/account_repository.dart';
import 'package:lanonna/features/invitations/domain/invitation_status.dart';
import 'package:lanonna/features/invitations/domain/invite_email_delivery.dart';

void main() {
  InvitationRow row({
    InviteEmailDeliveryStatus? status,
    String? sentAt,
  }) =>
      InvitationRow(
        id: 'inv-1',
        email: 'a@b.com',
        status: InvitationStatus.pending,
        emailDeliveryStatus: status,
        emailSentAt: sentAt,
      );

  test('resend only when delivery failed', () {
    expect(invitationCanResendEmail(row(status: InviteEmailDeliveryStatus.failed)), isTrue);
    expect(
      invitationCanResendEmail(row(status: InviteEmailDeliveryStatus.pending)),
      isFalse,
    );
    expect(
      invitationCanResendEmail(row(status: InviteEmailDeliveryStatus.sent)),
      isFalse,
    );
  });

  test('in-flight detection for polling', () {
    expect(
      invitationEmailDeliveryInFlight(row(status: InviteEmailDeliveryStatus.pending)),
      isTrue,
    );
    expect(
      invitationEmailDeliveryInFlight(row(status: InviteEmailDeliveryStatus.failed)),
      isFalse,
    );
    expect(
      invitationsNeedDeliveryRefresh([
        row(status: InviteEmailDeliveryStatus.pending),
      ]),
      isTrue,
    );
  });
}

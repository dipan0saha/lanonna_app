import 'package:flutter_test/flutter_test.dart';
import 'package:lanonna/features/account/data/account_repository.dart';
import 'package:lanonna/features/invitations/domain/invitation_status.dart';

void main() {
  test('fromJson takes the resend action from the server', () {
    final stuck = InvitationRow.fromJson({
      'id': 'inv-1',
      'invitee_email': 'friend@example.com',
      'status': 'pending',
      'email_delivery_status': 'pending',
      'can_resend_email': true,
    });
    expect(stuck.canResendEmail, isTrue);
    // The server says the send is stuck, so the list stops waiting on it.
    expect(stuck.emailDeliveryInFlight, isFalse);

    final sent = InvitationRow.fromJson({
      'id': 'inv-2',
      'invitee_email': 'friend@example.com',
      'status': 'pending',
      'email_delivery_status': 'failed',
      'email_sent_at': '2026-01-01T00:00:00Z',
    });
    expect(sent.emailSentAt, '2026-01-01T00:00:00Z');
    expect(sent.canResendEmail, isFalse);
  });

  test('emailDeliveryInFlight only while the worker is sending', () {
    InvitationRow row(InviteEmailDeliveryStatus? delivery, {String? sentAt}) =>
        InvitationRow(
          id: 'inv-1',
          email: 'friend@example.com',
          status: InvitationStatus.pending,
          emailDeliveryStatus: delivery,
          emailSentAt: sentAt,
        );
    expect(row(InviteEmailDeliveryStatus.pending).emailDeliveryInFlight, isTrue);
    expect(row(InviteEmailDeliveryStatus.failed).emailDeliveryInFlight, isFalse);
    expect(row(InviteEmailDeliveryStatus.sent).emailDeliveryInFlight, isFalse);
    expect(row(null).emailDeliveryInFlight, isFalse);
    expect(
      row(InviteEmailDeliveryStatus.pending, sentAt: '2026-01-01T00:00:00Z')
          .emailDeliveryInFlight,
      isFalse,
    );
  });
}

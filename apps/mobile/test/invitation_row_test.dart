import 'package:flutter_test/flutter_test.dart';
import 'package:lanonna/features/account/data/account_repository.dart';
import 'package:lanonna/features/invitations/domain/invitation_status.dart';

void main() {
  test('canResendEmail is false when email_sent_at is set', () {
    const row = InvitationRow(
      id: 'inv-1',
      email: 'a@b.com',
      status: InvitationStatus.pending,
      emailDeliveryStatus: InviteEmailDeliveryStatus.failed,
      emailSentAt: '2026-01-01T00:00:00Z',
    );
    expect(row.canResendEmail, isFalse);
  });

  test('fromJson maps email_sent_at', () {
    final row = InvitationRow.fromJson({
      'id': 'inv-1',
      'invitee_email': 'a@b.com',
      'status': 'pending',
      'email_delivery_status': 'failed',
      'email_sent_at': '2026-01-01T00:00:00Z',
    });
    expect(row.emailSentAt, '2026-01-01T00:00:00Z');
    expect(row.canResendEmail, isFalse);
  });
}

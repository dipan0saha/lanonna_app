import 'package:flutter_test/flutter_test.dart';
import 'package:lanonna/features/invitations/data/models/invitation_preview.dart';
import 'package:lanonna/features/invitations/presentation/invite_accept_messages.dart';

void main() {
  test('inviteAcceptUserMessage maps known API errors', () {
    expect(inviteAcceptUserMessage('expired'), contains('expired'));
    expect(inviteAcceptUserMessage('revoked'), contains('revoked'));
    expect(inviteAcceptUserMessage('already_used'), contains('already used'));
    expect(inviteAcceptUserMessage('email_mismatch'), contains('email'));
  });

  test('invitePreviewProblemCode maps preview status', () {
    const accepted = InvitationPreview(
      status: 'accepted',
      invitedRole: 'follower',
      inviteeEmail: 'a@b.com',
      babyName: 'Baby',
    );
    expect(accepted.canContinueInviteFlow, isTrue);

    const revoked = InvitationPreview(
      status: 'revoked',
      invitedRole: 'follower',
      inviteeEmail: 'a@b.com',
      babyName: 'Baby',
    );
    expect(revoked.canContinueInviteFlow, isFalse);
    expect(invitePreviewProblemCode(revoked), 'revoked');
  });
}

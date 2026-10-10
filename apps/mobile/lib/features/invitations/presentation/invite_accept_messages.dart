import '../data/models/invitation_preview.dart';

String inviteAcceptUserMessage(String errorCode) {
  return switch (errorCode) {
    'expired' => 'This invitation has expired. Ask the family to send a new invite.',
    'revoked' => 'This invitation was revoked. Ask the family to send a new invite.',
    'already_used' =>
      'This invitation was already used. Sign in with the account that accepted it.',
    'not_found' => 'This invitation link is invalid or was revoked.',
    'max_owners' => 'This baby already has the maximum number of owners.',
    'already_member' => 'You are already part of this baby\'s circle.',
    'email_mismatch' => 'Sign in with the email address that received the invitation.',
    _ => 'Could not accept this invitation. Please try again.',
  };
}

String invitePreviewProblemCode(InvitationPreview preview) {
  if (preview.isExpired) return 'expired';
  if (preview.isRevoked) return 'revoked';
  return 'not_found';
}

import '../../../core/api/api_exception.dart';
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

/// User copy when [InvitationsRepository.fetchPreview] fails (M-26).
String invitePreviewFetchUserMessage(Object error, {required bool offline}) {
  if (offline) {
    return 'Connect to the internet to open this invitation.';
  }
  if (error is ApiException && error.statusCode == 404) {
    return inviteAcceptUserMessage('not_found');
  }
  return 'Could not load this invitation. Try again.';
}

bool invitePreviewFetchCanRetry(Object error, {required bool offline}) {
  if (offline) return true;
  if (error is ApiException && error.statusCode == 404) return false;
  return true;
}

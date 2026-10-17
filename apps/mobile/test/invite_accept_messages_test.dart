import 'dart:io';
import 'package:lanonna/features/invitations/domain/invitation_status.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:lanonna/core/api/api_exception.dart';
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
      status: InvitationStatus.accepted,
      invitedRole: 'follower',
      inviteeEmail: 'a@b.com',
      babyName: 'Baby',
    );
    expect(accepted.canContinueInviteFlow, isTrue);

    const revoked = InvitationPreview(
      status: InvitationStatus.revoked,
      invitedRole: 'follower',
      inviteeEmail: 'a@b.com',
      babyName: 'Baby',
    );
    expect(revoked.canContinueInviteFlow, isFalse);
    expect(invitePreviewProblemCode(revoked), 'revoked');
  });

  test('inviteLandingAcceptErrorMessage maps ApiException and offline', () {
    expect(
      inviteLandingAcceptErrorMessage(
        ApiException('Bad request', statusCode: 400),
      ),
      'Bad request',
    );
    expect(
      inviteLandingAcceptErrorMessage(const SocketException('offline')),
      contains('offline'),
    );
    expect(
      inviteLandingAcceptErrorMessage(Exception('Custom failure')),
      'Custom failure',
    );
  });

  test('invitePreviewFetchUserMessage distinguishes offline, 404, and retryable', () {
    expect(
      invitePreviewFetchUserMessage(Exception('x'), offline: true),
      contains('internet'),
    );
    expect(
      invitePreviewFetchUserMessage(
        ApiException('missing', statusCode: 404),
        offline: false,
      ),
      inviteAcceptUserMessage('not_found'),
    );
    expect(
      invitePreviewFetchUserMessage(
        ApiException('server', statusCode: 503),
        offline: false,
      ),
      contains('Try again'),
    );
    expect(
      invitePreviewFetchCanRetry(
        ApiException('missing', statusCode: 404),
        offline: false,
      ),
      isFalse,
    );
    expect(
      invitePreviewFetchCanRetry(
        ApiException('server', statusCode: 503),
        offline: false,
      ),
      isTrue,
    );
  });
}

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanonna/features/invitations/domain/invitation_status.dart';
import 'package:lanonna/l10n/app_localizations.dart';
import 'package:lanonna/core/api/api_exception.dart';
import 'package:lanonna/features/invitations/data/models/invitation_preview.dart';
import 'package:lanonna/features/invitations/presentation/invite_accept_messages.dart';

void main() {
  late AppLocalizations l10n;

  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  test('inviteAcceptUserMessage maps known API errors', () {
    expect(inviteAcceptUserMessage(l10n, 'expired'), contains('expired'));
    expect(inviteAcceptUserMessage(l10n, 'revoked'), contains('revoked'));
    expect(inviteAcceptUserMessage(l10n, 'already_used'), contains('already used'));
    expect(inviteAcceptUserMessage(l10n, 'email_mismatch'), contains('email'));
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

  test('invitePreviewFetchUserMessage distinguishes offline, 404, and retryable', () {
    expect(
      invitePreviewFetchUserMessage(l10n, Exception('x'), offline: true),
      contains('internet'),
    );
    expect(
      invitePreviewFetchUserMessage(
        l10n,
        ApiException('missing', statusCode: 404),
        offline: false,
      ),
      inviteAcceptUserMessage(l10n, 'not_found'),
    );
    expect(
      invitePreviewFetchUserMessage(
        l10n,
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

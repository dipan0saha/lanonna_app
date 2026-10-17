import 'package:lanonna/l10n/app_localizations.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/api/localized_failure.dart';
import '../data/models/invitation_preview.dart';

/// Accepting an invite returned an API error code (`expired`, `max_owners`, …).
class InviteAcceptException implements LocalizedFailure {
  const InviteAcceptException(this.code);

  final String code;

  @override
  String userMessage(AppLocalizations l10n) =>
      inviteAcceptUserMessage(l10n, code);

  @override
  String toString() => 'invite_accept_failed code=$code';
}

String inviteAcceptUserMessage(AppLocalizations l10n, String errorCode) {
  return switch (errorCode) {
    'expired' => l10n.inviteErrorExpired,
    'revoked' => l10n.inviteErrorRevoked,
    'already_used' => l10n.inviteErrorAlreadyUsed,
    'not_found' => l10n.inviteErrorNotFound,
    'max_owners' => l10n.inviteErrorMaxOwners,
    'already_member' => l10n.inviteErrorAlreadyMember,
    'email_mismatch' => l10n.inviteErrorEmailMismatch,
    _ => l10n.inviteErrorGeneric,
  };
}

String invitePreviewProblemCode(InvitationPreview preview) {
  if (preview.isExpired) return 'expired';
  if (preview.isRevoked) return 'revoked';
  return 'not_found';
}

/// User copy when [InvitationsRepository.fetchPreview] fails (M-26).
String invitePreviewFetchUserMessage(
  AppLocalizations l10n,
  Object error, {
  required bool offline,
}) {
  if (offline) return l10n.inviteErrorOffline;
  if (error is ApiException && error.statusCode == 404) {
    return inviteAcceptUserMessage(l10n, 'not_found');
  }
  return l10n.inviteErrorLoadFailed;
}

bool invitePreviewFetchCanRetry(Object error, {required bool offline}) {
  if (offline) return true;
  if (error is ApiException && error.statusCode == 404) return false;
  return true;
}

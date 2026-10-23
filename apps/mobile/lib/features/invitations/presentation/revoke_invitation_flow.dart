import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/api/run_mutation.dart';
import '../../../core/widgets/app_confirm_dialog.dart';
import '../../../l10n/app_localizations.dart';
import '../../account/data/account_repository.dart';

/// Confirms, then revokes a pending invitation. Shared by Manage followers
/// and the home invite-status card.
///
/// Returns `true` only when the invite was revoked; Cancel or a dismissed
/// sheet does nothing, and API errors surface via [runMutation].
Future<bool> revokeInvitationWithConfirmation(
  BuildContext context, {
  required String babyId,
  required String invitationId,
  required String inviteeEmail,
}) async {
  final l10n = AppLocalizations.of(context)!;
  final confirmed = await showConfirmDialog(
    context,
    title: l10n.inviteRevokeConfirmTitle,
    message: l10n.inviteRevokeConfirmBody(inviteeEmail),
    confirmLabel: l10n.actionRevoke,
    variant: ConfirmDialogVariant.destructive,
  );
  if (!confirmed || !context.mounted) return false;
  return runMutation(
    context,
    () => context.read<AccountRepository>().revokeInvitation(
      babyId,
      invitationId,
    ),
  );
}

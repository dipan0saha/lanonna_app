import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/api/run_mutation.dart';
import '../../../core/widgets/app_confirm_dialog.dart';
import '../../../l10n/app_localizations.dart';
import '../../home/data/home_refresh_signal.dart';
import '../data/registry_repository.dart';

/// Confirms, then deletes a registry item. Shared by the registry list (trash)
/// and the edit form so both entry points behave the same.
///
/// Returns `true` only when the item was deleted; Cancel or a dismissed sheet
/// does nothing, and API errors surface via [runMutation].
Future<bool> deleteRegistryItemWithConfirmation(
  BuildContext context, {
  required String babyId,
  required String itemId,
}) async {
  final l10n = AppLocalizations.of(context)!;
  final confirmed = await showConfirmDialog(
    context,
    title: l10n.registryDeleteConfirmTitle,
    message: l10n.messageRemoves,
    confirmLabel: l10n.actionDelete,
    variant: ConfirmDialogVariant.destructive,
  );
  if (!confirmed || !context.mounted) return false;
  final ok = await runMutation(
    context,
    () => context.read<RegistryRepository>().deleteItem(babyId, itemId),
  );
  if (!ok || !context.mounted) return false;
  context.read<HomeRefreshSignal>().notifyHomeShouldRefresh();
  return true;
}

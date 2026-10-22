import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lanonna/core/domain/baby_display_label.dart';
import 'package:lanonna/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

import '../../../core/api/run_mutation.dart';
import '../../../core/domain/baby_summary.dart';
import '../../../core/widgets/app_confirm_dialog.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../account/data/account_repository.dart';
import '../../home/data/home_refresh_signal.dart';
import '../../home/data/home_repository.dart';
import '../../home/data/selected_baby_store.dart';

/// Two-step destructive confirmation, then API delete and baby-context refresh.
Future<bool> deleteBabyProfileWithConfirmation(
  BuildContext context,
  BabySummary baby,
) async {
  final l10n = AppLocalizations.of(context)!;
  final name = babyNameLabel(l10n, baby.name);

  final confirmed = await showConfirmDialogSequence(
    context,
    [
      ConfirmDialogStep(
        title: l10n.deleteBabyProfileConfirmTitle,
        message: l10n.deleteBabyProfileConfirmBody(name),
        confirmLabel: l10n.deleteBabyProfileConfirmAction,
        variant: ConfirmDialogVariant.destructive,
      ),
      ConfirmDialogStep(
        title: l10n.deleteBabyProfileFinalTitle(name),
        message: l10n.deleteBabyProfileFinalBody,
        confirmLabel: l10n.deleteBabyProfileConfirmAction,
        variant: ConfirmDialogVariant.destructive,
      ),
    ],
  );
  if (!confirmed || !context.mounted) return false;

  final deleted = await runMutation(
    context,
    () => context.read<AccountRepository>().deleteBabyProfile(baby.id),
  );
  if (!deleted || !context.mounted) return false;

  AppSnackBar.showInfo(context, l10n.deleteBabyProfileSuccess);
  await _refreshBabyContextAfterRemoval(context);
  return true;
}

Future<void> _refreshBabyContextAfterRemoval(BuildContext context) async {
  final store = context.read<SelectedBabyStore>();
  final homeRepo = context.read<HomeRepository>();
  await homeRepo.resolveSelectedBaby(store);
  if (!context.mounted) return;
  context.read<HomeRefreshSignal>().notifyBabyContextChanged();
  context.go('/home');
}

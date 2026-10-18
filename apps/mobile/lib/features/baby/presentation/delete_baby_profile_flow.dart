import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lanonna/core/domain/baby_display_label.dart';
import 'package:lanonna/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

import '../../../core/api/run_mutation.dart';
import '../../../core/domain/baby_summary.dart';
import '../../../core/theme/app_colors.dart';
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

  final previewOk = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(l10n.deleteBabyProfileConfirmTitle),
      content: Text(l10n.deleteBabyProfileConfirmBody(name)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(l10n.authPasswordResetCancel),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.error),
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(l10n.deleteBabyProfileConfirmAction),
        ),
      ],
    ),
  );
  if (previewOk != true || !context.mounted) return false;

  final finalOk = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(l10n.deleteBabyProfileFinalTitle(name)),
      content: Text(l10n.deleteBabyProfileFinalBody),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(l10n.authPasswordResetCancel),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.error),
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(l10n.deleteBabyProfileConfirmAction),
        ),
      ],
    ),
  );
  if (finalOk != true || !context.mounted) return false;

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

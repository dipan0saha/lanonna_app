import 'package:flutter/material.dart';
import 'package:lanonna/l10n/app_localizations.dart';

import '../theme/app_colors.dart';
import '../theme/app_metrics.dart';
import '../theme/la_nonna_theme.dart';

/// Orange priority badge (P1–P5) for registry rows.
class RegistryPriorityChip extends StatelessWidget {
  const RegistryPriorityChip({super.key, required this.priority});

  final int priority;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppMetrics.appChipHorizontalPadding,
        vertical: AppMetrics.appChipDenseVerticalPadding,
      ),
      decoration: BoxDecoration(
        color: AppColors.peachTint,
        borderRadius: BorderRadius.circular(AppMetrics.buttonRadius),
        border: Border.all(color: AppColors.secondaryDark, width: 1.5),
      ),
      child: Text(
        AppLocalizations.of(context)!.registryPriorityShort(priority),
        style: context.textStyles.labelSmall?.copyWith(
          color: AppColors.secondaryDark,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

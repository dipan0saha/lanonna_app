import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_metrics.dart';
import '../theme/la_nonna_theme.dart';
import '../../l10n/app_localizations.dart';
import 'app_semantics.dart';

class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AppSemantics.container(
      'offline_banner',
      Material(
      color: AppColors.peachTint,
      child: SafeArea(
        bottom: false,
        child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppMetrics.horizontalPadding,
          8,
          AppMetrics.horizontalPadding,
          8,
        ),
        child: Text(
          l10n.messageReOfflineCheckConnection,
          style: context.textStyles.bodySmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: context.brand.ownerBadgeText,
          ),
          textAlign: TextAlign.center,
        ),
        ),
      ),
    ),
    );
  }
}

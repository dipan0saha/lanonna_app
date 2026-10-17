import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_bordered_surface.dart';
import '../../../../core/theme/la_nonna_theme.dart';
import '../../data/account_repository.dart';
import '../../../../l10n/app_localizations.dart';

class AccountStorageCard extends StatelessWidget {
  const AccountStorageCard({super.key, required this.usage});

  final StorageUsage usage;

  String _formatGb(int bytes) {
    final gb = bytes / (1024 * 1024 * 1024);
    if (gb >= 0.1) return '${gb.toStringAsFixed(1)} GB';
    final mb = bytes / (1024 * 1024);
    return '${mb.toStringAsFixed(0)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final text = context.textStyles;
    return AppBorderedSurface(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            AppLocalizations.of(context)!.accountStorageUsed(
              _formatGb(usage.usedBytes),
              _formatGb(usage.quotaBytes),
            ),
            style: text.titleSmall,
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: usage.usedFraction,
              minHeight: 8,
              backgroundColor: AppColors.border,
              color: AppColors.primaryDark,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.messageSharedAcrossEveryBabyProfile,
            style: text.bodySmall?.copyWith(color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_metrics.dart';
import '../../../../core/theme/la_nonna_theme.dart';
import '../../../../core/widgets/tinted_icon_square.dart';
import '../../../../l10n/app_localizations.dart';

class HomeFollowerQuickActions extends StatelessWidget {
  const HomeFollowerQuickActions({
    super.key,
    this.onVoteInFun,
    this.onViewGallery,
    this.useBornOutlineActions = false,
  });

  final VoidCallback? onVoteInFun;
  final VoidCallback? onViewGallery;
  final bool useBornOutlineActions;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppMetrics.horizontalPadding,
        0,
        AppMetrics.horizontalPadding,
        18,
      ),
      child: useBornOutlineActions
          ? Row(
              children: [
                Expanded(
                  child: _QuickActionTile(
                    icon: Icons.photo_library_outlined,
                    label: l10n.actionViewGallery,
                    onTap: onViewGallery,
                  ),
                ),
              ],
            )
          : Row(
              children: [
                if (onVoteInFun != null)
                  Expanded(
                    child: _QuickActionTile(
                      icon: Icons.emoji_events_outlined,
                      label: l10n.actionVoteFun,
                      onTap: onVoteInFun,
                    ),
                  ),
                if (onVoteInFun != null) SizedBox(width: AppSpacing.md),
                Expanded(
                  child: _QuickActionTile(
                    icon: Icons.photo_library_outlined,
                    label: l10n.actionViewGallery,
                    onTap: onViewGallery,
                  ),
                ),
              ],
            ),
    );
  }
}

class _QuickActionTile extends StatelessWidget {
  const _QuickActionTile({required this.icon, required this.label, this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppMetrics.surfaceRadius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppMetrics.surfaceRadius),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppMetrics.surfaceRadius),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              TintedIconSquare(icon: icon),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                style: context.textStyles.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

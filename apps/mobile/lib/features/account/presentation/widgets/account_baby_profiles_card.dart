import 'package:flutter/material.dart';
import 'package:lanonna/core/domain/baby_display_label.dart';
import 'package:lanonna/l10n/app_localizations.dart';

import '../../../../core/domain/baby_summary.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_metrics.dart';
import '../../../../core/widgets/app_bordered_surface.dart';
import '../../../../core/widgets/baby_profile_avatar.dart';
import '../../../../core/widgets/membership_role_pill.dart';
import '../../../../core/theme/la_nonna_theme.dart';

class AccountBabyProfilesCard extends StatelessWidget {
  const AccountBabyProfilesCard({
    super.key,
    required this.babies,
    required this.subtitleFor,
    required this.onBabyTap,
    this.onBabyLongPress,
  });

  final List<BabySummary> babies;
  final String Function(BabySummary baby) subtitleFor;
  final void Function(BabySummary baby) onBabyTap;
  final void Function(BabySummary baby)? onBabyLongPress;

  @override
  Widget build(BuildContext context) {
    if (babies.isEmpty) return const SizedBox.shrink();
    return AppBorderedSurface(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var i = 0; i < babies.length; i++) ...[
            if (i > 0) const Divider(height: 1, color: AppColors.border),
            _BabyRow(
              baby: babies[i],
              subtitle: subtitleFor(babies[i]),
              onTap: () => onBabyTap(babies[i]),
              onLongPress: onBabyLongPress == null
                  ? null
                  : () => onBabyLongPress!(babies[i]),
            ),
          ],
        ],
      ),
    );
  }
}

class _BabyRow extends StatelessWidget {
  const _BabyRow({
    required this.baby,
    required this.subtitle,
    required this.onTap,
    this.onLongPress,
  });

  final BabySummary baby;
  final String subtitle;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final isOwner = baby.role == 'owner';
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppMetrics.surfacePadding,
          vertical: AppSpacing.md,
        ),
        child: Row(
          children: [
            BabyProfileAvatar(baby: baby),
            SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    babyNameLabel(AppLocalizations.of(context)!, baby.name),
                    style: context.textStyles.titleSmall,
                  ),
                  Text(
                    subtitle,
                    style: context.textStyles.bodySmall?.copyWith(
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ),
            ),
            MembershipRolePill(isOwner: isOwner),
          ],
        ),
      ),
    );
  }
}

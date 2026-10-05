import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_metrics.dart';
import '../../../../core/theme/la_nonna_theme.dart';
import '../../../onboarding/presentation/widgets/onboarding_buttons.dart';

class OwnerExpectingHeroCard extends StatelessWidget {
  const OwnerExpectingHeroCard({
    super.key,
    required this.babyName,
    required this.daysToDueDate,
    this.onAnnounceTap,
    this.showAnnounceCta = true,
    this.dueDateLabel,
    this.followerFootnote,
  });

  final String babyName;
  final int? daysToDueDate;
  final VoidCallback? onAnnounceTap;
  final bool showAnnounceCta;
  final String? dueDateLabel;
  final String? followerFootnote;

  @override
  Widget build(BuildContext context) {
    final text = context.textStyles;

    return Container(
      margin: EdgeInsets.fromLTRB(
        AppMetrics.horizontalPadding,
        0,
        AppMetrics.horizontalPadding,
        18,
      ),
      padding: const EdgeInsets.fromLTRB(20, 26, 20, 26),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppMetrics.homeHeroRadius),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            'Waiting for $babyName',
            style: text.bodyLarge,
          ),
          const SizedBox(height: 12),
          Text(
            daysToDueDate?.toString() ?? '-',
            style: text.displayLarge,
          ),
          const SizedBox(height: 4),
          Text(
            dueDateLabel != null
                ? 'Days to due date · $dueDateLabel'
                : 'DAYS TO DUE DATE',
            style: text.labelSmall?.copyWith(letterSpacing: 0.06 * 11),
          ),
          if (followerFootnote != null) ...[
            const SizedBox(height: 12),
            Text(
              followerFootnote!,
              textAlign: TextAlign.center,
              style: text.bodySmall?.copyWith(color: AppColors.muted),
            ),
          ],
          if (showAnnounceCta) ...[
            const SizedBox(height: 18),
            OnboardingPrimaryButton(
              label: 'Announce Arrival',
              onPressed: onAnnounceTap,
            ),
          ],
        ],
      ),
    );
  }
}

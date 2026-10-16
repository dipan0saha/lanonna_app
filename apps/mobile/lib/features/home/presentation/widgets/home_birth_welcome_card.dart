import 'package:flutter/material.dart';

import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_metrics.dart';
import '../../../../core/theme/la_nonna_theme.dart';
import '../../../../core/time/app_date_time.dart';
import '../../../../core/widgets/app_semantics.dart';
import '../../../announcement/presentation/announcement_share.dart';
import '../../data/models/home_summary.dart';

class HomeBirthWelcomeCard extends StatelessWidget {
  const HomeBirthWelcomeCard({
    super.key,
    required this.welcome,
    required this.babyId,
    this.showShareToInstagram = true,
  });

  final BirthWelcomeSummary welcome;
  final String babyId;
  final bool showShareToInstagram;

  @override
  Widget build(BuildContext context) {
    final text = context.textStyles;
    final brand = context.brand;
    final locale = localeNameForFormatting(context);
    final bornLine = _bornSummaryLine(context, locale);

    return Container(
      margin: EdgeInsets.fromLTRB(
        AppMetrics.horizontalPadding,
        8,
        AppMetrics.horizontalPadding,
        18,
      ),
      padding: const EdgeInsets.fromLTRB(22, 30, 22, 22),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [brand.peachTint, brand.sageTint]),
        borderRadius: BorderRadius.circular(AppMetrics.homeHeroRadius),
      ),
      child: Column(
        children: [
          Text('🎉', style: context.textStyles.headlineMedium),
          const SizedBox(height: 8),
          Text(
            '${welcome.babyName} is here!',
            style: text.titleSmall,
            textAlign: TextAlign.center,
          ),
          if (bornLine != null) ...[
            SizedBox(height: AppSpacing.sm),
            Text(
              bornLine,
              textAlign: TextAlign.center,
              style: text.bodyMedium?.copyWith(color: AppColors.textPrimary),
            ),
          ],
          SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: AppSemantics.button(
                  'home_view_announcement',
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.surface,
                      foregroundColor: AppColors.textPrimary,
                      elevation: 0,
                    ),
                    onPressed: () => context.push('/baby/$babyId/announcement'),
                    child: const Text('View Announcement'),
                  ),
                  label: 'View announcement',
                ),
              ),
              if (showShareToInstagram) ...[
                SizedBox(width: AppSpacing.smMd),
                Expanded(
                  child: AppSemantics.button(
                    'home_share_announcement',
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primaryDark,
                        side: const BorderSide(color: AppColors.primaryDark),
                        backgroundColor: AppColors.surface,
                      ),
                      onPressed: () => AnnouncementShare.shareBabyAnnouncement(
                        context,
                        babyId,
                      ),
                      child: const Text('Share to Instagram'),
                    ),
                    label: 'Share announcement to Instagram',
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  String? _bornSummaryLine(BuildContext context, String locale) {
    final parts = <String>[];
    final rawDate = welcome.birthDate;
    if (rawDate != null && rawDate.isNotEmpty) {
      final formatted = formatApiCalendarDate(rawDate, locale);
      if (formatted.isNotEmpty) {
        parts.add('Born $formatted');
      }
    }
    final weight = welcome.weightText?.trim();
    if (weight != null && weight.isNotEmpty) {
      parts.add(weight);
    }
    if (parts.isEmpty && welcome.everyoneNotified != true) {
      return null;
    }
    var line = parts.join(' · ');
    if (welcome.everyoneNotified == true) {
      line = line.isEmpty
          ? "Everyone you've invited has been notified."
          : '$line. Everyone you\'ve invited has been notified.';
    }
    return line.isEmpty ? null : line;
  }
}

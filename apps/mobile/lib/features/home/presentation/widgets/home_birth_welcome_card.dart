import 'package:flutter/material.dart';
import 'package:lanonna/core/domain/baby_display_label.dart';

import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_metrics.dart';
import '../../../../core/theme/la_nonna_theme.dart';
import '../../../../core/time/app_date_time.dart';
import '../../../../core/widgets/app_button_label.dart';
import '../../../../core/widgets/app_responsive_button_pair.dart';
import '../../../../core/widgets/app_semantics.dart';
import '../../../announcement/presentation/announcement_share.dart';
import '../../data/models/home_summary.dart';
import '../../../../core/theme/app_button_styles.dart';
import '../../../../l10n/app_localizations.dart';

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
    final l10n = AppLocalizations.of(context)!;
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
            AppLocalizations.of(
              context,
            )!.homeBirthWelcomeTitle(
              babyNameLabel(AppLocalizations.of(context)!, welcome.babyName),
            ),
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
          AppResponsiveButtonPair(
            start: AppSemantics.button(
              'home_view_announcement',
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.surface,
                  foregroundColor: AppColors.textPrimary,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppMetrics.buttonHorizontalPadding,
                    vertical: AppMetrics.buttonVerticalPadding,
                  ),
                ),
                onPressed: () => context.push('/baby/$babyId/announcement'),
                child: AppButtonLabel(AppLocalizations.of(context)!.homeViewAnnouncement),
              ),
              label: l10n.actionViewAnnouncement,
            ),
            end: showShareToInstagram
                ? AppSemantics.button(
                    'home_share_announcement',
                    OutlinedButton(
                      style: AppButtonStyles.outlinedAccent,
                      onPressed: () => AnnouncementShare.shareBabyAnnouncement(
                        context,
                        babyId,
                      ),
                      child: AppButtonLabel(AppLocalizations.of(context)!.homeShareToInstagram),
                    ),
                    label: l10n.actionShareAnnouncementInstagram,
                  )
                : null,
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
        parts.add(AppLocalizations.of(context)!.lifecycleBornOn(formatted));
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
          ? AppLocalizations.of(context)!.homeEveryoneYouveInvitedHasBeen
          : AppLocalizations.of(context)!.homeInvitesNotifiedWithLine(line);
    }
    return line.isEmpty ? null : line;
  }
}

import 'package:flutter/material.dart';
import 'package:lanonna/l10n/app_localizations.dart';

import '../../../../core/media/cached_signed_image.dart';
import '../../../../core/time/app_date_time.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_metrics.dart';
import '../../../../core/theme/la_nonna_theme.dart';
import '../../../../core/widgets/app_engagement_pill.dart';
import '../../data/announcement_repository.dart';

/// White keepsake card with script first name and four icon stats.
class AnnouncementKeepsakeCard extends StatelessWidget {
  const AnnouncementKeepsakeCard({
    super.key,
    required this.detail,
    this.onSignedUrlError,
    this.showEngagementRow = false,
    this.onSquishTap,
    this.squishCount,
    this.commentCount,
  });

  final AnnouncementDetail detail;
  final VoidCallback? onSignedUrlError;
  final bool showEngagementRow;
  final VoidCallback? onSquishTap;
  final int? squishCount;
  final int? commentCount;

  @override
  Widget build(BuildContext context) {
    final d = detail;
    final locale = localeNameForFormatting(context);
    final birthDateLabel = d.birthDate != null
        ? formatApiCalendarDate(d.birthDate, locale)
        : null;
    final birthTimeLabel = formatApiClockTime(
      d.birthTime,
      Localizations.localeOf(context).toString(),
    );

    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(
        maxWidth: AppMetrics.keepsakeCardMaxWidth,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppMetrics.keepsakeCardRadius),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDark.withValues(alpha: 0.12),
            blurRadius: AppMetrics.keepsakeCardShadowBlur,
            offset: Offset(0, AppMetrics.keepsakeCardShadowYOffset),
          ),
        ],
      ),
      padding: AppMetrics.keepsakeCardPadding,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (d.photoDisplayUrl != null)
            Container(
              width: AppMetrics.keepsakePhotoSize,
              height: AppMetrics.keepsakePhotoSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.primaryDark,
                  width: AppMetrics.keepsakePhotoBorderWidth,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.25),
                    blurRadius: AppMetrics.keepsakePhotoShadowBlur,
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: CachedSignedImage(
                imageUrl: d.photoDisplayUrl,
                cacheKey: 'announcement-photo-${d.id}',
                width: AppMetrics.keepsakePhotoSize,
                height: AppMetrics.keepsakePhotoSize,
                fit: BoxFit.cover,
                onSignedUrlError: onSignedUrlError,
              ),
            )
          else
            CircleAvatar(
              radius: AppMetrics.keepsakePlaceholderAvatarRadius,
              backgroundColor: AppColors.sageTint,
              child: Icon(
                Icons.child_care,
                size: AppMetrics.keepsakePlaceholderChildIconSize,
                color: AppColors.primaryDark,
              ),
            ),
          SizedBox(height: AppSpacing.lg),
          Text(
            d.firstName ?? AppLocalizations.of(context)!.babyNameDefault,
            style: context.keepsakeScriptNameStyle,
            textAlign: TextAlign.center,
          ),
          if (d.lastName != null && d.lastName!.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(top: AppSpacing.xxs),
              child: Text(
                d.lastName!.toUpperCase(),
                style: context.textStyles.labelMedium?.copyWith(
                  letterSpacing: AppMetrics.keepsakeLastNameLetterSpacing,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
            child: const Divider(height: 1, color: AppColors.border),
          ),
          _StatsGrid(
            birthDate: birthDateLabel,
            birthTime: birthTimeLabel.isNotEmpty ? birthTimeLabel : null,
            weight: d.weightText,
            length: d.lengthText,
          ),
          if (showEngagementRow &&
              (squishCount != null || commentCount != null)) ...[
            SizedBox(height: AppSpacing.lg),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: AppSpacing.smMd,
              runSpacing: AppSpacing.sm,
              children: [
                if (squishCount != null)
                  AppSquishEngagementPill(
                    label: AppLocalizations.of(
                      context,
                    )!.photoSquishCount(squishCount!),
                    active: false,
                    onPressed: onSquishTap ?? () {},
                    semanticsId: 'announcement_squish',
                  ),
                if (commentCount != null)
                  AppEngagementPill(
                    label: AppLocalizations.of(
                      context,
                    )!.photoCommentCount(commentCount!),
                    icon: Icons.chat_bubble_outline,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({this.birthDate, this.birthTime, this.weight, this.length});

  final String? birthDate;
  final String? birthTime;
  final String? weight;
  final String? length;

  @override
  Widget build(BuildContext context) {
    final items = <_StatItem>[
      if (birthDate != null)
        _StatItem(Icons.calendar_today_outlined, birthDate!),
      if (birthTime != null) _StatItem(Icons.schedule_outlined, birthTime!),
      if (weight != null) _StatItem(Icons.monitor_weight_outlined, weight!),
      if (length != null) _StatItem(Icons.straighten, length!),
    ];
    if (items.isEmpty) return const SizedBox.shrink();
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: AppSpacing.xl,
      runSpacing: AppSpacing.md,
      children: items
          .map(
            (item) => SizedBox(
              width: AppMetrics.keepsakeStatColumnWidth,
              child: Column(
                children: [
                  Icon(
                    item.icon,
                    size: AppMetrics.keepsakeStatIconSize,
                    color: AppColors.primaryDark,
                  ),
                  SizedBox(height: AppSpacing.xxs),
                  Text(
                    item.label,
                    textAlign: TextAlign.center,
                    style: context.textStyles.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}

class _StatItem {
  const _StatItem(this.icon, this.label);
  final IconData icon;
  final String label;
}

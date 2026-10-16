import 'package:flutter/material.dart';

import '../../../../core/media/cached_signed_image.dart';
import '../../../../core/time/app_date_time.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_metrics.dart';
import '../../../../core/theme/la_nonna_theme.dart';
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
      constraints: const BoxConstraints(maxWidth: 360),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDark.withValues(alpha: 0.12),
            blurRadius: 28,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 22),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (d.photoDisplayUrl != null)
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.primaryDark, width: 3),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.25),
                    blurRadius: 12,
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: CachedSignedImage(
                imageUrl: d.photoDisplayUrl,
                cacheKey: 'announcement-photo-${d.id}',
                width: 120,
                height: 120,
                fit: BoxFit.cover,
                onSignedUrlError: onSignedUrlError,
              ),
            )
          else
            const CircleAvatar(
              radius: 52,
              backgroundColor: AppColors.sageTint,
              child: Icon(
                Icons.child_care,
                size: 40,
                color: AppColors.primaryDark,
              ),
            ),
          const SizedBox(height: 16),
          Text(
            d.firstName ?? 'Baby',
            style: context.keepsakeScriptNameStyle,
            textAlign: TextAlign.center,
          ),
          if (d.lastName != null && d.lastName!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                d.lastName!.toUpperCase(),
                style: context.textStyles.labelMedium?.copyWith(
                  letterSpacing: 2.4,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Divider(height: 1, color: AppColors.border),
          ),
          _StatsGrid(
            birthDate: birthDateLabel,
            birthTime: birthTimeLabel.isNotEmpty ? birthTimeLabel : null,
            weight: d.weightText,
            length: d.lengthText,
          ),
          if (showEngagementRow &&
              (squishCount != null || commentCount != null)) ...[
            const SizedBox(height: 16),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 10,
              runSpacing: 8,
              children: [
                if (squishCount != null)
                  _EngagementPill(
                    icon: Icons.back_hand_outlined,
                    label: '$squishCount squishes',
                    onTap: onSquishTap,
                  ),
                if (commentCount != null)
                  _EngagementPill(
                    icon: Icons.chat_bubble_outline,
                    label: '$commentCount comments',
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
      spacing: 20,
      runSpacing: 12,
      children: items
          .map(
            (item) => SizedBox(
              width: 120,
              child: Column(
                children: [
                  Icon(item.icon, size: 20, color: AppColors.primaryDark),
                  const SizedBox(height: 4),
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

class _EngagementPill extends StatelessWidget {
  const _EngagementPill({required this.icon, required this.label, this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppMetrics.buttonRadius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppMetrics.buttonRadius),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppMetrics.buttonRadius),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: AppColors.primaryDark),
              const SizedBox(width: 6),
              Text(label, style: context.textStyles.labelSmall),
            ],
          ),
        ),
      ),
    );
  }
}

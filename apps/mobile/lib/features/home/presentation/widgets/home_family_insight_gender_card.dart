import 'package:flutter/material.dart';
import 'package:lanonna/l10n/app_localizations.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/vote_count_pill.dart';
import '../../../../core/theme/la_nonna_theme.dart';
import '../../../../core/time/app_date_time.dart';
import '../../../fun/domain/gender_vote_display.dart';
import '../../data/models/home_summary.dart';
import 'home_scroll_section.dart';
import 'home_section_trailing.dart';

class HomeFamilyInsightGenderCard extends StatelessWidget {
  const HomeFamilyInsightGenderCard({
    super.key,
    required this.summary,
    this.onViewAll,
  });

  final HomeSummary summary;
  final VoidCallback? onViewAll;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final totals =
        summary.genderTotals ?? const GenderTotals(male: 0, female: 0);
    final genderVotes = genderVoteDisplay(
      maleVotes: totals.male,
      femaleVotes: totals.female,
    );
    final total = genderVotes.total;
    final topName = summary.topName;
    final topDate = summary.topBirthdateGuess;
    final locale = localeNameForFormatting(context);

    return HomeScrollSection.bordered(
      title: l10n.messageInsight,
      trailing: onViewAll != null
          ? HomeSectionLink(label: l10n.actionView, onPressed: onViewAll!)
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                l10n.labelBoyGirl,
                style: context.textStyles.labelSmall?.copyWith(
                  color: AppColors.muted,
                ),
              ),
              const Spacer(),
              if (total > 0) VoteCountPill(total: total),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _voteBox(
                  context,
                  AppLocalizations.of(context)!.funGenderBoy,
                  genderVotes.displayPercentForMale(),
                  totals.male,
                  leading: totals.male > totals.female,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _voteBox(
                  context,
                  AppLocalizations.of(context)!.funGenderGirl,
                  genderVotes.displayPercentForFemale(),
                  totals.female,
                  leading: totals.female > totals.male,
                ),
              ),
            ],
          ),
          if (genderVotes.maleProgress != null) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: genderVotes.maleProgress,
                minHeight: 8,
                backgroundColor: AppColors.peachTint,
                color: AppColors.primaryDark,
              ),
            ),
          ],
          if (topName != null && topName.suggestedName.isNotEmpty) ...[
            const Divider(height: 24),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.labelTopName,
                        style: context.textStyles.labelSmall?.copyWith(
                          color: AppColors.muted,
                        ),
                      ),
                      Text(
                        '${topName.suggestedName} · ${l10n.nameLoveCount(topName.likeCount)}',
                        style: context.textStyles.titleSmall,
                      ),
                    ],
                  ),
                ),
                if (topDate != null)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        l10n.labelTopGuessDate,
                        style: context.textStyles.labelSmall?.copyWith(
                          color: AppColors.muted,
                        ),
                      ),
                      Text(
                        formatApiCalendarDate(topDate, locale),
                        style: context.textStyles.titleSmall,
                      ),
                    ],
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _voteBox(
    BuildContext context,
    String label,
    int pct,
    int count, {
    bool leading = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: leading ? AppColors.primaryDark : AppColors.border,
          width: leading ? 2 : 1.5,
        ),
      ),
      child: Column(
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          Text(
            AppLocalizations.of(context)!.predictionGenderVoteShare(pct, count),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/vote_count_pill.dart';
import '../../../../core/theme/la_nonna_theme.dart';
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
    final totals = summary.genderTotals ?? const GenderTotals(male: 0, female: 0);
    final total = totals.male + totals.female;
    final boyPct = total > 0 ? ((totals.male / total) * 100).round() : 50;
    final topName = summary.topName;
    final topDate = summary.topBirthdateGuess;

    return HomeScrollSection.bordered(
      title: 'Family Insight',
      trailing: onViewAll != null
          ? HomeSectionLink(label: 'View all', onPressed: onViewAll!)
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'BOY OR GIRL?',
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
              Expanded(child: _voteBox('Boy', boyPct, totals.male)),
              const SizedBox(width: 10),
              Expanded(child: _voteBox('Girl', 100 - boyPct, totals.female)),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: total > 0 ? totals.male / total : 0.5,
              minHeight: 8,
              backgroundColor: AppColors.peachTint,
              color: AppColors.primaryDark,
            ),
          ),
          if (topName != null && topName.suggestedName.isNotEmpty) ...[
            const Divider(height: 24),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'TOP NAME',
                        style: context.textStyles.labelSmall?.copyWith(
                          color: AppColors.muted,
                        ),
                      ),
                      Text(
                        '${topName.suggestedName} · ${topName.likeCount} loves',
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
                        'TOP GUESS DATE',
                        style: context.textStyles.labelSmall?.copyWith(
                          color: AppColors.muted,
                        ),
                      ),
                      Text(topDate, style: context.textStyles.titleSmall),
                    ],
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _voteBox(String label, int pct, int count) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.sageTint,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          Text('$pct% ($count)'),
        ],
      ),
    );
  }
}
